import 'package:blackshell_golf/features/apple_sync/apple_fitness_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('blackshell/healthkit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('saveGolfWorkout sends the completed round payload', () async {
    MethodCall? capturedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return 'workout-uuid';
    });

    final startedAt = DateTime.utc(2026, 10, 9, 1, 15);
    final endedAt = DateTime.utc(2026, 10, 9, 5, 45);

    final workoutID = await AppleFitnessSync().saveGolfWorkout(
      startedAt: startedAt,
      endedAt: endedAt,
      roundId: 'autosave-1791511200000',
      courseName: 'BlackShell Golf Club',
      holeCount: 18,
      indoor: false,
    );

    expect(workoutID, 'workout-uuid');
    expect(capturedCall?.method, 'saveGolfWorkout');

    final arguments = Map<String, Object?>.from(
      capturedCall!.arguments as Map<Object?, Object?>,
    );
    expect(arguments, {
      'startedAtMillis': startedAt.millisecondsSinceEpoch,
      'endedAtMillis': endedAt.millisecondsSinceEpoch,
      'roundId': 'autosave-1791511200000',
      'courseName': 'BlackShell Golf Club',
      'holeCount': 18,
      'indoor': false,
    });
  });
}
