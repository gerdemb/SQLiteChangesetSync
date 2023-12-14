//
//  Logger.swift
//  SQLiteChangesetSyncDemo
//
//  Created by Ben Gerdemann on 12/8/23.
//

import Foundation
import OSLog

@available(iOS 14.0, *)
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    public static let sqliteChangesetSyncDemo = Logger(subsystem: subsystem, category: "SQLiteChangesetSyncDemo")
    public static let SQL = Logger(subsystem: subsystem, category: "SQL")

}
