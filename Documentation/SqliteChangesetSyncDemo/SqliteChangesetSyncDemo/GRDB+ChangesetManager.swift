//
//  GRDB+ChangesetManager.swift
//
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import GRDB
import SqliteChangesetSync

extension GRDB.DatabaseWriter {
    public func writeWithChangeset<T>(meta: String = "{}", _ updates: (Database) throws -> T) throws -> T {
        try writeWithoutTransaction { db in
            var result: T?
            try db.inTransaction {
                let session = try SqliteSession(db.sqliteConnection!)
                result = try updates(db)
                _ = try session.commit(meta: meta)
                return .commit
            }
            return result!
        }
    }
}
