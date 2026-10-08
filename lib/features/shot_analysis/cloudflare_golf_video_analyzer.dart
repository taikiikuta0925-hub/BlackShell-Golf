import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'shot_analysis_ports.dart';

/// Sends a golf swing clip to the configured BlackShell Cloudflare Worker.
///
/// Configuration is resolved in this order:
///
/// 1. [endpoint], or `BLACKSHELL_AI_ENDPOINT` at compile time.
/// 2. [baseUrl], or `AI_API_BASE_URL` at compile time, with
///    `/analyze-swing` appended.
///
/// An optional bearer token can be supplied with [bearerToken] or the
/// `BLACKSHELL_AI_TOKEN` compile-time value. The Gemini API key belongs only
/// in the Worker secret store.
class CloudflareGolfVideoAnalyzer implements GolfVideoAnalyzer {
  CloudflareGolfVideoAnalyzer({
    String? endpoint,
    String? baseUrl,
    String? bearerToken,
    HttpClient? httpClient,
    this.requestTimeout = const Duration(minutes: 2),
    this.maxVideoBytes = defaultMaxVideoBytes,
  }) : assert(maxVideoBytes > 0),
       _endpoint = _resolveEndpoint(endpoint: endpoint, baseUrl: baseUrl),
       _bearerToken = (bearerToken ?? _environmentToken).trim(),
       _httpClient = httpClient ?? HttpClient(),
       _ownsHttpClient = httpClient == null;

  static const int defaultMaxVideoBytes = 14 * 1024 * 1024;
  static const String defaultBaseUrl =
      'https://blackshell-golf-ai.tx-appe-chi.workers.dev';
  static const int _maxResponseBytes = 1024 * 1024;
  static const String _environmentEndpoint = String.fromEnvironment(
    'BLACKSHELL_AI_ENDPOINT',
  );
  static const String _environmentBaseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );
  static const String _environmentToken = String.fromEnvironment(
    'BLACKSHELL_AI_TOKEN',
  );

  static const Set<String> _supportedMimeTypes = {
    'video/x-flv',
    'video/quicktime',
    'video/mpeg',
    'video/mpegps',
    'video/mpg',
    'video/mp4',
    'video/webm',
    'video/wmv',
    'video/3gpp',
    'video/avi',
  };

  static const Map<String, String> _mimeAliases = {
    'video/x-ms-wmv': 'video/wmv',
    'video/x-msvideo': 'video/avi',
    'video/x-m4v': 'video/mp4',
    'video/3gp': 'video/3gpp',
  };

  static const Map<String, String> _mimeTypesByExtension = {
    'flv': 'video/x-flv',
    'mov': 'video/quicktime',
    'mpeg': 'video/mpeg',
    'mpegps': 'video/mpegps',
    'mpg': 'video/mpg',
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'webm': 'video/webm',
    'wmv': 'video/wmv',
    '3gp': 'video/3gpp',
    '3gpp': 'video/3gpp',
    'avi': 'video/avi',
  };

  final Uri? _endpoint;
  final String _bearerToken;
  final HttpClient _httpClient;
  final bool _ownsHttpClient;
  final Set<HttpClientRequest> _activeRequests = {};

  final Duration requestTimeout;
  final int maxVideoBytes;

  bool _closed = false;

  Uri? get endpoint => _endpoint;

  @override
  bool get isConfigured => !_closed && _endpoint != null;

  static bool get hasEnvironmentEndpoint =>
      _resolveEndpoint(endpoint: null, baseUrl: null) != null;

  @override
  Future<GolfSwingAnalysisResult> analyze({
    required XFile video,
    required ShotAnalysisContext context,
    AnalysisStageChanged? onStage,
  }) async {
    try {
      _ensureOpenAndConfigured();
      onStage?.call(AnalysisStage.validating);

      final sizeBytes = await _videoLength(video);
      if (sizeBytes <= 0) {
        throw const ShotAnalysisException(ShotAnalysisErrorCode.emptyVideo);
      }
      if (sizeBytes > maxVideoBytes) {
        throw ShotAnalysisException(
          ShotAnalysisErrorCode.videoTooLarge,
          technicalMessage:
              'Video is $sizeBytes bytes; the limit is $maxVideoBytes bytes.',
        );
      }

      final mimeType = _resolveMimeType(video);
      if (mimeType == null) {
        throw ShotAnalysisException(
          ShotAnalysisErrorCode.unsupportedVideo,
          technicalMessage:
              'Unsupported video type: ${video.mimeType ?? video.name}',
        );
      }

      onStage?.call(AnalysisStage.uploading);
      final response = await _sendMultipart(
        endpoint: _endpoint!,
        video: video,
        videoSize: sizeBytes,
        mimeType: mimeType,
        context: context,
        onUploadComplete: () => onStage?.call(AnalysisStage.processing),
      );

      if (_closed) {
        throw const ShotAnalysisException(ShotAnalysisErrorCode.cancelled);
      }

      onStage?.call(AnalysisStage.analyzing);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _mapHttpFailure(response);
      }
      return _parseAnalysis(response.body);
    } on ShotAnalysisException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.timeout,
        technicalMessage: 'The analysis request timed out.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.networkUnavailable,
        technicalMessage: 'Unable to reach the analysis service.',
        cause: error,
      );
    } on HandshakeException catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.networkUnavailable,
        technicalMessage: 'A secure connection could not be established.',
        cause: error,
      );
    } on FileSystemException catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.uploadFailed,
        technicalMessage: 'The selected video could not be read.',
        cause: error,
      );
    } on HttpException catch (error) {
      throw ShotAnalysisException(
        _closed
            ? ShotAnalysisErrorCode.cancelled
            : ShotAnalysisErrorCode.networkUnavailable,
        technicalMessage: _closed
            ? 'The analysis request was cancelled.'
            : 'The analysis connection ended unexpectedly.',
        cause: error,
      );
    } catch (error) {
      if (_closed) {
        throw ShotAnalysisException(
          ShotAnalysisErrorCode.cancelled,
          technicalMessage: 'The analysis request was cancelled.',
          cause: error,
        );
      }
      throw ShotAnalysisException.unknown(error);
    } finally {
      try {
        onStage?.call(AnalysisStage.cleaningUp);
      } catch (_) {
        // Progress reporting must not replace the analysis result or error.
      }
    }
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    for (final request in _activeRequests.toList(growable: false)) {
      request.abort();
    }
    _activeRequests.clear();
    if (_ownsHttpClient) {
      _httpClient.close(force: true);
    }
  }

  void _ensureOpenAndConfigured() {
    if (_closed) {
      throw const ShotAnalysisException(ShotAnalysisErrorCode.cancelled);
    }
    if (_endpoint == null) {
      throw const ShotAnalysisException(
        ShotAnalysisErrorCode.notConfigured,
        technicalMessage:
            'Set AI_API_BASE_URL or BLACKSHELL_AI_ENDPOINT with --dart-define.',
      );
    }
  }

  Future<int> _videoLength(XFile video) async {
    try {
      return await video.length().timeout(requestTimeout);
    } on TimeoutException {
      rethrow;
    } on FileSystemException {
      rethrow;
    } catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.uploadFailed,
        technicalMessage: 'The selected video size could not be read.',
        cause: error,
      );
    }
  }

  Future<_WorkerResponse> _sendMultipart({
    required Uri endpoint,
    required XFile video,
    required int videoSize,
    required String mimeType,
    required ShotAnalysisContext context,
    required void Function() onUploadComplete,
  }) async {
    HttpClientRequest? request;
    try {
      request = await _httpClient
          .openUrl('POST', endpoint)
          .timeout(requestTimeout);
      _activeRequests.add(request);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-BlackShell-Client', 'flutter');
      if (_bearerToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_bearerToken',
        );
      }

      final boundary = _newBoundary();
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );

      final contextJson = jsonEncode(context.toJson());
      final safeFileName = _safeFileName(video.name, mimeType);
      final prefix = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="context"\r\n'
        'Content-Type: application/json; charset=utf-8\r\n\r\n'
        '$contextJson\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="video"; '
        'filename="$safeFileName"\r\n'
        'Content-Type: $mimeType\r\n\r\n',
      );
      final suffix = utf8.encode('\r\n--$boundary--\r\n');
      request.contentLength = prefix.length + videoSize + suffix.length;

      request.add(prefix);
      await request
          .addStream(_validatedVideoStream(video, expectedSize: videoSize))
          .timeout(requestTimeout);
      request.add(suffix);
      await request.flush().timeout(requestTimeout);
      onUploadComplete();

      final httpResponse = await request.close().timeout(requestTimeout);
      final body = await _readResponseBody(
        httpResponse,
      ).timeout(requestTimeout);
      return _WorkerResponse(statusCode: httpResponse.statusCode, body: body);
    } on TimeoutException {
      request?.abort();
      rethrow;
    } catch (_) {
      request?.abort();
      rethrow;
    } finally {
      if (request != null) {
        _activeRequests.remove(request);
      }
    }
  }

  Stream<List<int>> _validatedVideoStream(
    XFile video, {
    required int expectedSize,
  }) async* {
    var bytesRead = 0;
    await for (final chunk in video.openRead()) {
      bytesRead += chunk.length;
      if (bytesRead > maxVideoBytes) {
        throw const ShotAnalysisException(ShotAnalysisErrorCode.videoTooLarge);
      }
      yield chunk;
    }
    if (bytesRead <= 0) {
      throw const ShotAnalysisException(ShotAnalysisErrorCode.emptyVideo);
    }
    if (bytesRead != expectedSize) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.uploadFailed,
        technicalMessage:
            'The video changed while it was being uploaded '
            '($expectedSize bytes expected, $bytesRead bytes read).',
      );
    }
  }

  Future<String> _readResponseBody(HttpClientResponse response) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > _maxResponseBytes) {
        throw const ShotAnalysisException(
          ShotAnalysisErrorCode.invalidResponse,
          technicalMessage: 'The analysis response was too large.',
        );
      }
      bytes.add(chunk);
    }
    try {
      return utf8.decode(bytes.takeBytes());
    } on FormatException catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.invalidResponse,
        technicalMessage: 'The analysis response was not valid UTF-8.',
        cause: error,
      );
    }
  }

  GolfSwingAnalysisResult _parseAnalysis(String rawResponse) {
    try {
      Object? value = _decodeJson(rawResponse);
      Map<String, dynamic>? analysis;

      for (var depth = 0; depth < 4; depth += 1) {
        final object = _stringKeyedMap(value);
        if (object == null) {
          break;
        }
        if (_looksLikeAnalysis(object)) {
          analysis = object;
          break;
        }

        Object? wrapped;
        if (object.containsKey('result')) {
          wrapped = object['result'];
        } else if (object.containsKey('analysis')) {
          wrapped = object['analysis'];
        } else {
          break;
        }
        value = wrapped is String ? _decodeJson(wrapped) : wrapped;
      }

      if (analysis == null) {
        throw const FormatException('Missing analysis object.');
      }

      final parsed = GolfSwingAnalysisResult.fromJson(analysis);
      if (parsed.summary.trim().isEmpty && !parsed.hasStructuredFeedback) {
        throw const FormatException('The analysis object was empty.');
      }
      return GolfSwingAnalysisResult(
        summary: parsed.summary,
        strengths: parsed.strengths,
        improvements: parsed.improvements,
        recommendations: parsed.recommendations,
        observations: parsed.observations,
        safetyNotes: parsed.safetyNotes,
        rawResponse: rawResponse,
      );
    } on ShotAnalysisException {
      rethrow;
    } catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.invalidResponse,
        technicalMessage: 'The Worker returned an invalid analysis response.',
        cause: error,
      );
    }
  }

  ShotAnalysisException _mapHttpFailure(_WorkerResponse response) {
    final error = _decodeServerError(response.body);
    final code = error.code;
    final message = error.message == null
        ? 'Analysis service returned HTTP ${response.statusCode}.'
        : 'HTTP ${response.statusCode}: ${error.message}';

    final mappedCode = switch (code) {
      'not_configured' ||
      'invalid_endpoint' ||
      'missing_api_key' => ShotAnalysisErrorCode.notConfigured,
      'unauthorized' || 'forbidden' => ShotAnalysisErrorCode.unauthorized,
      'video_too_large' => ShotAnalysisErrorCode.videoTooLarge,
      'unsupported_video' => ShotAnalysisErrorCode.unsupportedVideo,
      'content_rejected' => ShotAnalysisErrorCode.contentRejected,
      'invalid_response' ||
      'invalid_request' => ShotAnalysisErrorCode.invalidResponse,
      'rate_limited' => ShotAnalysisErrorCode.rateLimited,
      'service_unavailable' => ShotAnalysisErrorCode.serviceUnavailable,
      'upload_failed' => ShotAnalysisErrorCode.uploadFailed,
      'processing_failed' => ShotAnalysisErrorCode.processingFailed,
      _ => switch (response.statusCode) {
        401 || 403 => ShotAnalysisErrorCode.unauthorized,
        404 => ShotAnalysisErrorCode.notConfigured,
        408 => ShotAnalysisErrorCode.timeout,
        413 => ShotAnalysisErrorCode.videoTooLarge,
        415 => ShotAnalysisErrorCode.unsupportedVideo,
        422 => ShotAnalysisErrorCode.contentRejected,
        429 => ShotAnalysisErrorCode.rateLimited,
        >= 500 => ShotAnalysisErrorCode.serviceUnavailable,
        _ => ShotAnalysisErrorCode.processingFailed,
      },
    };

    return ShotAnalysisException(
      mappedCode,
      technicalMessage: message,
      retryable: error.retryable,
    );
  }

  static Uri? _resolveEndpoint({String? endpoint, String? baseUrl}) {
    final directValue = endpoint ?? _environmentEndpoint;
    if (directValue.trim().isNotEmpty) {
      return _validatedHttpUri(directValue);
    }

    final baseValue = baseUrl ?? _environmentBaseUrl;
    final base = _validatedHttpUri(baseValue);
    if (base == null) {
      return null;
    }
    final segments = base.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty || segments.last != 'analyze-swing') {
      segments.add('analyze-swing');
    }
    return base.replace(pathSegments: segments);
  }

  static Uri? _validatedHttpUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    if (uri.scheme == 'https') {
      return uri;
    }
    final host = uri.host.toLowerCase();
    final loopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (uri.scheme != 'http' || !loopback) {
      return null;
    }
    return uri;
  }

  static String? _resolveMimeType(XFile video) {
    final supplied = video.mimeType?.split(';').first.trim().toLowerCase();
    if (supplied != null && supplied.isNotEmpty) {
      final normalized = _mimeAliases[supplied] ?? supplied;
      if (_supportedMimeTypes.contains(normalized)) {
        return normalized;
      }
      if (supplied != 'application/octet-stream') {
        return null;
      }
    }

    final name = video.name.isEmpty ? video.path : video.name;
    final separator = name.lastIndexOf('.');
    if (separator < 0 || separator == name.length - 1) {
      return null;
    }
    return _mimeTypesByExtension[name.substring(separator + 1).toLowerCase()];
  }

  static String _safeFileName(String originalName, String mimeType) {
    var result = originalName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (result.isEmpty || result == '.' || result == '..') {
      result = 'swing.${_extensionForMimeType(mimeType)}';
    }
    if (result.length > 120) {
      result = result.substring(result.length - 120);
    }
    return result;
  }

  static String _extensionForMimeType(String mimeType) {
    return switch (mimeType) {
      'video/quicktime' => 'mov',
      'video/webm' => 'webm',
      'video/wmv' => 'wmv',
      'video/3gpp' => '3gp',
      'video/avi' => 'avi',
      'video/x-flv' => 'flv',
      'video/mpeg' || 'video/mpegps' || 'video/mpg' => 'mpeg',
      _ => 'mp4',
    };
  }

  static String _newBoundary() {
    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '----BlackShellGolf$suffix';
  }

  static Object? _decodeJson(String source) {
    var value = source.trim();
    if (value.startsWith('```')) {
      final firstLineEnd = value.indexOf('\n');
      if (firstLineEnd >= 0) {
        value = value.substring(firstLineEnd + 1);
      }
      if (value.endsWith('```')) {
        value = value.substring(0, value.length - 3).trimRight();
      }
    }
    return jsonDecode(value);
  }

  static Map<String, dynamic>? _stringKeyedMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static bool _looksLikeAnalysis(Map<String, dynamic> value) {
    const keys = {
      'summary',
      'overallSummary',
      'overall_summary',
      'strengths',
      'positives',
      'improvements',
      'areasForImprovement',
      'areas_for_improvement',
      'recommendations',
      'practiceTips',
      'practice_tips',
      'drills',
      'practice_drills',
      'observations',
      'phaseObservations',
      'phase_observations',
      'safetyNotes',
      'safety_notes',
    };
    return value.keys.any(keys.contains);
  }

  static _ServerError _decodeServerError(String body) {
    try {
      final decoded = _stringKeyedMap(_decodeJson(body));
      if (decoded == null) {
        return const _ServerError();
      }
      final rawMessage = decoded['error'] is Map
          ? (decoded['error'] as Map)['message']
          : decoded['error'] ?? decoded['message'];
      final message = rawMessage?.toString().trim();
      final rawCode =
          decoded['code'] ??
          (decoded['error'] is Map ? (decoded['error'] as Map)['code'] : null);
      return _ServerError(
        code: rawCode?.toString().trim().toLowerCase(),
        message: message == null || message.isEmpty
            ? null
            : message.substring(0, min(message.length, 300)),
        retryable: decoded['retryable'] is bool
            ? decoded['retryable'] as bool
            : null,
      );
    } catch (_) {
      return const _ServerError();
    }
  }
}

class _WorkerResponse {
  const _WorkerResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class _ServerError {
  const _ServerError({this.code, this.message, this.retryable});

  final String? code;
  final String? message;
  final bool? retryable;
}
