import SwiftUI
import SQLiteChangesetSync

@main
struct SQLiteChangesetSyncDemo: App {
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
