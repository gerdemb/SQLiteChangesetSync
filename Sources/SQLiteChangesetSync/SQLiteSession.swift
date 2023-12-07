//
//  SqliteSession.swift
//
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import SQLiteSessionExtension

public class SQLiteSession {
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
    
    public func captureChangesetData() throws -> ChangesetData? {
        /// If called a second time on a session object, the changeset will contain all changes that have taken place on the connection since the session was created.
        /// In other words, a session object is not reset or zeroed by a call to sqlite3session_changeset().
        var bytes: UnsafeMutableRawPointer?
        var count: Int32 = 0
        try exec { sqlite3session_changeset(session, &count, &bytes) }
        if bytes != nil {
            defer { sqlite3_free(bytes) }
            return ChangesetData(bytes: bytes!, count: count)
        }
        return nil
    }
}
