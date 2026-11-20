import ActivityKit
import Foundation

enum DeskTaskKind: String, Codable, Hashable {
    case download
    case decrypt
}

struct DeskTaskAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var progress: Double
        var detail: String
        var kind: String
        var done: Bool
    }

    var kind: String
    var startedAt: Date
}
