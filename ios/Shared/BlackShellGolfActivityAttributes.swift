import ActivityKit
import Foundation

struct BlackShellGolfActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var courseName: String
    var holeNumber: Int
    var holeCount: Int
    var par: Int
    var currentPlayerName: String
    var currentHoleScore: Int
    var currentHoleEntered: Bool
    var currentToPar: Int
    var leaderName: String
    var leaderToPar: Int
    var statusLabel: String
    var statusCode: String
    var isComplete: Bool
  }

  var roundID: String
}
