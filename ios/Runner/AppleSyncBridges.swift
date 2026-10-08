import ActivityKit
import Flutter
import Foundation
import WatchConnectivity

final class WatchRoundBridge: NSObject, WCSessionDelegate {
  private let channel: FlutterMethodChannel
  private var lastRoundContext: [String: Any] = ["active": false]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "blackshell/watch",
      binaryMessenger: messenger
    )
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }

    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(availability())

    case "updateRound":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "updateRound expects a round-state map.",
            details: nil
          )
        )
        return
      }
      publish(arguments, result: result)

    case "clearRound":
      publish(["active": false], result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func availability() -> [String: Any] {
    guard WCSession.isSupported() else {
      return [
        "supported": false,
        "paired": false,
        "installed": false,
        "reachable": false,
        "activationState": "unsupported",
      ]
    }

    let session = WCSession.default
    return [
      "supported": true,
      "paired": session.isPaired,
      "installed": session.isWatchAppInstalled,
      "reachable": session.isReachable,
      "activationState": activationStateName(session.activationState),
    ]
  }

  private func publish(_ state: [String: Any], result: @escaping FlutterResult) {
    guard WCSession.isSupported() else {
      result(false)
      return
    }

    var context = sanitizedDictionary(state)
    context["protocolVersion"] = 1
    context["updatedAt"] = Date().timeIntervalSince1970
    lastRoundContext = context

    let session = WCSession.default
    guard session.activationState == .activated else {
      session.activate()
      result(false)
      return
    }

    do {
      try session.updateApplicationContext(context)
      if session.isReachable {
        session.sendMessage(
          ["type": "roundState", "state": context],
          replyHandler: nil,
          errorHandler: nil
        )
      }
      result(true)
    } catch {
      result(
        FlutterError(
          code: "watch_sync_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func deliverCommand(_ message: [String: Any]) {
    guard let command = message["command"] as? String,
          command != "requestState" else {
      return
    }

    var payload = sanitizedDictionary(message)
    payload["receivedAt"] = Date().timeIntervalSince1970
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("watchCommand", arguments: payload)
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if activationState == .activated {
      sendLastRoundContext(using: session)
    }
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod(
        "availabilityChanged",
        arguments: self?.availability()
      )
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod(
        "availabilityChanged",
        arguments: self?.availability()
      )
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    deliverCommand(message)
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    if message["command"] as? String == "requestState" {
      replyHandler(["state": lastRoundContext])
      return
    }

    deliverCommand(message)
    replyHandler(["accepted": true])
  }

  private func activationStateName(_ state: WCSessionActivationState) -> String {
    switch state {
    case .notActivated:
      return "notActivated"
    case .inactive:
      return "inactive"
    case .activated:
      return "activated"
    @unknown default:
      return "unknown"
    }
  }

  private func sendLastRoundContext(using session: WCSession) {
    do {
      try session.updateApplicationContext(lastRoundContext)
      if session.isReachable {
        session.sendMessage(
          ["type": "roundState", "state": lastRoundContext],
          replyHandler: nil,
          errorHandler: nil
        )
      }
    } catch {
      // The next score update or Watch request retries delivery.
    }
  }

  private func sanitizedDictionary(_ value: [String: Any]) -> [String: Any] {
    value.reduce(into: [String: Any]()) { output, entry in
      if let sanitized = sanitize(entry.value) {
        output[entry.key] = sanitized
      }
    }
  }

  private func sanitize(_ value: Any) -> Any? {
    switch value {
    case is NSNull:
      return nil
    case let value as String:
      return value
    case let value as NSNumber:
      return value
    case let value as Date:
      return value
    case let value as Data:
      return value
    case let value as [String: Any]:
      return sanitizedDictionary(value)
    case let value as [Any]:
      return value.compactMap(sanitize)
    default:
      return String(describing: value)
    }
  }
}

@available(iOS 16.1, *)
final class GolfLiveActivityBridge {
  private let channel: FlutterMethodChannel
  private var activeActivityID: String?
  private var startupCleanupTask: Task<Void, Never>?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "blackshell/live_activity",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    dismissActivitiesFromPreviousLaunch()
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result([
        "supported": true,
        "enabled": ActivityAuthorizationInfo().areActivitiesEnabled,
        "activeActivityID": currentActivity()?.id as Any,
      ])

    case "start":
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        result(
          FlutterError(
            code: "live_activities_disabled",
            message: "Live Activities are disabled for this device or app.",
            details: nil
          )
        )
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let contentState = contentState(from: arguments) else {
        result(invalidStateError())
        return
      }
      start(arguments: arguments, contentState: contentState, result: result)

    case "update":
      guard let arguments = call.arguments as? [String: Any],
            let contentState = contentState(from: arguments) else {
        result(invalidStateError())
        return
      }
      update(
        arguments: arguments,
        contentState: contentState,
        result: result
      )

    case "end":
      let arguments = call.arguments as? [String: Any]
      let finalState = arguments.flatMap(contentState(from:))
      let immediate = arguments?["immediate"] as? Bool ?? true
      end(
        arguments: arguments,
        finalState: finalState,
        immediate: immediate,
        result: result
      )

    case "endAll":
      endAll(result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(
    arguments: [String: Any],
    contentState: BlackShellGolfActivityAttributes.ContentState,
    result: @escaping FlutterResult
  ) {
    let roundID = roundID(from: arguments) ?? UUID().uuidString
    let content = ActivityContent(state: contentState, staleDate: nil)
    let cleanupTask = startupCleanupTask

    Task { @MainActor in
      await cleanupTask?.value
      self.startupCleanupTask = nil

      if let activity = self.currentActivity(roundID: roundID) {
        self.activeActivityID = activity.id
        await activity.update(content)
        result(activity.id)
        return
      }

      do {
        let attributes = BlackShellGolfActivityAttributes(roundID: roundID)
        let activity = try Activity.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
        self.activeActivityID = activity.id
        result(activity.id)
      } catch {
        result(
          FlutterError(
            code: "live_activity_start_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func update(
    arguments: [String: Any],
    contentState: BlackShellGolfActivityAttributes.ContentState,
    result: @escaping FlutterResult
  ) {
    guard let activity = currentActivity(roundID: roundID(from: arguments)) else {
      result(
        FlutterError(
          code: "live_activity_not_found",
          message: "There is no Live Activity for this golf round.",
          details: nil
        )
      )
      return
    }

    let content = ActivityContent(state: contentState, staleDate: nil)
    Task { @MainActor in
      await activity.update(content)
      self.activeActivityID = activity.id
      result(activity.id)
    }
  }

  private func end(
    arguments: [String: Any]?,
    finalState: BlackShellGolfActivityAttributes.ContentState?,
    immediate: Bool,
    result: @escaping FlutterResult
  ) {
    let activities = activities(roundID: arguments.flatMap(roundID(from:)))
    guard !activities.isEmpty else {
      result(false)
      return
    }
    let activityIDs = Set(activities.map(\.id))

    Task { @MainActor in
      for activity in activities {
        let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        await activity.end(
          content,
          dismissalPolicy: immediate ? .immediate : .default
        )
      }
      if let activeActivityID = self.activeActivityID,
         activityIDs.contains(activeActivityID) {
        self.activeActivityID = nil
      }
      result(true)
    }
  }

  private func endAll(result: @escaping FlutterResult) {
    let activities = Activity<BlackShellGolfActivityAttributes>.activities
    Task { @MainActor in
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      self.activeActivityID = nil
      result(activities.count)
    }
  }

  private func currentActivity(
    roundID: String? = nil
  ) -> Activity<BlackShellGolfActivityAttributes>? {
    let activities = activities(roundID: roundID)
    if let activeActivityID,
       let activity = activities.first(where: { $0.id == activeActivityID }) {
      return activity
    }
    return activities.first
  }

  private func activities(
    roundID: String?
  ) -> [Activity<BlackShellGolfActivityAttributes>] {
    let activities = Activity<BlackShellGolfActivityAttributes>.activities
    guard let roundID else {
      return activities
    }
    return activities.filter { $0.attributes.roundID == roundID }
  }

  private func roundID(from arguments: [String: Any]) -> String? {
    guard let roundID = arguments["roundId"] as? String,
          !roundID.isEmpty else {
      return nil
    }
    return roundID
  }

  private func dismissActivitiesFromPreviousLaunch() {
    let staleActivities = Activity<BlackShellGolfActivityAttributes>.activities
    guard !staleActivities.isEmpty else {
      return
    }

    startupCleanupTask = Task { @MainActor [weak self] in
      for activity in staleActivities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      self?.activeActivityID = nil
    }
  }

  private func contentState(
    from arguments: [String: Any]
  ) -> BlackShellGolfActivityAttributes.ContentState? {
    guard arguments["courseName"] is String,
          arguments["currentPlayerName"] is String else {
      return nil
    }

    return BlackShellGolfActivityAttributes.ContentState(
      courseName: string(arguments, "courseName", fallback: "BlackShell Golf"),
      holeNumber: integer(arguments, "holeNumber", fallback: 1),
      holeCount: integer(arguments, "holeCount", fallback: 18),
      par: integer(arguments, "par", fallback: 4),
      currentPlayerName: string(arguments, "currentPlayerName", fallback: "Player"),
      currentHoleScore: integer(arguments, "currentHoleScore", fallback: 0),
      currentHoleEntered: arguments["currentHoleEntered"] as? Bool ?? false,
      currentToPar: integer(arguments, "currentToPar", fallback: 0),
      leaderName: string(arguments, "leaderName", fallback: ""),
      leaderToPar: integer(arguments, "leaderToPar", fallback: 0),
      statusLabel: string(arguments, "statusLabel", fallback: "Scoring"),
      statusCode: string(arguments, "statusCode", fallback: "scoring"),
      isComplete: arguments["isComplete"] as? Bool ?? false
    )
  }

  private func invalidStateError() -> FlutterError {
    FlutterError(
      code: "invalid_arguments",
      message: "Live Activity state requires courseName and currentPlayerName.",
      details: nil
    )
  }

  private func string(
    _ dictionary: [String: Any],
    _ key: String,
    fallback: String
  ) -> String {
    dictionary[key] as? String ?? fallback
  }

  private func integer(
    _ dictionary: [String: Any],
    _ key: String,
    fallback: Int
  ) -> Int {
    (dictionary[key] as? NSNumber)?.intValue ?? fallback
  }
}
