import SwiftUI
import SqliteChangesetSync
import Players

@main
struct SqliteChangesetSyncDemoApp: App {
    let changsetRepository = { try! ChangesetRepository(DatabaseManager.shared) }()
    let playerRepository = { try! PlayerRepository(DatabaseManager.shared) }()

    var body: some Scene {
        WindowGroup {
            AppView()
                // Use the on-disk repository in the application
                .environment(\.playerRepository, playerRepository)
                .environment(\.changesetRepository, changsetRepository)
        }
    }
}
