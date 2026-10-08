import 'package:image_picker/image_picker.dart';

import 'shot_analysis_models.dart';

export 'shot_analysis_models.dart'
    show
        AnalysisStage,
        AnalysisStageChanged,
        GolfSwingAnalysisResult,
        PickedVideo,
        ShotAnalysisContext,
        ShotAnalysisErrorCode,
        ShotAnalysisException,
        SwingPhaseObservation,
        VideoInputSource;

abstract interface class VideoSourceGateway {
  Future<PickedVideo?> pickVideo(VideoInputSource source);

  Future<PickedVideo?> recoverLostVideo();
}

abstract interface class GolfVideoAnalyzer {
  bool get isConfigured;

  Future<GolfSwingAnalysisResult> analyze({
    required XFile video,
    required ShotAnalysisContext context,
    AnalysisStageChanged? onStage,
  });

  void close();
}
