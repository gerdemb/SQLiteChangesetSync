//
//  ChangesetData.swift
//  
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import SQLiteSessionExtension

public enum ChangesetOperationType {
    case insert, update, delete
}

public struct ChangesetOperation {
    var type: ChangesetOperationType
    var tableName: String
    var oldValues: [String?]
    var newValues: [String?]
}

public class ChangesetData {
    var data: Data
    
    init(bytes: UnsafeMutableRawPointer, count: Int32) {
        // Copy data
        self.data = Data(bytes: bytes, count: Int(count))
    }
    
    init(data: Data) {
        self.data = data
    }
    
    private func withUnsafeMutableBytes<ResultType>(_ body: (Int32, UnsafeMutableRawPointer) throws -> ResultType) rethrows -> ResultType {
        let count = data.count
        return try data.withUnsafeMutableBytes { pointer in
            let count = Int32(count)
            let bytes = pointer.baseAddress!
            return try body(count, bytes)
        }
    }
    
    func apply(_ sqliteConnection: OpaquePointer, bIgnoreConflicts: Bool = true) throws {
        try withUnsafeMutableBytes { count, bytes in
            try exec {
                sqlite3changeset_apply(
                    sqliteConnection,
                    count,      // Size of changeset in bytes
                    bytes,             // Changeset blob
                    nil,                    // xFilter
                    { (pCtx, eConflict, pIter) -> Int32 in
                        return SQLITE_CHANGESET_OMIT  // Just ignore conflicts for now
                    },
                    UnsafeMutableRawPointer(mutating: bIgnoreConflicts ? UnsafeRawPointer(bitPattern: 1) : UnsafeRawPointer(bitPattern: 0)))
            }
        }
    }
    
    public lazy var operations: Result<[ChangesetOperation], Error> = {
        do {
            return try withUnsafeMutableBytes { count, bytes in
                var changes = [ChangesetOperation]()
                var pIter: OpaquePointer?

                try exec { sqlite3changeset_start(&pIter, count, bytes) }
                defer { sqlite3changeset_finalize(pIter) }

                while SQLITE_ROW == sqlite3changeset_next(pIter) {
                    var zTab: UnsafePointer<Int8>?
                    var nCol: Int32 = 0
                    var op: Int32 = 0
                    var pVal: OpaquePointer?

                    try exec { sqlite3changeset_op(pIter, &zTab, &nCol, &op, nil) }
                    let tableName = String(cString: zTab!)
                    var oldValues: [String?] = []
                    var newValues: [String?] = []

                    if op == SQLITE_UPDATE || op == SQLITE_DELETE {
                        for i in 0..<nCol {
                            try exec { sqlite3changeset_old(pIter, i, &pVal) }
                            oldValues.append(pVal != nil ? String(cString: sqlite3_value_text(pVal)) : nil)
                        }
                    }

                    if op == SQLITE_UPDATE || op == SQLITE_INSERT {
                        for i in 0..<nCol {
                            try exec { sqlite3changeset_new(pIter, i, &pVal) }
                            newValues.append(pVal != nil ? String(cString: sqlite3_value_text(pVal)) : nil)
                        }
                    }

                    let change = ChangesetOperation(
                        type: op == SQLITE_INSERT ? .insert : op == SQLITE_UPDATE ? .update : .delete,
                        tableName: tableName,
                        oldValues: oldValues,
                        newValues: newValues
                    )
                    changes.append(change)
                }

                return .success(changes)
            }
        } catch {
            return .failure(error)
        }
    }()
    
    static func combineChangesets(_ changeSets: [ChangesetData]) throws -> ChangesetData {
        var pGrp: OpaquePointer?
        var pnOut: Int32 = 0
        var ppOut: UnsafeMutableRawPointer?
        
        try exec { sqlite3changegroup_new(&pGrp) }
        for changeset in changeSets {
            try changeset.withUnsafeMutableBytes { count, bytes in
                try exec { sqlite3changegroup_add(pGrp, count, bytes)
                }
            }
        }
        try exec { sqlite3changegroup_output(pGrp, &pnOut, &ppOut) }
        return ChangesetData(bytes: ppOut!, count: pnOut)
    }
}
