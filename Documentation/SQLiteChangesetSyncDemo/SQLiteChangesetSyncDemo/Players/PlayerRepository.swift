import Foundation
import GRDB
import os.log
import SQLiteChangesetSync

/// A repository of players.
///
/// You create a `PlayerRepository` with a
/// [connection to an SQLite database](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections),
/// created with a configuration returned from
/// ``makeConfiguration(_:)``.
///
/// For example:
///
/// ```swift
/// // Create an in-memory PlayerRepository
/// let config = PlayerRepository.makeConfiguration()
/// let dbQueue = try DatabaseQueue(configuration: config)
/// let repository = try PlayerRepository(dbQueue)
/// ```
///
/// ## Topics
///
/// ### Creating a repository
///
/// - ``init(_:)``
/// - ``makeConfiguration(_:)``
///
/// ### Performing read-only accesses
///
/// - ``reader``
///
/// ### Performing writes
///
/// - ``deleteAllPlayer()``
/// - ``insert(_:)``
/// - ``update(_:)``
public struct PlayerRepository {
    /// Creates a `PlayerRepository`, and makes sure the database schema
    /// is ready.
    ///
    /// - important: Create the `DatabaseWriter` with a configuration
    ///   returned by ``makeConfiguration(_:)``.
    public init(_ dbWriter: some GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }
    
    /// Provides access to the database.
    ///
    /// Application can use a `DatabasePool`, while SwiftUI previews and tests
    /// can use a fast in-memory `DatabaseQueue`.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections>
    private let dbWriter: any DatabaseWriter
    
    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createPlayer") { db in
            // Create a table
            // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseschema>
            try db.create(table: "player") { t in
                t.primaryKey("uuid", .text)
                t.column("name", .text).notNull()
                t.column("score", .integer).notNull()
                t.column("photoID", .integer).notNull()
            }
        }
        
        // Migrations for future application versions will be inserted here:
        // migrator.registerMigration(...) { db in
        //     ...
        // }
        
        return migrator
    }
}

// MARK: - Database Access: Writes
// The write methods execute invariant-preserving database transactions.
// In this demo repository, they are pretty simple.

extension PlayerRepository {
    /// Inserts a player and returns the inserted player.
    public func insert(_ player: Player) throws -> Player {
        try dbWriter.write { db in
            try player.inserted(db)
        }
    }
    
    /// Updates the player.
    public func update(_ player: Player) throws {
        try dbWriter.write { db in
            try player.update(db)
        }
    }
    
    /// Deletes all players.
    public func deleteAllPlayer() throws {
        try dbWriter.write { db in
            _ = try Player.deleteAll(db)
        }
    }
    
    /// Delete a player.
    public func deletePlayer(_ uuid: String) throws {
        try dbWriter.write { db in
            _ = try Player.deleteOne(db, key: uuid)
        }
    }
}

// MARK: - Database Access: Reads

// This demo app does not provide any specific reading method, and instead
// gives an unrestricted read-only access to the rest of the application.
// In your app, you are free to choose another path, and define focused
// reading methods.
extension PlayerRepository {
    /// Provides a read-only access to the database.
    public var reader: any GRDB.DatabaseReader {
        dbWriter
    }
}
