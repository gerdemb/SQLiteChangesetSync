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
                t.column("parent_changeset", .blob)
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
    
    public func reset() throws {
        try dbWriter.write { db in
            // I don't understand why it is necessary to set defer_foreign_keys here as the foreign keys are defined
            // as DEFERRABLE INITIALLY DEFERRED in the table definition, however if the defer_foreign_keys
            // PRAGMA is not set the "DELETE FROM changeset" statement will throw foreign key constraint violated
            // errors
            try db.execute(sql: "PRAGMA defer_foreign_keys = on")
            try updateHeadUUID(db, uuid: nil)
            try deleteChangesetAll(db)
        }
    }
}

extension ChangesetRepository {
    /// Provides a read-only access to the database.
    public var reader: any GRDB.DatabaseReader {
        dbWriter
    }
}

// MARK: - Repository Operations

extension ChangesetRepository {
    public func commit<T>(meta: String = "{}", _ updates: (Database) throws -> T) throws -> T{
        try dbWriter.write { db in
            // 1. Start a session
            let session = try SQLiteSession(db.sqliteConnection!)
            
            // 2. Perform the update
            let result = try updates(db)
            
            // 3. Capture the changeset data
            if let changesetData = try session.captureChangesetData() {
                
                // 4. Get parent UUID
                let parent_uuid = try selectHeadUUID(db)
                
                // 5. Save the changeset data to the database
                let changeset = Changeset(
                    parent_uuid: parent_uuid,
                    parent_changeset: changesetData.data,
                    pushed: false,
                    meta: meta
                )
                try insertChangeset(db, changeset: changeset)
                
                // 6. Update the head UUID
                try updateHeadUUID(db, uuid: changeset.uuid)
            }
            return result
        }
    }
    
    public func pull() throws -> Bool {
        var changeSetApplied = false
        try dbWriter.write { db in
            while true {
                // 1. Search for a child changeset
                let head = try selectHeadUUID(db)
                guard let child = try selectChangesetChild(db, uuid: head) else { break }
                
                // 2. Create ChangesetData
                let data: Data?
                if child.parent_uuid == head {
                    data = child.parent_changeset
                } else {
                    data = child.merge_changeset
                }
                
                // 3. Apply Changeset to Database
                if let data = data {
                    let changesetData = ChangesetData(data: data)
                    try changesetData.apply(db.sqliteConnection!)
                }
                
                // 4. Update head UUID
                try updateHeadUUID(db, uuid: child.uuid)
                changeSetApplied = true
            }
            if changeSetApplied {
                try db.notifyChanges(in: .fullDatabase)
            }
        }
        return changeSetApplied
    }
}

// MARK: - Merging

extension ChangesetRepository {
    private func branchChangesetData(_ db: Database, _ mainUUID: String, _ branchUUID: String) throws -> (changesetData: ChangesetData?, meta: [String]) {
        let changesets = try selectChangesetBranches(db, mainUUID: mainUUID, branchUUID: branchUUID)
        
        let changesetData = changesets
            .compactMap { $0.parent_changeset }
            .map { ChangesetData(data: $0) }
        let combinedData = try ChangesetData.combineChangesets(changesetData)
        
        let meta = changesets
            .map { $0.meta }

        return (combinedData, meta)
    }
    
    public func merge(_ mainUUID: String, _ branchUUID: String) throws -> Changeset {
        try dbWriter.write { db in
            let (parentChangesetData, parentMeta) = try branchChangesetData(db, mainUUID, branchUUID)
            let (mergeChangesetData, mergeMeta) = try branchChangesetData(db, branchUUID, mainUUID)
            
            let decodedParentMeta = decodeJSONStrings(parentMeta)
            let decodedMergeMeta = decodeJSONStrings(mergeMeta)
            let combinedDictionary = ["parentMeta": decodedParentMeta, "mergeMeta": decodedMergeMeta]
            let combinedJsonData = try JSONSerialization.data(withJSONObject: combinedDictionary)
            let meta = String(data: combinedJsonData, encoding: .utf8)

            let changeset = Changeset(
                uuid: UUID().uuidString,
                parent_uuid: mainUUID,
                parent_changeset: parentChangesetData?.data,
                merge_uuid: branchUUID,
                merge_changeset: mergeChangesetData?.data,
                pushed: false,
                meta: meta ?? "{}"
            )
            try insertChangeset(db, changeset: changeset)
            return changeset
        }
    }
    
    public func mergeAll() throws {
            while true {
                let leafNodes = try dbWriter.read { db in
                    try selectChangesetLeaves(db)
                }
                guard (leafNodes.count >= 2) else { break }
                let _ = try merge(leafNodes[0].uuid, leafNodes[1].uuid)
            }
    }
    
    private func decodeJSONStrings(_ jsonStrings: [String]) -> [Any] {
        return jsonStrings.compactMap { jsonString in
            guard let jsonData = jsonString.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: jsonData, options: [])
        }
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
    
    private func insertChangeset(_ db: Database, changeset: Changeset) throws {
        try changeset.insert(db)
    }
    
    private func deleteChangesetAll(_ db: Database) throws {
        try Changeset.deleteAll(db)
    }
    
    private func selectChangesetBranches(_ db: Database, mainUUID: String, branchUUID: String) throws -> [Changeset] {
        return try Changeset.fetchAll(db, sql: """
        WITH RECURSIVE
            AncestorsMain(uuid, parent_uuid, parent_changeset, merge_uuid, merge_changeset, pushed, meta, depth) AS (
                SELECT
                    uuid
                  , parent_uuid
                  , parent_changeset
                  , merge_uuid
                  , merge_changeset
                  , pushed
                  , meta
                  , 0 AS depth
                FROM changeset
                WHERE uuid = :mainUUID
                UNION ALL
                SELECT
                    n.uuid
                  , n.parent_uuid
                  , n.parent_changeset
                  , n.merge_uuid
                  , n.merge_changeset
                  , n.pushed
                  , n.meta
                  , a.depth + 1
                FROM changeset n
                INNER JOIN AncestorsMain a ON n.uuid = a.parent_uuid
                UNION ALL
                SELECT
                    n.uuid
                  , n.parent_uuid
                  , n.parent_changeset
                  , n.merge_uuid
                  , n.merge_changeset
                  , n.pushed
                  , n.meta
                  , a.depth + 1
                FROM changeset n
                INNER JOIN AncestorsMain a ON n.uuid = a.merge_uuid
                WHERE a.merge_uuid IS NOT NULL
            )
          , AncestorsBranch(uuid, parent_uuid, parent_changeset, merge_uuid, merge_changeset, pushed, meta, depth) AS (
              SELECT
                  uuid
                , parent_uuid
                , parent_changeset
                , merge_uuid
                , merge_changeset
                , pushed
                , meta
                , 0 AS depth
              FROM changeset
              WHERE uuid = :branchUUID
              UNION ALL
              SELECT
                  n.uuid
                , n.parent_uuid
                , n.parent_changeset
                , n.merge_uuid
                , n.merge_changeset
                , n.pushed
                , n.meta
                , a.depth + 1
              FROM changeset n
              INNER JOIN AncestorsBranch a ON n.uuid = a.parent_uuid
              UNION ALL
              SELECT
                  n.uuid
                , n.parent_uuid
                , n.parent_changeset
                , n.merge_uuid
                , n.merge_changeset
                , n.pushed
                , n.meta
                , a.depth + 1
              FROM changeset n
              INNER JOIN AncestorsBranch a ON n.uuid = a.merge_uuid
              WHERE a.merge_uuid IS NOT NULL
          )
        SELECT DISTINCT
            ab.uuid
          , ab.parent_uuid
          , ab.parent_changeset
          , ab.merge_uuid
          , ab.merge_changeset
          , ab.meta
          , ab.pushed
        FROM AncestorsBranch ab
        LEFT JOIN AncestorsMain am ON ab.uuid = am.uuid
        WHERE am.uuid IS NULL
          AND ab.merge_uuid IS NULL
        ORDER BY
            ab.depth DESC
    """, arguments: StatementArguments(
        ["mainUUID": mainUUID, "branchUUID": branchUUID]
    ))
    }
    
    private func selectChangesetLeaves(_ db: Database) throws -> [Changeset] {
        return try Changeset.fetchAll(db, sql: """
        SELECT
            *
        FROM changeset AS n
        WHERE NOT EXISTS (
        SELECT
            1
        FROM changeset AS m
        WHERE m.parent_uuid = n.uuid
        OR m.merge_uuid = n.uuid);
    """)
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
