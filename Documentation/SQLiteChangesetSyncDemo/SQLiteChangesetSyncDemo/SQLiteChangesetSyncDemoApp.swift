import SwiftUI
import SQLiteChangesetSync

@main
struct SQLiteChangesetSyncDemo: App {
    let dbWriter = DatabaseManager.shared
    let changsetRepository: ChangesetRepository
    let playerRepository: PlayerRepository

    var body: some Scene {
        WindowGroup {
            AppView()
                // Use the on-disk repository in the application
                .environment(\.playerRepository, playerRepository)
                .environment(\.changesetRepository, changsetRepository)
        }
    }
    
    init() {
        do {
            self.changsetRepository = try ChangesetRepository(dbWriter)
            self.playerRepository = try PlayerRepository(changsetRepository)
        } catch {
            fatalError("Could not init \(error)")
        }
    }
}
