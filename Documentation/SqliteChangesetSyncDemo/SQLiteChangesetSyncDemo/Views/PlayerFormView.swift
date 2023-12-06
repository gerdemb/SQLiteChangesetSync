import GRDB
import SwiftUI

/// The view that edits a player
struct PlayerFormView: View {
    @Environment(\.changesetRepository) private var changesetRepository
    let player: Player
    
    var body: some View {
        Stepper(
            "Score: \(player.score)",
            onIncrement: { updateScore { $0 += 10 } },
            onDecrement: { updateScore { $0 = max(0, $0 - 10) } })
    }
    
    private func updateScore(_ transform: (inout Int) -> Void) {
        do {
            var updatedPlayer = player
            transform(&updatedPlayer.score)
            let meta = """
            { "message": "UPDATE \(updatedPlayer.uuid)" }
            """
            try changesetRepository.commit(meta: meta) { db in
                try updatedPlayer.update(db)
            }
        } catch RecordError.recordNotFound {
            // Oops, player does not exist.
            // Ignore this error: `PlayerEditionView` will dismiss.
        } catch {
            // Ignore other errors.
        }
    }
}

struct PlayerFormView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerFormView(player: .makeRandom())
            .padding()
    }
}
