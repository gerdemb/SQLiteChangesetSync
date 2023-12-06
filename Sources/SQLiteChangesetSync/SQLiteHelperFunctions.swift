//
//  SqliteHelperFunctions.swift
//  
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import SQLite3

enum SQLiteError: Error {
    case operationFailed(String)
}

func exec(operation: () -> Int32) throws {
    let resultCode = operation()
    if resultCode != SQLITE_OK {
        let errmsg = String(cString: sqlite3_errstr(resultCode))
        throw SQLiteError.operationFailed(errmsg)
    }
}
