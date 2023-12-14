import SwiftUI
import SQLiteChangesetSync
import CloudKit
import OSLog


enum CloudKitConfig {
    static let containerIdentifier = "iCloud.com.github.gerdemb.SQLiteChangesetSyncDemo"
    static let zoneName = "ChangeSets"
    static let subscriptionID = "changeset-subscription-id"
}

extension Notification.Name {
    static let didReceiveRemoteNotification = Notification.Name("didReceiveRemoteNotification")
}


@main
struct SQLiteChangesetSyncDemo: App {
    @UIApplicationDelegateAdaptor(SQLiteChangesetSyncDemoAppDelegate.self) private var appDelegate
    let dbWriter = DatabaseManager.shared
    let changesetRepository: ChangesetRepository
    let cloudKitManager: CloudKitManager
    let playerRepository: PlayerRepository
    
    var body: some Scene {
        WindowGroup {
            AppView()
            // Use the on-disk repository in the application
                .environment(\.changesetRepository, changesetRepository)
                .environment(\.cloudKitManager, cloudKitManager)
                .environment(\.playerRepository, playerRepository)
        }
    }
    
    init() {
        do {
            self.changesetRepository = try ChangesetRepository(dbWriter)
            self.cloudKitManager = CloudKitManager(dbWriter, config: SQLiteChangesetSyncDemo.getCloudKitManagerConfig())
            self.playerRepository = try PlayerRepository(changesetRepository)
            NotificationCenter.default.addObserver(forName: .didReceiveRemoteNotification, object: nil, queue: .main) { [self] notification in
                handleDidReceiveRemoteNotification(notification)
            }
        } catch {
            fatalError("Could not start app \(error)")
        }
    }
    
    private static func getCloudKitManagerConfig() -> CloudKitManagerConfig {
        let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
        let database = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: CloudKitConfig.zoneName)
        let subscriptionID = CloudKitConfig.subscriptionID
        return CloudKitManagerConfig(
            database: database,
            zone: zone,
            subscriptionID: subscriptionID
        )
    }
    
    private func handleDidReceiveRemoteNotification(_ notification: Notification) {
        let userInfo = notification.userInfo
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject]) else {
            return
        }
        
        if let _ = ckNotification as? CKRecordZoneNotification {
            Task {
                do {
                    _ = try await cloudKitManager.fetch()
                    try changesetRepository.mergeAll()
                    _ = try changesetRepository.pull()
                } catch {
                    Logger.sqliteChangesetSyncDemo.error("Error in handleDidReceiveRemoteNotification \(error)")
                }
            }
        }
    }
}

final class SQLiteChangesetSyncDemoAppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logger.sqliteChangesetSyncDemo.info("Registering for remote notifications")
        application.registerForRemoteNotifications()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Logger.sqliteChangesetSyncDemo.info("Did register for remote notifications")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.sqliteChangesetSyncDemo.error("Failed to register for notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        Logger.sqliteChangesetSyncDemo.info("Received remote notification")
        NotificationCenter.default.post(name: .didReceiveRemoteNotification, object: nil, userInfo: userInfo)
    }
}
