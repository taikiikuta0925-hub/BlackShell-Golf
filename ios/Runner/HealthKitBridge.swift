import Flutter
import Foundation
import HealthKit

final class HealthKitBridge {
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

    guard let startedAtMillis = number(arguments["startedAtMillis"]),
          let endedAtMillis = number(arguments["endedAtMillis"]),
          let roundID = arguments["roundId"] as? String,
          let courseName = arguments["courseName"] as? String,
          let holeCount = number(arguments["holeCount"])?.intValue else {
      result(invalidArgumentsError())
      return
    }

    let startedAt = Date(timeIntervalSince1970: startedAtMillis.doubleValue / 1_000)
    let endedAt = Date(timeIntervalSince1970: endedAtMillis.doubleValue / 1_000)
    guard endedAt > startedAt else {
      result(invalidArgumentsError())
      return
    }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .golf
    let indoor = arguments["indoor"] as? Bool ?? false
    configuration.locationType = indoor ? .indoor : .outdoor

    let builder = HKWorkoutBuilder(
      healthStore: healthStore,
      configuration: configuration,
      device: nil
    )

    builder.beginCollection(withStart: startedAt) { [weak self] success, error in
      guard let self else { return }
      guard success, error == nil else {
        self.complete(result, error: error, code: "healthkit_workout_start_failed")
        return
      }

      let metadata: [String: Any] = [
        HKMetadataKeyWorkoutBrandName: "BlackShell Golf",
        HKMetadataKeyIndoorWorkout: indoor,
        "com.taikiikuta.blackshellGolf.roundId": roundID,
        "com.taikiikuta.blackshellGolf.courseName": courseName,
        "com.taikiikuta.blackshellGolf.holeCount": holeCount,
      ]

      builder.addMetadata(metadata) { success, error in
        guard success, error == nil else {
          builder.discardWorkout()
          self.complete(result, error: error, code: "healthkit_metadata_failed")
          return
        }

        builder.endCollection(withEnd: endedAt) { success, error in
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
    value as? NSNumber
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
