import SwiftUI
import OSLog

/// A helper button that creates players in the database
struct CreatePlayerButton: View {
    @Environment(\.playerRepository) private var playerRepository
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            let player = Player.makeRandom()
            do {
                _ = try playerRepository.insert(player)
            } catch {
                Logger.sqliteChangesetSyncDemo.error("Player insert error \(error)")
            }
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}

// For tracking the player count in the preview
import GRDB
import GRDBQuery

struct DatabaseButtons_Previews: PreviewProvider {
    struct PlayerCountRequest: Queryable {
        static var defaultValue: Int { 0 }
        
        func publisher(in playerRepository: PlayerRepository) -> DatabasePublishers.Value<Int> {
            ValueObservation
                .tracking(Player.fetchCount)
                .publisher(in: playerRepository.reader, scheduling: .immediate)
        }
    }
    
    struct Preview: View {
        @Query(PlayerCountRequest())
        var playerCount: Int
        
        var body: some View {
            VStack {
                Text("Number of players: \(playerCount)")
                CreatePlayerButton("Create Player")
            }
            .informationBox()
            .padding()
        }
    }
    
    static var previews: some View {
        Preview()
    }
}
