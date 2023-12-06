//
//  SqliteSession.swift
//
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import SqliteSessionExtension

public class ChangesetData {
    let bytes: UnsafeMutableRawPointer
    let length: Int32
    private let mutableData: NSMutableData
    
    init(bytes: UnsafeMutableRawPointer, length: Int32) {
        self.bytes = bytes
        self.length = length
        self.mutableData = NSMutableData(
            bytesNoCopy: bytes,
            length: Int(length),
            deallocator: { bytes, _ in sqlite3_free(bytes) }
        )
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
    
    func printDebug() throws {
        // Create an iterator to iterate through the changeset
        var pIter: OpaquePointer?
        try exec { sqlite3changeset_start(&pIter, self.length, self.bytes) }
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
    let session: OpaquePointer
    
    public init(_ sqliteConnection: OpaquePointer) throws {
        // Create session
        var session: OpaquePointer?
        try exec { sqlite3session_create(sqliteConnection, "main", &session) }
        self.session = session!
        
        // Attach to all tables
        try exec { sqlite3session_attach(session, nil) }
    }
    
    deinit {
        sqlite3session_delete(session)
    }
    
    public func captureChangesetData() throws -> ChangesetData {
        /// If called a second time on a session object, the changeset will contain all changes that have taken place on the connection since the session was created.
        /// In other words, a session object is not reset or zeroed by a call to sqlite3session_changeset().
        var changeSet: UnsafeMutableRawPointer?
        var changeSetSize: Int32 = 0
        try exec { sqlite3session_changeset(session, &changeSetSize, &changeSet) }
        return ChangesetData(bytes: changeSet!, length: changeSetSize)
    }
}
