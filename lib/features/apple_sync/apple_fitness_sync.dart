import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppleFitnessAuthorization {
  unavailable,
  notDetermined,
  denied,
  authorized;

  static AppleFitnessAuthorization fromPlatform(Object? value) {
    return switch (value) {
      'authorized' => AppleFitnessAuthorization.authorized,
      'denied' => AppleFitnessAuthorization.denied,
      'notDetermined' => AppleFitnessAuthorization.notDetermined,
      _ => AppleFitnessAuthorization.unavailable,
    };
  }
}

/// Writes completed golf rounds to HealthKit so they appear in Apple Fitness.
///
/// The app only asks for permission to write workouts. It does not request or
/// read heart rate, calories, location, or any other health data.
class AppleFitnessSync {
  static const MethodChannel _channel = MethodChannel('blackshell/healthkit');

  static bool get _supportsHealthKit =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<AppleFitnessAuthorization> authorizationStatus() async {
    if (!_supportsHealthKit) {
      return AppleFitnessAuthorization.unavailable;
    }

    try {
      final availability = await _channel.invokeMapMethod<String, Object?>(
        'availability',
      );
      if (availability?['supported'] != true) {
        return AppleFitnessAuthorization.unavailable;
      }
      return AppleFitnessAuthorization.fromPlatform(
        availability?['authorization'],
      );
    } on MissingPluginException {
      return AppleFitnessAuthorization.unavailable;
    }
  }

  Future<AppleFitnessAuthorization> requestAuthorization() async {
    if (!_supportsHealthKit) {
      return AppleFitnessAuthorization.unavailable;
    }

    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'requestAuthorization',
      );
      if (response?['supported'] != true) {
        return AppleFitnessAuthorization.unavailable;
      }
      return AppleFitnessAuthorization.fromPlatform(response?['authorization']);
    } on MissingPluginException {
      return AppleFitnessAuthorization.unavailable;
    }
  }

  Future<String?> saveGolfWorkout({
    required DateTime startedAt,
    required DateTime endedAt,
    required String roundId,
    required String courseName,
    required int holeCount,
    required bool indoor,
  }) async {
    if (!_supportsHealthKit) {
      return null;
    }

    final workoutId = await _channel.invokeMethod<String>('saveGolfWorkout', {
      'startedAtMillis': startedAt.millisecondsSinceEpoch,
      'endedAtMillis': endedAt.millisecondsSinceEpoch,
      'roundId': roundId,
      'courseName': courseName,
      'holeCount': holeCount,
      'indoor': indoor,
    });
    return workoutId;
  }
}
