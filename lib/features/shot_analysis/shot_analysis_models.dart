import 'package:image_picker/image_picker.dart';

enum AnalysisStage { validating, uploading, processing, analyzing, cleaningUp }

typedef AnalysisStageChanged = void Function(AnalysisStage stage);

enum VideoInputSource { camera, gallery }

class PickedVideo {
  const PickedVideo({
    required this.file,
    required this.sizeBytes,
    this.source,
    this.recovered = false,
  });

  final XFile file;
  final int sizeBytes;
  final VideoInputSource? source;
  final bool recovered;

  String get fileName {
    final name = file.name.trim();
    return name.isEmpty ? 'video' : name;
  }
}

class ShotAnalysisContext {
  const ShotAnalysisContext({
    required this.languageCode,
    required this.club,
    required this.cameraAngle,
    required this.notes,
  });

  final String languageCode;
  final String club;
  final String cameraAngle;
  final String notes;

  Map<String, String> toJson() {
    return {
      'languageCode': languageCode,
      'club': club,
      'cameraAngle': cameraAngle,
      'notes': notes,
    };
  }
}

class SwingPhaseObservation {
  const SwingPhaseObservation({
    required this.phase,
    required this.observation,
    this.timestamp,
  });

  final String phase;
  final String observation;
  final String? timestamp;

  factory SwingPhaseObservation.fromJson(Map<String, dynamic> json) {
    return SwingPhaseObservation(
      phase: _firstNonEmptyString([
        json['phase'],
        json['name'],
        json['swingPhase'],
        json['swing_phase'],
      ]),
      observation: _firstNonEmptyString([
        json['observation'],
        json['finding'],
        json['feedback'],
        json['description'],
      ]),
      timestamp: _nullableString(
        json['timestamp'] ?? json['timecode'] ?? json['time_code'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase,
      'observation': observation,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }
}

class GolfSwingAnalysisResult {
  const GolfSwingAnalysisResult({
    required this.summary,
    this.strengths = const [],
    this.improvements = const [],
    this.recommendations = const [],
    this.observations = const [],
    this.safetyNotes = const [],
    this.rawResponse,
  });

  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> recommendations;
  final List<SwingPhaseObservation> observations;
  final List<String> safetyNotes;
  final String? rawResponse;

  bool get hasStructuredFeedback {
    return strengths.isNotEmpty ||
        improvements.isNotEmpty ||
        recommendations.isNotEmpty ||
        observations.isNotEmpty ||
        safetyNotes.isNotEmpty;
  }

  factory GolfSwingAnalysisResult.fromJson(
    Map<String, dynamic> json, {
    String? rawResponse,
  }) {
    final observationsValue =
        json['observations'] ??
        json['phaseObservations'] ??
        json['phase_observations'];

    return GolfSwingAnalysisResult(
      summary: _firstNonEmptyString([
        json['summary'],
        json['overallSummary'],
        json['overall_summary'],
        rawResponse,
      ]),
      strengths: _stringList(json['strengths'] ?? json['positives']),
      improvements: _stringList(
        json['improvements'] ??
            json['areasForImprovement'] ??
            json['areas_for_improvement'],
      ),
      recommendations: _stringList(
        json['recommendations'] ??
            json['practiceTips'] ??
            json['practice_tips'] ??
            json['drills'] ??
            json['practice_drills'],
      ),
      observations: _observationList(observationsValue),
      safetyNotes: _stringList(
        json['safetyNotes'] ?? json['safety_notes'] ?? json['safety'],
      ),
      rawResponse: rawResponse,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'strengths': strengths,
      'improvements': improvements,
      'recommendations': recommendations,
      'observations': observations.map((item) => item.toJson()).toList(),
      'safetyNotes': safetyNotes,
      if (rawResponse != null) 'rawResponse': rawResponse,
    };
  }
}

enum ShotAnalysisErrorCode {
  notConfigured,
  permissionDenied,
  permissionPermanentlyDenied,
  selectionFailed,
  recoveryFailed,
  emptyVideo,
  unsupportedVideo,
  videoTooLarge,
  networkUnavailable,
  timeout,
  unauthorized,
  rateLimited,
  uploadFailed,
  processingFailed,
  contentRejected,
  invalidResponse,
  serviceUnavailable,
  cancelled,
  unknown,
}

class ShotAnalysisException implements Exception {
  const ShotAnalysisException(
    this.code, {
    this.technicalMessage,
    this.cause,
    bool? retryable,
  }) : _retryable = retryable;

  final ShotAnalysisErrorCode code;
  final String? technicalMessage;
  final Object? cause;
  final bool? _retryable;

  bool get retryable {
    return _retryable ??
        switch (code) {
          ShotAnalysisErrorCode.networkUnavailable ||
          ShotAnalysisErrorCode.timeout ||
          ShotAnalysisErrorCode.rateLimited ||
          ShotAnalysisErrorCode.uploadFailed ||
          ShotAnalysisErrorCode.processingFailed ||
          ShotAnalysisErrorCode.serviceUnavailable ||
          ShotAnalysisErrorCode.unknown => true,
          _ => false,
        };
  }

  factory ShotAnalysisException.unknown(Object error) {
    return ShotAnalysisException(
      ShotAnalysisErrorCode.unknown,
      technicalMessage: error.toString(),
      cause: error,
    );
  }

  @override
  String toString() {
    final details = technicalMessage;
    return details == null || details.isEmpty
        ? 'ShotAnalysisException($code)'
        : 'ShotAnalysisException($code, $details)';
  }
}

String _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final text = _nullableString(value);
    if (text != null) {
      return text;
    }
  }
  return '';
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map(_nullableString)
        .whereType<String>()
        .toList(growable: false);
  }
  final singleValue = _nullableString(value);
  return singleValue == null ? const [] : [singleValue];
}

List<SwingPhaseObservation> _observationList(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          return SwingPhaseObservation.fromJson(item);
        }
        if (item is Map) {
          return SwingPhaseObservation.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
        final text = _nullableString(item);
        return text == null
            ? null
            : SwingPhaseObservation(phase: '', observation: text);
      })
      .whereType<SwingPhaseObservation>()
      .where((item) => item.phase.isNotEmpty || item.observation.isNotEmpty)
      .toList(growable: false);
}
