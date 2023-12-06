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
    static let empty = { try! ChangesetRepository(DatabaseQueue()) }

    public init(_ dbWriter: some GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
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
            let parent_uuid = try Head.fetchOne(db)!.uuid
            
            // 5. Save the changeset data to the database
            let changeset = Changeset(
                parent_uuid: parent_uuid,
                parent_changeset: changesetData.data,
                pushed: false,
                meta: meta
            )
            try changeset.insert(db)
            
            // 6. Update the head UUID
            try Head.updateAll(db, Column("uuid").set(to: changeset.uuid))
            return result
        }
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
