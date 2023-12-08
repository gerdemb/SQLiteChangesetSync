//
//  Logger.swift
//
//
//  Created by Ben Gerdemann on 12/8/23.
//

import Foundation
import OSLog

@available(iOS 14.0, *)
extension Logger {
    private static var subsystem = "SQLiteChangesetSync"

    public static let sqliteChangesetSync = Logger(subsystem: subsystem, category: "SQLiteChangesetSync")
}
