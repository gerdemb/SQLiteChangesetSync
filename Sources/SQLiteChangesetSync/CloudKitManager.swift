//
//  ChangesetRepository+CloudKit.swift
//
//
//  Created by Ben Gerdemann on 12/7/23.
//

import Foundation
import GRDB
import CloudKit
import SwiftUI
import OSLog

enum Config {
    /// iCloud container identifier.
    /// Update this if you wish to use your own iCloud container.
    static let containerIdentifier = "iCloud.com.github.gerdemb.SQLiteChangesetSyncDemo"
}

// MARK: - Setup

@available(iOS 15.0, *)
public class CloudKitManager {
    private let container = CKContainer(identifier: Config.containerIdentifier)
    private let zone = CKRecordZone(zoneName: "ChangeSets")
    private let subscriptionID = "changeset-subscription-id"
    private let cloudDatabase: CKDatabase
    
    private var lastChangeToken: CKServerChangeToken?
    private(set) public var isSetup = false
    
    public init(_ dbWriter: some GRDB.DatabaseWriter) {
        self.dbWriter = dbWriter
        cloudDatabase = container.privateCloudDatabase
    }
    
    private let dbWriter: any DatabaseWriter
    
    public func setup() async throws {
        loadLastChangeToken()
        try await createZoneIfNeeded()
        try await createSubscriptionIfNeeded()
        isSetup = true
        Logger.sqliteChangesetSync.info("CloudKit setup")
    }
    
    public func reset() async throws {
        isSetup = false
        // 1. Delete CloudKit data
        try await cloudDatabase.deleteRecordZone(withID: zone.zoneID)
        try await cloudDatabase.deleteSubscription(withID: subscriptionID)
        
        // 2. Reset UserDefaults
        UserDefaults.standard.removeObject(forKey: "isZoneCreated")
        UserDefaults.standard.removeObject(forKey: "isSubscribed")
        resetLastChangeToken()
        Logger.sqliteChangesetSync.info("CloudKit reset")

        try await setup()
    }
    
    public func resetLastChangeToken() {
        UserDefaults.standard.removeObject(forKey: "lastChangeToken")
        loadLastChangeToken()
    }
    
    public static let dummy = { try! CloudKitManager(DatabaseQueue()) }    
}

// MARK: - Operations

@available(iOS 15.0, *)
extension CloudKitManager {
    public func push() async throws -> [Changeset] {
        if !isSetup { try await setup() }
        
        // 1. Select Changesets that have not been pushed
        let changesets = try await dbWriter.read { [self] db in
            try selectChangesetNotPushed(db)
        }
        
        // 2. Iterate through Changesets
        for changeset in changesets {
            // 3. Save Changeset to CloudKit
            let recordID = CKRecord.ID(recordName: changeset.uuid, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "Changeset", recordID: recordID)
            record["parent_uuid"] = changeset.parent_uuid
            record["parent_changeset"] = changeset.parent_changeset as? NSData
            record["merge_uuid"] = changeset.merge_uuid
            record["merge_changeset"] = changeset.merge_changeset as? NSData
            record["meta"] = changeset.meta
            do {
                try await cloudDatabase.save(record)
            } catch {
                let ckError = error as? CKError
                switch ckError?.code {
                case .serverRecordChanged:
                    // Record has already been pushed. This could happen if there is an error between
                    // saving the record to CloudKit and updating the local database to show the
                    // changeset as pushed. We'll ignore this error and keep processing. Changeset
                    // will be updated as pushed in following code
                    Logger.sqliteChangesetSync.warning("Changeset has already been pushed \(error) \(String(describing: changeset)) ")
                default:
                    throw error
                }
                
                // 4. Update Changeset as pushed=true in database
                try await dbWriter.write { [self] db in
                    try updateChangesetSetPushed(db, uuid: changeset.uuid)
                }
            }
        }
        Logger.sqliteChangesetSync.info("Pushed \(changesets.count) changesets")
        return changesets
    }
        
        public func fetch() async throws -> [Changeset] {
            if !isSetup { try await setup() }
            var awaitingChanges = true
            var newChangesets: [Changeset] = []
            
            while awaitingChanges {
                // 1. Find new changes from CloudKit
                let changes = try await cloudDatabase.recordZoneChanges(inZoneWith: zone.zoneID, since: lastChangeToken)
                
                // 2. Iterate through new change sets
                for change in changes.modificationResultsByID {
                    switch change.value {
                    case .success(let modification):
                        let record = modification.record
                        let uuid = record.recordID.recordName
                        let found = try await dbWriter.read { [self] db in
                            try selectChangesetByUUID(db, uuid: uuid)
                        }
                        // 3. If changeset is new, add it to newChangesets
                        if found == nil {
                            let changeset = Changeset(
                                uuid: uuid,
                                parent_uuid: record["parent_uuid"],
                                parent_changeset: record["parent_changeset"],
                                merge_uuid: record["merge_uuid"],
                                merge_changeset: record["merge_changeset"],
                                pushed: true,
                                meta: record["meta"] as? String ?? "{}"
                            )
                            newChangesets.append(changeset)
                        }
                    case .failure(let error):
                        Logger.sqliteChangesetSync.error("CloudKit error \(error)")
                    }
                }
                
                saveChangeToken(changes.changeToken)
                
                awaitingChanges = changes.moreComing
            }
            
            // 4. Insert all new changesets
            let changesetsToInsert = newChangesets
            try await dbWriter.write { [self] db in
                for changeset in changesetsToInsert {
                    try insertChangeset(db, changeset: changeset)
                }
            }
            Logger.sqliteChangesetSync.info("Fetched \(newChangesets.count) changesets")
            return newChangesets
        }
    }
    
    // MARK: - Database Helpers
    
    @available(iOS 15.0, *)
    extension CloudKitManager {
        private func selectChangesetByUUID(_ db: Database, uuid: String) throws -> Changeset? {
            return try Changeset.fetchOne(db, key: uuid)
        }
        
        private func insertChangeset(_ db: Database, changeset: Changeset) throws {
            try changeset.insert(db)
        }
        
        private func selectChangesetNotPushed(_ db: Database) throws -> [Changeset] {
            return try Changeset.filter(Column("pushed") == false).fetchAll(db)
        }
        
        private func updateChangesetSetPushed(_ db: Database, uuid: String) throws {
            try Changeset.filter(key: uuid).updateAll(db, [Column("pushed").set(to: true)])
        }
    }
    
    // MARK: - CloudKit Helpers
    
    @available(iOS 15.0, *)
    extension CloudKitManager {
        private func loadLastChangeToken() {
            guard let data = UserDefaults.standard.data(forKey: "lastChangeToken") else {
                lastChangeToken = nil
                return
            }
            
            lastChangeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        
        private func saveChangeToken(_ token: CKServerChangeToken) {
            let tokenData = try! NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            
            lastChangeToken = token
            UserDefaults.standard.set(tokenData, forKey: "lastChangeToken")
        }
        
        private func createZoneIfNeeded() async throws {
            // Avoid the operation if this has already been done.
            guard !UserDefaults.standard.bool(forKey: "isZoneCreated") else {
                return
            }
            
            do {
                _ = try await cloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
            } catch {
                print("ERROR: Failed to create custom zone: \(error.localizedDescription)")
                throw error
            }
            
            UserDefaults.standard.setValue(true, forKey: "isZoneCreated")
        }
        
        private func createSubscriptionIfNeeded() async throws {
            guard !UserDefaults.standard.bool(forKey: "isSubscribed") else {
                return
            }
            
            // First check if the subscription has already been created.
            // If a subscription is returned, we don't need to create one.
            let foundSubscription = try? await cloudDatabase.subscription(for: subscriptionID)
            guard foundSubscription == nil else {
                UserDefaults.standard.setValue(true, forKey: "isSubscribed")
                return
            }
            
            // No subscription created yet, so create one here, reporting and passing along any errors.
            let subscription = CKRecordZoneSubscription(zoneID: zone.zoneID, subscriptionID: subscriptionID)
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            _ = try await cloudDatabase.modifySubscriptions(saving: [subscription], deleting: [])
            UserDefaults.standard.setValue(true, forKey: "isSubscribed")
        }
    }
    
    // MARK: - SwiftUI
    
    @available(iOS 15.0, *)
    private struct CloudKitManagerKey: EnvironmentKey {
        /// The default appDatabase is an empty in-memory repository.
        static let defaultValue = CloudKitManager.dummy()
    }
    
    @available(iOS 15.0, *)
    public extension EnvironmentValues {
        var cloudKitManager: CloudKitManager {
            get { self[CloudKitManagerKey.self] }
            set { self[CloudKitManagerKey.self] = newValue }
        }
    }
