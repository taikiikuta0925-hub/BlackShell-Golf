import Flutter
import Foundation
import HealthKit

final class HealthKitBridge {
  private enum MetadataKey {
    static let namespace = "com.taikiikuta.blackshellGolf"
    static let roundID = "\(namespace).roundId"
    static let courseName = "\(namespace).courseName"
    static let holeCount = "\(namespace).holeCount"
    static let schemaVersion = "\(namespace).schemaVersion"
    static let roundSummary = "\(namespace).roundSummary"
  }

  private struct GolfWorkoutInput {
    let startedAt: Date
    let endedAt: Date
    let roundID: String
    let courseName: String
    let holeCount: Int
    let indoor: Bool

    var metadata: [String: Any] {
      [
        HKMetadataKeyWorkoutBrandName: "BS Golf · \(holeCount)H",
        HKMetadataKeyIndoorWorkout: indoor,
        HKMetadataKeyExternalUUID: roundID,
        HKMetadataKeySyncIdentifier: "\(MetadataKey.namespace).round.\(roundID)",
        HKMetadataKeySyncVersion: 1,
        HKMetadataKeyTimeZone: TimeZone.current.identifier,
        MetadataKey.roundID: roundID,
        MetadataKey.courseName: courseName,
        MetadataKey.holeCount: holeCount,
        MetadataKey.schemaVersion: 1,
        MetadataKey.roundSummary: "\(courseName) · \(holeCount)H",
      ]
    }
  }

  private let channel: FlutterMethodChannel
  private let healthStore = HKHealthStore()
  private let workoutType = HKObjectType.workoutType()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "blackshell/healthkit",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(availability())

    case "requestAuthorization":
      requestAuthorization(result: result)

    case "saveGolfWorkout":
      guard let arguments = call.arguments as? [String: Any] else {
        result(invalidArgumentsError())
        return
      }
      saveGolfWorkout(arguments: arguments, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func availability() -> [String: Any] {
    guard HKHealthStore.isHealthDataAvailable() else {
      return [
        "supported": false,
        "authorization": "unavailable",
      ]
    }

    return [
      "supported": true,
      "authorization": authorizationName(
        healthStore.authorizationStatus(for: workoutType)
      ),
    ]
  }

  private func requestAuthorization(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(availability())
      return
    }

    let typesToShare: Set<HKSampleType> = [workoutType]
    healthStore.requestAuthorization(toShare: typesToShare, read: []) {
      [weak self] _, error in
      guard let self else { return }
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "healthkit_authorization_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(self.availability())
      }
    }
  }

  private func saveGolfWorkout(
    arguments: [String: Any],
    result: @escaping FlutterResult
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(
        FlutterError(
          code: "healthkit_unavailable",
          message: "HealthKit is not available on this device.",
          details: nil
        )
      )
      return
    }

    guard healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized else {
      result(
        FlutterError(
          code: "healthkit_permission_denied",
          message: "Permission to save workouts was not granted.",
          details: nil
        )
      )
      return
    }

    guard let workout = validatedInput(from: arguments) else {
      result(invalidArgumentsError())
      return
    }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .golf
    configuration.locationType = workout.indoor ? .indoor : .outdoor

    let builder = HKWorkoutBuilder(
      healthStore: healthStore,
      configuration: configuration,
      device: nil
    )

    builder.beginCollection(withStart: workout.startedAt) { [weak self] success, error in
      guard let self else { return }
      guard success, error == nil else {
        self.complete(result, error: error, code: "healthkit_workout_start_failed")
        return
      }

      builder.addMetadata(workout.metadata) { success, error in
        guard success, error == nil else {
          builder.discardWorkout()
          self.complete(result, error: error, code: "healthkit_metadata_failed")
          return
        }

        builder.endCollection(withEnd: workout.endedAt) { success, error in
          guard success, error == nil else {
            builder.discardWorkout()
            self.complete(result, error: error, code: "healthkit_workout_end_failed")
            return
          }

          builder.finishWorkout { workout, error in
            guard let workout, error == nil else {
              self.complete(result, error: error, code: "healthkit_workout_save_failed")
              return
            }
            DispatchQueue.main.async {
              result(workout.uuid.uuidString)
            }
          }
        }
      }
    }
  }

  private func authorizationName(_ status: HKAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .sharingDenied:
      return "denied"
    case .sharingAuthorized:
      return "authorized"
    @unknown default:
      return "unavailable"
    }
  }

  private func number(_ value: Any?) -> NSNumber? {
    guard let number = value as? NSNumber,
          CFGetTypeID(number) != CFBooleanGetTypeID() else {
      return nil
    }
    return number
  }

  private func validatedInput(from arguments: [String: Any]) -> GolfWorkoutInput? {
    guard let startedAtMillis = finiteDouble(arguments["startedAtMillis"]),
          let endedAtMillis = finiteDouble(arguments["endedAtMillis"]),
          startedAtMillis >= 0,
          endedAtMillis > startedAtMillis,
          let roundIDValue = arguments["roundId"] as? String,
          let roundID = sanitizedRoundID(roundIDValue),
          let courseNameValue = arguments["courseName"] as? String,
          let courseName = sanitizedMetadataString(courseNameValue, maxLength: 120),
          !courseName.isEmpty,
          let holeCount = integer(arguments["holeCount"]),
          (1...36).contains(holeCount),
          let indoor = arguments["indoor"] as? Bool else {
      return nil
    }

    let startedAt = Date(timeIntervalSince1970: startedAtMillis / 1_000)
    let endedAt = Date(timeIntervalSince1970: endedAtMillis / 1_000)
    let maximumRoundDuration: TimeInterval = 36 * 60 * 60
    let maximumClockSkew: TimeInterval = 10 * 60
    guard endedAt.timeIntervalSince(startedAt) <= maximumRoundDuration,
          endedAt <= Date().addingTimeInterval(maximumClockSkew) else {
      return nil
    }

    return GolfWorkoutInput(
      startedAt: startedAt,
      endedAt: endedAt,
      roundID: roundID,
      courseName: courseName,
      holeCount: holeCount,
      indoor: indoor
    )
  }

  private func finiteDouble(_ value: Any?) -> Double? {
    guard let number = number(value) else { return nil }
    let value = number.doubleValue
    return value.isFinite ? value : nil
  }

  private func integer(_ value: Any?) -> Int? {
    guard let value = finiteDouble(value),
          value.rounded(.towardZero) == value,
          value >= Double(Int.min),
          value <= Double(Int.max) else {
      return nil
    }
    return Int(value)
  }

  private func sanitizedRoundID(_ value: String) -> String? {
    guard let sanitized = sanitizedMetadataString(value, maxLength: 128),
          !sanitized.isEmpty else {
      return nil
    }

    let allowedCharacters = CharacterSet.alphanumerics.union(
      CharacterSet(charactersIn: "-._:")
    )
    guard sanitized.unicodeScalars.allSatisfy(allowedCharacters.contains) else {
      return nil
    }
    return sanitized
  }

  private func sanitizedMetadataString(
    _ value: String,
    maxLength: Int
  ) -> String? {
    let withoutControls = value.filter { character in
      character.unicodeScalars.allSatisfy {
        !CharacterSet.controlCharacters.contains($0)
      }
    }
    let collapsedWhitespace = withoutControls
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
    guard !collapsedWhitespace.isEmpty else { return nil }
    return String(collapsedWhitespace.prefix(maxLength))
  }

  private func invalidArgumentsError() -> FlutterError {
    FlutterError(
      code: "invalid_arguments",
      message: "A golf workout requires valid start/end times and round details.",
      details: nil
    )
  }

  private func complete(
    _ result: @escaping FlutterResult,
    error: Error?,
    code: String
  ) {
    DispatchQueue.main.async {
      result(
        FlutterError(
          code: code,
          message: error?.localizedDescription ?? "The workout could not be saved.",
          details: nil
        )
      )
    }
  }
}
