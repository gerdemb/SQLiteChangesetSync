//
//  GRDB+ChangesetManager.swift
//
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import GRDB
import SQLiteChangesetSync

extension GRDB.DatabaseWriter {
    public func writeWithChangeset<T>(_ updates: (Database) throws -> T) throws -> T {
        try write { db in
            let session = try SQLiteSession(db.sqliteConnection!)
            let result = try updates(db)
            let changesetData = try session.captureChangesetData()
            return result
        }
    }
}
