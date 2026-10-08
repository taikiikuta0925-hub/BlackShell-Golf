import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blackshell_golf/features/shot_analysis/cloudflare_golf_video_analyzer.dart';
import 'package:blackshell_golf/features/shot_analysis/shot_analysis_ports.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('accepts HTTPS endpoints and limits HTTP to local development', () {
    final defaults = CloudflareGolfVideoAnalyzer();
    final production = CloudflareGolfVideoAnalyzer(
      baseUrl: 'https://blackshell-golf-ai.example.workers.dev',
    );
    final insecure = CloudflareGolfVideoAnalyzer(
      endpoint: 'http://api.example.com/analyze-swing',
    );
    final local = CloudflareGolfVideoAnalyzer(
      endpoint: 'http://127.0.0.1:8787/analyze-swing',
    );
    addTearDown(defaults.close);
    addTearDown(production.close);
    addTearDown(insecure.close);
    addTearDown(local.close);

    expect(defaults.isConfigured, isTrue);
    expect(
      defaults.endpoint,
      Uri.parse(
        'https://blackshell-golf-ai.tx-appe-chi.workers.dev/analyze-swing',
      ),
    );
    expect(production.isConfigured, isTrue);
    expect(
      production.endpoint,
      Uri.parse('https://blackshell-golf-ai.example.workers.dev/analyze-swing'),
    );
    expect(insecure.isConfigured, isFalse);
    expect(local.isConfigured, isTrue);
  });

  test('uploads multipart video and parses a wrapped analysis', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final requestChecked = Completer<void>();
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/analyze-swing');
      expect(request.headers.contentType?.mimeType, 'multipart/form-data');
      final body = await request.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      final text = latin1.decode(body);
      expect(text, contains('name="context"'));
      expect(text, contains('"club":"7 iron"'));
      expect(text, contains('name="video"; filename="swing.mp4"'));
      expect(text, contains('short-video'));
      requestChecked.complete();

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'analysis': {
            'summary': 'Stable setup and balanced finish.',
            'strengths': ['Good posture'],
            'improvements': ['Smoother transition'],
            'recommendations': ['Pause drill'],
            'observations': [
              {
                'phase': 'Top',
                'observation': 'Good width.',
                'timestamp': '00:02',
              },
            ],
            'safetyNotes': <String>[],
          },
        }),
      );
      await request.response.close();
    });

    final directory = await Directory.systemTemp.createTemp('blackshell_ai_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/swing.mp4');
    await file.writeAsString('short-video');

    final analyzer = CloudflareGolfVideoAnalyzer(
      endpoint: 'http://127.0.0.1:${server.port}/analyze-swing',
    );
    addTearDown(analyzer.close);
    final stages = <AnalysisStage>[];
    final result = await analyzer.analyze(
      video: XFile(file.path, mimeType: 'video/mp4', name: 'swing.mp4'),
      context: const ShotAnalysisContext(
        languageCode: 'en',
        club: '7 iron',
        cameraAngle: 'down the line',
        notes: '',
      ),
      onStage: stages.add,
    );

    await requestChecked.future;
    expect(result.summary, 'Stable setup and balanced finish.');
    expect(result.observations.single.timestamp, '00:02');
    expect(stages, containsAllInOrder(AnalysisStage.values));
  });

  test('rejects an oversized video before opening a request', () async {
    final directory = await Directory.systemTemp.createTemp('blackshell_ai_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/large.mp4');
    await file.writeAsBytes([1, 2, 3, 4]);

    final analyzer = CloudflareGolfVideoAnalyzer(
      endpoint: 'https://example.invalid/analyze-swing',
      maxVideoBytes: 3,
    );
    addTearDown(analyzer.close);

    expect(
      () => analyzer.analyze(
        video: XFile(file.path, mimeType: 'video/mp4'),
        context: const ShotAnalysisContext(
          languageCode: 'ja',
          club: '',
          cameraAngle: 'not specified',
          notes: '',
        ),
      ),
      throwsA(
        isA<ShotAnalysisException>().having(
          (error) => error.code,
          'code',
          ShotAnalysisErrorCode.videoTooLarge,
        ),
      ),
    );
  });
}
