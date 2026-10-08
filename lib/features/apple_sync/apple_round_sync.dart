import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef WatchCommandHandler = void Function(WatchRoundCommand command);

class WatchRoundCommand {
  const WatchRoundCommand({required this.name, this.playerIndex, this.delta});

  final String name;
  final int? playerIndex;
  final int? delta;

  static WatchRoundCommand? fromArguments(Object? arguments) {
    if (arguments is! Map) {
      return null;
    }
    final name = arguments['command'];
    if (name is! String || name.isEmpty) {
      return null;
    }
    return WatchRoundCommand(
      name: name,
      playerIndex: (arguments['playerIndex'] as num?)?.toInt(),
      delta: (arguments['delta'] as num?)?.toInt(),
    );
  }
}

/// Keeps a running golf round in sync with Apple Watch and ActivityKit.
///
/// Calls are serialized so a quick series of score taps cannot let an older
/// platform update arrive after a newer one. Missing Apple plugins are treated
/// as an unavailable feature, which keeps Android, desktop, and widget tests
/// working without platform-specific branches in the scorecard.
class AppleRoundSync {
  AppleRoundSync({required WatchCommandHandler onWatchCommand})
    : _onWatchCommand = onWatchCommand {
    if (_supportsAppleSurfaces) {
      _watchChannel.setMethodCallHandler(_handleWatchCall);
    }
  }

  static const MethodChannel _watchChannel = MethodChannel('blackshell/watch');
  static const MethodChannel _liveActivityChannel = MethodChannel(
    'blackshell/live_activity',
  );

  final WatchCommandHandler _onWatchCommand;
  Future<void> _operation = Future<void>.value();
  String? _roundID;
  bool _liveActivityStarted = false;
  bool _disposed = false;

  static bool get _supportsAppleSurfaces =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> publish(
    Map<String, Object?> state, {
    bool startLiveActivity = false,
  }) {
    if (!_supportsAppleSurfaces) {
      return Future<void>.value();
    }
    final snapshot = Map<String, Object?>.from(state);
    final roundID = _roundIDFrom(snapshot);
    if (roundID != null && roundID != _roundID) {
      _roundID = roundID;
      _liveActivityStarted = false;
    }
    return _enqueue(() async {
      await _invokeSilently(_watchChannel, 'updateRound', snapshot);

      if (startLiveActivity || !_liveActivityStarted) {
        await _startLiveActivity(snapshot);
        return;
      }

      final activityID = await _invokeSilently(
        _liveActivityChannel,
        'update',
        snapshot,
      );
      if (activityID == null) {
        _liveActivityStarted = false;
        await _startLiveActivity(snapshot);
      }
    });
  }

  Future<void> finish(
    Map<String, Object?> finalState, {
    bool immediate = false,
  }) {
    if (!_supportsAppleSurfaces) {
      return Future<void>.value();
    }
    final snapshot = Map<String, Object?>.from(finalState)
      ..['isComplete'] = true
      ..['immediate'] = immediate;
    _roundID = _roundIDFrom(snapshot) ?? _roundID;
    return _enqueue(() async {
      await _invokeSilently(_watchChannel, 'updateRound', snapshot);
      await _invokeSilently(_watchChannel, 'clearRound');
      await _invokeSilently(_liveActivityChannel, 'end', snapshot);
      _liveActivityStarted = false;
    });
  }

  Future<void> cancel() {
    if (!_supportsAppleSurfaces) {
      return Future<void>.value();
    }
    final endArguments = _endArguments(immediate: true);
    return _enqueue(() async {
      await _invokeSilently(_watchChannel, 'clearRound');
      await _invokeSilently(_liveActivityChannel, 'end', endArguments);
      _liveActivityStarted = false;
      _roundID = null;
    });
  }

  void dispose({bool cancelActiveRound = false}) {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_supportsAppleSurfaces) {
      _watchChannel.setMethodCallHandler(null);
    }
    if (_supportsAppleSurfaces && cancelActiveRound) {
      final endArguments = _endArguments(immediate: true);
      _operation = _operation.then((_) async {
        await _invokeSilently(_watchChannel, 'clearRound');
        await _invokeSilently(_liveActivityChannel, 'end', endArguments);
        _liveActivityStarted = false;
        _roundID = null;
      });
    }
  }

  Future<void> _startLiveActivity(Map<String, Object?> snapshot) async {
    final activityID = await _invokeSilently(
      _liveActivityChannel,
      'start',
      snapshot,
    );
    _liveActivityStarted = activityID != null;
  }

  Map<String, Object?> _endArguments({required bool immediate}) {
    return <String, Object?>{
      'immediate': immediate,
      if (_roundID != null) 'roundId': _roundID,
    };
  }

  static String? _roundIDFrom(Map<String, Object?> state) {
    final roundID = state['roundId'];
    return roundID is String && roundID.isNotEmpty ? roundID : null;
  }

  Future<void> _handleWatchCall(MethodCall call) async {
    if (_disposed || call.method != 'watchCommand') {
      return;
    }
    final command = WatchRoundCommand.fromArguments(call.arguments);
    if (command != null) {
      _onWatchCommand(command);
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final completer = Completer<void>();
    _operation = _operation.then((_) async {
      if (_disposed) {
        completer.complete();
        return;
      }
      try {
        await action();
        completer.complete();
      } catch (error, stackTrace) {
        debugPrint('Apple round sync failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        completer.complete();
      }
    });
    return completer.future;
  }

  static Future<Object?> _invokeSilently(
    MethodChannel channel,
    String method, [
    Object? arguments,
  ]) async {
    try {
      return await channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        '$method is unavailable: ${error.code} ${error.message ?? ''}',
      );
      return null;
    }
  }
}
