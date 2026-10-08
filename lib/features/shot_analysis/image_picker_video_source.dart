import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'shot_analysis_ports.dart';

class ImagePickerVideoSource implements VideoSourceGateway {
  ImagePickerVideoSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedVideo?> pickVideo(VideoInputSource source) async {
    try {
      final file = await _picker.pickVideo(
        source: switch (source) {
          VideoInputSource.camera => ImageSource.camera,
          VideoInputSource.gallery => ImageSource.gallery,
        },
      );

      if (file == null) {
        return null;
      }

      return _describeVideo(file, source: source);
    } on PlatformException catch (error) {
      throw _mapPlatformException(error, recovery: false);
    } on ShotAnalysisException {
      rethrow;
    } catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.selectionFailed,
        technicalMessage: error.toString(),
        cause: error,
      );
    }
  }

  @override
  Future<PickedVideo?> recoverLostVideo() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        return null;
      }

      final exception = response.exception;
      if (exception != null) {
        throw _mapPlatformException(exception, recovery: true);
      }

      final files = response.files;
      if (files == null || files.isEmpty) {
        return null;
      }

      return _describeVideo(files.first, recovered: true);
    } on PlatformException catch (error) {
      throw _mapPlatformException(error, recovery: true);
    } on ShotAnalysisException {
      rethrow;
    } catch (error) {
      throw ShotAnalysisException(
        ShotAnalysisErrorCode.recoveryFailed,
        technicalMessage: error.toString(),
        cause: error,
      );
    }
  }

  Future<PickedVideo> _describeVideo(
    XFile file, {
    VideoInputSource? source,
    bool recovered = false,
  }) async {
    final sizeBytes = await file.length();
    if (sizeBytes <= 0) {
      throw const ShotAnalysisException(ShotAnalysisErrorCode.emptyVideo);
    }

    return PickedVideo(
      file: file,
      sizeBytes: sizeBytes,
      source: source,
      recovered: recovered,
    );
  }

  ShotAnalysisException _mapPlatformException(
    PlatformException error, {
    required bool recovery,
  }) {
    final code = error.code.toLowerCase();
    final isPermissionError =
        code.contains('access_denied') ||
        code.contains('permission_denied') ||
        code.contains('access_restricted');
    final isPermanent =
        code.contains('without_prompt') || code.contains('restricted');

    if (isPermissionError) {
      return ShotAnalysisException(
        isPermanent
            ? ShotAnalysisErrorCode.permissionPermanentlyDenied
            : ShotAnalysisErrorCode.permissionDenied,
        technicalMessage: error.message ?? error.code,
        cause: error,
      );
    }

    return ShotAnalysisException(
      recovery
          ? ShotAnalysisErrorCode.recoveryFailed
          : ShotAnalysisErrorCode.selectionFailed,
      technicalMessage: error.message ?? error.code,
      cause: error,
    );
  }
}
