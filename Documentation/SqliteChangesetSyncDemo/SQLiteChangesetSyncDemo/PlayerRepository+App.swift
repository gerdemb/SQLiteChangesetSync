import Foundation
import GRDB

// A `PlayerRepository` extension for creating various repositories for the
// app, tests, and previews.
extension PlayerRepository {
    /// The on-disk repository for the application.
    static let empty = { try! PlayerRepository(DatabaseQueue()) }
    
    /// Returns an in-memory repository that contains one player,
    /// for previews and tests.
    ///
    /// - parameter playerId: The ID of the inserted player.
    static func populated(playerUUID: String? = nil) -> PlayerRepository {
        let repo = self.empty()
        _ = try! repo.insert(Player.makeRandom(uuid: playerUUID))
        return repo
    }
}
