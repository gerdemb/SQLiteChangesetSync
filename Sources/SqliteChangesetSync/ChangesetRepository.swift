//
//  ChangesetRepository.swift
//  
//
//  Created by Ben Gerdemann on 12/5/23.
//

import Foundation
import GRDB

public struct ChangesetRepository {
    public init(_ dbWriter: some GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }
    
    private let dbWriter: any DatabaseWriter

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif
        
        migrator.registerMigration("init") { db in
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