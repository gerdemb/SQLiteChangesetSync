import GRDB
import GRDBQuery
import SwiftUI

/// The main application view
struct AppView: View {
    @Environment(\.playerRepository) private var playerRepository
    
    /// A helper `Identifiable` type that can feed SwiftUI `sheet(item:onDismiss:content:)`
    private struct EditedPlayer: Identifiable {
        var id: String { return uuid }
        var uuid: String
    }
    
    @Query(PlayerRequest())
    private var players: [Player]
    
    @State private var editedPlayer: EditedPlayer?
    
    var body: some View {
        NavigationView {
            VStack {
                if !players.isEmpty {
                    ForEach(players, id: \.uuid) { player in
                        PlayerView(
                            player: player,
                            editAction: { editPlayer(uuid: player.uuid) },
                            deleteAction: { try? deletePlayer(player: player) }
                        )
                        .padding(.vertical)
                    }
                } else {
                    PlayerView(player: .placeholder)
                        .padding(.vertical)
                        .redacted(reason: .placeholder)
                }
                Spacer()
                footer()
            }
            .padding(.horizontal)
            .sheet(item: $editedPlayer) { player in
                PlayerEditionView(uuid: player.uuid)
            }
        }
    }
    
    private func footer() -> some View {
        VStack {
//            Text("The demo application observes the database and displays information about the player.")
//                .informationStyle()
            HStack {
                CreatePlayerButton("Create a Player")
                PushButton("Push")
            }
            HStack {
                FetchButton("Fetch")
                MergeButton("Merge")
                PullButton("Pull")
            }
            HStack {
                ResetDatabaseButton("Reset DB")
                ResetCloudKitButton("Reset CloudKit")
            }
        }
        .informationBox()
    }
    
    private func editPlayer(uuid: String) {
        editedPlayer = EditedPlayer(uuid: uuid)
    }
    
    private func deletePlayer(player: Player) throws {
        try playerRepository.deletePlayer(player)
    }
}

/// A @Query request that observes the player (any player, actually) in the database
private struct PlayerRequest: Queryable {
    static var defaultValue: [Player] { [] }
    
    func publisher(in playerRepository: PlayerRepository) -> DatabasePublishers.Value<[Player]> {
        ValueObservation
            .tracking(Player.fetchAll)
            .publisher(in: playerRepository.reader, scheduling: .immediate)
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView().environment(\.playerRepository, .empty())
            .previewDisplayName("Database Initially Empty")
        AppView().environment(\.playerRepository, .populated())
            .previewDisplayName("Database Initially Populated")
    }
}
