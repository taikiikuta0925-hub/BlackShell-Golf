import Combine
import Foundation
import WatchConnectivity

struct WatchPlayer: Identifiable, Equatable {
  let id: Int
  let name: String
  let holeScore: Int
  let entered: Bool
  let totalScore: Int
  let toPar: Int

  init(index: Int, dictionary: [String: Any]) {
    id = index
    name = dictionary["name"] as? String ?? "Player \(index + 1)"
    holeScore = (dictionary["holeScore"] as? NSNumber)?.intValue ?? 0
    entered = dictionary["entered"] as? Bool ?? false
    totalScore = (dictionary["totalScore"] as? NSNumber)?.intValue ?? 0
    toPar = (dictionary["toPar"] as? NSNumber)?.intValue ?? 0
  }
}

struct WatchRoundState: Equatable {
  let active: Bool
  let courseName: String
  let holeNumber: Int
  let holeIndex: Int
  let holeCount: Int
  let par: Int
  let yards: Int?
  let currentPlayerIndex: Int
  let statusCode: String
  let holeComplete: Bool
  let isLastHole: Bool
  let players: [WatchPlayer]

  static let empty = WatchRoundState(
    active: false,
    courseName: "BlackShell Golf",
    holeNumber: 1,
    holeIndex: 0,
    holeCount: 18,
    par: 4,
    yards: nil,
    currentPlayerIndex: 0,
    statusCode: "scoring",
    holeComplete: false,
    isLastHole: false,
    players: []
  )

  init(dictionary: [String: Any]) {
    active = dictionary["active"] as? Bool ?? true
    courseName = dictionary["courseName"] as? String ?? "BlackShell Golf"
    holeNumber = (dictionary["holeNumber"] as? NSNumber)?.intValue ?? 1
    holeIndex = (dictionary["holeIndex"] as? NSNumber)?.intValue ?? 0
    holeCount = (dictionary["holeCount"] as? NSNumber)?.intValue ?? 18
    par = (dictionary["par"] as? NSNumber)?.intValue ?? 4
    yards = (dictionary["yards"] as? NSNumber)?.intValue
    currentPlayerIndex =
      (dictionary["currentPlayerIndex"] as? NSNumber)?.intValue ?? 0
    holeComplete = dictionary["holeComplete"] as? Bool ?? false
    isLastHole = dictionary["isLastHole"] as? Bool ?? false
    statusCode = dictionary["statusCode"] as? String
      ?? (holeComplete ? "readyForNextHole" : "scoring")

    let rawPlayers = dictionary["players"] as? [[String: Any]] ?? []
    players = rawPlayers.enumerated().map { index, value in
      WatchPlayer(index: index, dictionary: value)
    }
  }

  private init(
    active: Bool,
    courseName: String,
    holeNumber: Int,
    holeIndex: Int,
    holeCount: Int,
    par: Int,
    yards: Int?,
    currentPlayerIndex: Int,
    statusCode: String,
    holeComplete: Bool,
    isLastHole: Bool,
    players: [WatchPlayer]
  ) {
    self.active = active
    self.courseName = courseName
    self.holeNumber = holeNumber
    self.holeIndex = holeIndex
    self.holeCount = holeCount
    self.par = par
    self.yards = yards
    self.currentPlayerIndex = currentPlayerIndex
    self.statusCode = statusCode
    self.holeComplete = holeComplete
    self.isLastHole = isLastHole
    self.players = players
  }
}

final class WatchRoundStore: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var state = WatchRoundState.empty
  @Published private(set) var isReachable = false
  @Published private(set) var lastError: String?

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }

    let session = WCSession.default
    session.delegate = self
    session.activate()
    isReachable = session.isReachable

    if !session.receivedApplicationContext.isEmpty {
      state = WatchRoundState(dictionary: session.receivedApplicationContext)
    }
  }

  func requestLatestState() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else { return }

    session.sendMessage(
      ["command": "requestState"],
      replyHandler: { [weak self] reply in
        guard let dictionary = reply["state"] as? [String: Any] else { return }
        self?.apply(dictionary)
      },
      errorHandler: { [weak self] error in
        self?.show(error)
      }
    )
  }

  func send(
    command: String,
    playerIndex: Int? = nil,
    delta: Int? = nil
  ) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      DispatchQueue.main.async { [weak self] in
        self?.lastError = NSLocalizedString(
          "watch.error.connect_iphone",
          comment: ""
        )
      }
      return
    }

    var message: [String: Any] = ["command": command]
    if let playerIndex {
      message["playerIndex"] = playerIndex
    }
    if let delta {
      message["delta"] = delta
    }

    session.sendMessage(
      message,
      replyHandler: nil,
      errorHandler: { [weak self] error in
        self?.show(error)
      }
    )
  }

  func clearError() {
    lastError = nil
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.isReachable = session.isReachable
      if let error {
        self?.lastError = error.localizedDescription
      }
    }

    if activationState == .activated {
      if !session.receivedApplicationContext.isEmpty {
        apply(session.receivedApplicationContext)
      }
      requestLatestState()
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { [weak self] in
      self?.isReachable = session.isReachable
      if session.isReachable {
        self?.lastError = nil
      }
    }
    if session.isReachable {
      requestLatestState()
    }
  }

  func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    apply(applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard message["type"] as? String == "roundState",
          let dictionary = message["state"] as? [String: Any] else {
      return
    }
    apply(dictionary)
  }

  private func apply(_ dictionary: [String: Any]) {
    let newState = WatchRoundState(dictionary: dictionary)
    DispatchQueue.main.async { [weak self] in
      self?.state = newState
      self?.lastError = nil
    }
  }

  private func show(_ error: Error) {
    DispatchQueue.main.async { [weak self] in
      self?.lastError = error.localizedDescription
    }
  }
}
