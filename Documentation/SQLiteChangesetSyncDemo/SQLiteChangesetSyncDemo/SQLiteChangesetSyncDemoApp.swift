import SwiftUI
import SQLiteChangesetSync

@main
struct SQLiteChangesetSyncDemo: App {
    let dbWriter = DatabaseManager.shared
    let changsetRepository: ChangesetRepository
    let cloudKitManager: CloudKitManager
    let playerRepository: PlayerRepository

    var body: some Scene {
        WindowGroup {
            AppView()
                // Use the on-disk repository in the application
                .environment(\.changesetRepository, changsetRepository)
                .environment(\.cloudKitManager, cloudKitManager)
                .environment(\.playerRepository, playerRepository)
        }
    }
    
    init() {
        do {
            self.changsetRepository = try ChangesetRepository(dbWriter)
            self.cloudKitManager = CloudKitManager(dbWriter)
            self.playerRepository = try PlayerRepository(changsetRepository)
        } catch {
            fatalError("Could not start app \(error)")
        }
    }
}
