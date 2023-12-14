import GRDB
import Foundation

// Equatable for testability
/// A player.
public struct Player: Codable, Equatable {
    private(set) public var uuid: String
    public var name: String
    public var score: Int
    public var photoID: Int
    
    public init(
        uuid: String? = nil,
        name: String,
        score: Int,
        photoID: Int)
    {
        if let uuid = uuid {
            self.uuid = uuid
        } else {
            self.uuid = UUID().uuidString
        }
        self.name = name
        self.score = score
        self.photoID = photoID
    }
}

extension Player: FetchableRecord, PersistableRecord {
}
