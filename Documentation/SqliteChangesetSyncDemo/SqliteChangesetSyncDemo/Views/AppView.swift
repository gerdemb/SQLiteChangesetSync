import GRDB
import GRDBQuery
import Players
import SwiftUI

/// The main application view
struct AppView: View {
    /// A helper `Identifiable` type that can feed SwiftUI `sheet(item:onDismiss:content:)`
    private struct EditedPlayer: Identifiable {
        var id: Int64
    }
    
    @Query(PlayerRequest())
    private var players: [Player]
    
    @State private var editedPlayer: EditedPlayer?
    
    var body: some View {
        NavigationView {
            VStack {
                if !players.isEmpty {
                    ForEach(players, id: \.id) { player in
                        PlayerView(player: player, editAction: { editPlayer(id: player.id!) })
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
                PlayerEditionView(id: player.id)
            }
            .navigationTitle("@Query Demo")
        }
    }
    
    private func footer() -> some View {
        VStack {
            Text("The demo application observes the database and displays information about the player.")
                .informationStyle()
            CreatePlayerButton("Create a Player")
        }
        .informationBox()
    }
    
    private func editPlayer(id: Int64) {
        editedPlayer = EditedPlayer(id: id)
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
