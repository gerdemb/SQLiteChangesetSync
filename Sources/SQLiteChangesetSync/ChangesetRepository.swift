//
//  ChangesetRepository.swift
//
//
//  Created by Ben Gerdemann on 12/5/23.
//

import Foundation
import GRDB
import SwiftUI

public struct ChangesetRepository {
    public static let empty = { try! ChangesetRepository(DatabaseQueue()) }
    
    public init(_ dbWriter: some GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrate(migrator)
    }
    
    private let dbWriter: any DatabaseWriter
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createChangeset") { db in
            try db.create(table: "changeset") { t in
                // Define columns
                t.column("uuid", .text).notNull().primaryKey()
                t.column("parent_uuid", .text)
                t.column("parent_changeset", .blob).notNull()
                t.column("merge_uuid", .text)
                t.column("merge_changeset", .blob)
                t.column("pushed", .boolean).notNull()
                t.column("meta", .text).notNull().defaults(to: "{}")
                
                // Define foreign key constraints
                t.foreignKey(["parent_uuid"], references: "changeset", columns: ["uuid"], onDelete: .restrict, onUpdate: .restrict, deferred: true)
                t.foreignKey(["merge_uuid"], references: "changeset", columns: ["uuid"], onDelete: .restrict, onUpdate: .restrict, deferred: true)
            }
            
            try db.create(table: "head") { t in
                // Define columns
                t.column("uuid", .text).primaryKey()
                
                // Define foreign key constraints
                t.foreignKey(["uuid"], references: "changeset", columns: ["uuid"], onDelete: .restrict, onUpdate: .restrict, deferred: true)
            }
            
            // Initial value for head is NULL
            try Head(uuid: nil).insert(db)
        }
        
        return migrator
    }
    
    public func migrate(_ migrator: DatabaseMigrator) throws {
        try migrator.migrate(dbWriter)
    }
}

extension ChangesetRepository {
    /// Provides a read-only access to the database.
    public var reader: any GRDB.DatabaseReader {
        dbWriter
    }
}

extension ChangesetRepository {
    public func commit<T>(meta: String = "{}", _ updates: (Database) throws -> T) throws -> T{
        try dbWriter.write { db in
            // 1. Start a session
            let session = try SQLiteSession(db.sqliteConnection!)
            
            // 2. Perform the update
            let result = try updates(db)
            
            // 3. Capture the changeset data
            let changesetData = try session.captureChangesetData()
            
            // 4. Get parent UUID
            let parent_uuid = try selectHeadUUID(db)
            
            // 5. Save the changeset data to the database
            let changeset = Changeset(
                parent_uuid: parent_uuid,
                parent_changeset: changesetData.data,
                pushed: false,
                meta: meta
            )
            try changeset.insert(db)
            
            // 6. Update the head UUID
            try updateHeadUUID(db, uuid: changeset.uuid)
            return result
        }
    }
    
    public func pull() throws -> Bool {
        var changeSetApplied = false
        try dbWriter.write { db in
            while true {
                let head = try selectHeadUUID(db)
                guard let child = try selectChangesetChild(db, uuid: head) else { break }
                let changesetData: ChangesetData
                if child.parent_uuid == head {
                    changesetData = ChangesetData(data: child.parent_changeset)
                } else {
                    changesetData = ChangesetData(data: child.merge_changeset!)
                }
                try changesetData.apply(db.sqliteConnection!)
                try updateHeadUUID(db, uuid: child.uuid)
                changeSetApplied = true
            }
        }
        return changeSetApplied
    }
}

// MARK: Database Access Methods

extension ChangesetRepository {
    private func selectHeadUUID(_ db: Database) throws -> String? {
        return try Head.fetchOne(db)!.uuid
    }
    
    private func selectChangesetChild(_ db: Database, uuid: String?) throws -> Changeset? {
        return try Changeset.fetchOne(db, sql: """
            SELECT
                *
            FROM changeset
            WHERE (:uuid IS NULL
            AND parent_uuid IS NULL)
               OR (:uuid IS NOT NULL
                   AND parent_uuid = :uuid)
               OR (:uuid IS NOT NULL
                   AND merge_uuid = :uuid)
            """, arguments: StatementArguments(
                ["uuid": uuid]
            ))
    }
    
    private func updateHeadUUID(_ db: Database, uuid: String?) throws {
        try Head.updateAll(db, Column("uuid").set(to: uuid))
    }
}

private struct ChangesetRepositoryKey: EnvironmentKey {
    /// The default appDatabase is an empty in-memory repository.
    static let defaultValue = ChangesetRepository.empty()
}

@available(macOS 10.15, *)
@available(iOS 13.0, *)
public extension EnvironmentValues {
    var changesetRepository: ChangesetRepository {
        get { self[ChangesetRepositoryKey.self] }
        set { self[ChangesetRepositoryKey.self] = newValue }
    }
}
