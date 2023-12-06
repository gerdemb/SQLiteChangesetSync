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
    let bytes: UnsafeMutableRawPointer
    let length: Int32
    lazy var data = {
        Data(bytes: bytes, count: Int(length))
    }()
    
    init(bytes: UnsafeMutableRawPointer, length: Int32) {
        self.bytes = bytes
        self.length = length
    }
    
    deinit {
        sqlite3_free(bytes)
    }
    
    func apply(_ sqliteConnection: OpaquePointer, bIgnoreConflicts: Bool = true) throws {
        try exec {
            sqlite3changeset_apply(
                sqliteConnection,
                self.length,      // Size of changeset in bytes
                self.bytes,             // Changeset blob
                nil,                    // xFilter
                { (pCtx, eConflict, pIter) -> Int32 in
                    return SQLITE_CHANGESET_OMIT  // Just ignore conflicts for now
                },
                UnsafeMutableRawPointer(mutating: bIgnoreConflicts ? UnsafeRawPointer(bitPattern: 1) : UnsafeRawPointer(bitPattern: 0)))
        }
    }
    
    public lazy var operations = {
        do {
            var changes = [ChangesetOperation]()
            var pIter: OpaquePointer?

            try exec { sqlite3changeset_start(&pIter, self.length, self.bytes) }
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

            return changes
        } catch {
            debugPrint("Error getting changeset operations \(error)")
            return []
        }
    }()
    
    static func combineChangesets(_ changeSets: [ChangesetData]) throws -> ChangesetData {
        var pGrp: OpaquePointer?
        var pnOut: Int32 = 0
        var ppOut: UnsafeMutableRawPointer?
        
        try exec { sqlite3changegroup_new(&pGrp) }
        for changeSet in changeSets {
            try exec { sqlite3changegroup_add(pGrp, changeSet.length, changeSet.bytes) }
        }
        try exec { sqlite3changegroup_output(pGrp, &pnOut, &ppOut) }
        return ChangesetData(bytes: ppOut!, length: pnOut)
    }
}
