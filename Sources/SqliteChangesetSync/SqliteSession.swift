//
//  SqliteSession.swift
//
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import SqliteSessionExtension
import SQLite3
import GRDB

public class ChangesetData {
    let bytes: UnsafeMutableRawPointer
    let length: Int32
    private let mutableData: NSMutableData
    let data: Data
    
    init(bytes: UnsafeMutableRawPointer, length: Int32) {
        self.bytes = bytes
        self.length = length
        self.mutableData = NSMutableData(
            bytesNoCopy: bytes,
            length: Int(length),
            deallocator: { bytes, _ in sqlite3_free(bytes) }
        )
        self.data = Data(referencing: self.mutableData)
    }
    
    init(referencing data: Data) {
        self.data = data
        self.mutableData = NSMutableData(data: data)
        self.bytes = mutableData.mutableBytes
        self.length = Int32(mutableData.length)
    }
}

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

public class SqliteSession {
    let db: Database
    let session: OpaquePointer
    var hasCommited = false
    
    public init(_ db: Database) throws {
        self.db = db
        // Create session
        var session: OpaquePointer?
        try exec { sqlite3session_create(db.sqliteConnection!, "main", &session) }
        self.session = session!
        
        // Attach to all tables
        try exec { sqlite3session_attach(session, nil) }
    }
    
    deinit {
        sqlite3session_delete(session)
    }
    
    public func commit(meta: String = "{}") throws -> Changeset {
        guard !hasCommited else {
            fatalError("Don't call commit twice on the same SqliteSession object")
        }
        defer { hasCommited = true }

        // Capture the changeset
        var changeSet: UnsafeMutableRawPointer?
        var changeSetSize: Int32 = 0
        try exec { sqlite3session_changeset(session, &changeSetSize, &changeSet) }
        let changesetData = ChangesetData(bytes: changeSet!, length: changeSetSize)
        
        // Insert the new changeset
        let parent_uuid = try Head.fetchOne(db)!.uuid
        let changeset = Changeset(
            parent_uuid: parent_uuid,
            parent_changeset: changesetData.data,
            pushed: false,
            meta: meta
        )
        try changeset.insert(db)
        
        // Update head
        try Head.updateAll(db, [Column("uuid").set(to: changeset.uuid)])
        return changeset
    }
}

// Apply the changeset
func applyChangeSetData(_ db: OpaquePointer, _ changeSetData: ChangesetData, bIgnoreConflicts: Bool = true) throws {
    
    func xConflict(_ pCtx: UnsafeMutableRawPointer?, _ eConflict: Int32, _ pIter: OpaquePointer?) -> Int32 {
        let ret = pCtx?.load(as: Int32.self) ?? 0
        return ret
    }

    
    try exec {
        sqlite3changeset_apply(
            db,
            changeSetData.length,      // Size of changeset in bytes
            changeSetData.bytes,             // Changeset blob
            nil,                    // xFilter
            { (pCtx, eConflict, pIter) -> Int32 in
                return SQLITE_CHANGESET_OMIT
            },
            UnsafeMutableRawPointer(mutating: bIgnoreConflicts ? UnsafeRawPointer(bitPattern: 1) : UnsafeRawPointer(bitPattern: 0)))
    }
}

func combineChangesets(_ changeSets: [ChangesetData]) throws -> ChangesetData {
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

func printChangeset(_ changeSetData: ChangesetData) throws {
//    var rc: Int32

    // Create an iterator to iterate through the changeset
    var pIter: OpaquePointer?
    try exec { sqlite3changeset_start(&pIter, changeSetData.length, changeSetData.bytes) }
    defer { sqlite3changeset_finalize(pIter) }
    // This loop runs once for each change in the changeset
    while SQLITE_ROW == sqlite3changeset_next(pIter) {
        var zTab: UnsafePointer<Int8>?
        var nCol: Int32 = 0
        var op: Int32 = 0
        var pVal: OpaquePointer?

        // Print the type of operation and the table it is on
        try exec { sqlite3changeset_op(pIter, &zTab, &nCol, &op, nil) }
        print("\(op == SQLITE_INSERT ? "INSERT" : op == SQLITE_UPDATE ? "UPDATE" : "DELETE") on table \(String(cString: zTab!))")

        // If this is an UPDATE or DELETE, print the old.* values
        if op == SQLITE_UPDATE || op == SQLITE_DELETE {
            print("Old values:")
            for i in 0..<nCol {
                try exec { sqlite3changeset_old(pIter, i, &pVal) }
                print(" \(pVal != nil ? String(cString: sqlite3_value_text(pVal)) : "-")", terminator: "")
            }
            print("")
        }

        // If this is an UPDATE or INSERT, print the new.* values
        if op == SQLITE_UPDATE || op == SQLITE_INSERT {
            print("New values:")
            for i in 0..<nCol {
                try exec { sqlite3changeset_new(pIter, i, &pVal) }
                print(" \(pVal != nil ? String(cString: sqlite3_value_text(pVal)) : "-")", terminator: "")
            }
            print("")
        }
    }
}

