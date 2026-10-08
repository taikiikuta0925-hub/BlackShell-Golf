import 'package:flutter/material.dart';

import '../../ui/liquid_glass.dart';
import 'shot_analysis_models.dart';

/// Optional localization hook supplied by the host app.
///
/// The first argument is English and the second is Japanese.
typedef ShotAnalysisTranslator =
    String Function(String english, String japanese);

/// Small, dependency-free localization helper for the shot analysis feature.
class ShotAnalysisCopy {
  const ShotAnalysisCopy({required this.languageCode, this.translate});

  final String languageCode;
  final ShotAnalysisTranslator? translate;

  bool get isJapanese => languageCode.toLowerCase().startsWith('ja');

  String text(String english, String japanese) {
    return translate?.call(english, japanese) ??
        (isJapanese ? japanese : english);
  }

  String stageLabel(AnalysisStage stage) {
    return switch (stage) {
      AnalysisStage.validating => text('Checking video', '動画を確認中'),
      AnalysisStage.uploading => text('Uploading', 'アップロード中'),
      AnalysisStage.processing => text('Preparing frames', '映像を処理中'),
      AnalysisStage.analyzing => text('Analyzing swing', 'スイングを解析中'),
      AnalysisStage.cleaningUp => text('Finishing up', '結果を仕上げ中'),
    };
  }

  String stageDescription(AnalysisStage stage) {
    return switch (stage) {
      AnalysisStage.validating => text(
        'Checking the file format and video quality.',
        'ファイル形式と映像の品質を確認しています。',
      ),
      AnalysisStage.uploading => text(
        'Securely sending the selected video for analysis.',
        '選択した動画を解析サービスへ安全に送信しています。',
      ),
      AnalysisStage.processing => text(
        'Finding the key moments in your swing.',
        'スイングの重要な瞬間を抽出しています。',
      ),
      AnalysisStage.analyzing => text(
        'Reviewing posture, sequence, balance, and club movement.',
        '姿勢、動作順序、バランス、クラブの動きを確認しています。',
      ),
      AnalysisStage.cleaningUp => text(
        'Organizing your feedback and practice tips.',
        'フィードバックと練習ポイントを整理しています。',
      ),
    };
  }

  String errorTitle(ShotAnalysisErrorCode code) {
    return switch (code) {
      ShotAnalysisErrorCode.permissionDenied ||
      ShotAnalysisErrorCode.permissionPermanentlyDenied => text(
        'Video access is needed',
        '動画へのアクセスが必要です',
      ),
      ShotAnalysisErrorCode.notConfigured => text(
        'Analysis is not configured',
        '解析サービスが未設定です',
      ),
      ShotAnalysisErrorCode.videoTooLarge => text(
        'Video is too large',
        '動画のサイズが大きすぎます',
      ),
      ShotAnalysisErrorCode.unsupportedVideo => text(
        'Video is not supported',
        '対応していない動画です',
      ),
      ShotAnalysisErrorCode.contentRejected => text(
        'Video could not be analyzed',
        'この動画は解析できませんでした',
      ),
      _ => text('Something went wrong', 'エラーが発生しました'),
    };
  }

  String errorMessage(ShotAnalysisErrorCode code) {
    return switch (code) {
      ShotAnalysisErrorCode.notConfigured => text(
        'Connect the analysis service, then try again.',
        '解析サービスを接続してから、もう一度お試しください。',
      ),
      ShotAnalysisErrorCode.permissionDenied => text(
        'Allow camera or photo access when prompted, then select the video again.',
        'カメラまたは写真へのアクセスを許可して、動画を選び直してください。',
      ),
      ShotAnalysisErrorCode.permissionPermanentlyDenied => text(
        'Enable camera or photo access in Settings, then return to the app.',
        '設定からカメラまたは写真へのアクセスを許可して、アプリに戻ってください。',
      ),
      ShotAnalysisErrorCode.selectionFailed => text(
        'The video picker could not be opened. Please try again.',
        '動画選択を開けませんでした。もう一度お試しください。',
      ),
      ShotAnalysisErrorCode.recoveryFailed => text(
        'An interrupted video selection could not be restored.',
        '中断された動画選択を復元できませんでした。',
      ),
      ShotAnalysisErrorCode.emptyVideo => text(
        'The selected file is empty. Choose a different video.',
        '選択したファイルが空です。別の動画を選んでください。',
      ),
      ShotAnalysisErrorCode.unsupportedVideo => text(
        'Choose a standard video recorded by your camera or saved in Photos.',
        'カメラで撮影した動画、または写真に保存された一般的な動画を選んでください。',
      ),
      ShotAnalysisErrorCode.videoTooLarge => text(
        'Trim the video around one swing and upload it again.',
        '1回のスイングが収まる長さに動画を短くして、もう一度お試しください。',
      ),
      ShotAnalysisErrorCode.networkUnavailable => text(
        'Check your internet connection and try again.',
        'インターネット接続を確認して、もう一度お試しください。',
      ),
      ShotAnalysisErrorCode.timeout => text(
        'The analysis took too long. Try again on a stable connection.',
        '解析がタイムアウトしました。安定した通信環境でもう一度お試しください。',
      ),
      ShotAnalysisErrorCode.unauthorized => text(
        'The analysis service could not authorize this request.',
        '解析サービスでリクエストを認証できませんでした。',
      ),
      ShotAnalysisErrorCode.rateLimited => text(
        'The service is busy. Wait a moment and try again.',
        '解析サービスが混み合っています。少し待ってからもう一度お試しください。',
      ),
      ShotAnalysisErrorCode.uploadFailed => text(
        'The video upload did not finish. Please try again.',
        '動画のアップロードが完了しませんでした。もう一度お試しください。',
      ),
      ShotAnalysisErrorCode.processingFailed => text(
        'The service could not prepare this video for analysis.',
        '動画を解析用に処理できませんでした。',
      ),
      ShotAnalysisErrorCode.contentRejected => text(
        'Use a clear golf swing video with one golfer fully visible.',
        'ゴルファーの全身がはっきり映ったスイング動画を選んでください。',
      ),
      ShotAnalysisErrorCode.invalidResponse => text(
        'The analysis result was incomplete. Please run the analysis again.',
        '解析結果が不完全でした。もう一度解析してください。',
      ),
      ShotAnalysisErrorCode.serviceUnavailable => text(
        'The analysis service is temporarily unavailable.',
        '解析サービスを一時的に利用できません。',
      ),
      ShotAnalysisErrorCode.cancelled => text(
        'The analysis was cancelled.',
        '解析がキャンセルされました。',
      ),
      ShotAnalysisErrorCode.unknown => text(
        'Please try again. If the problem continues, choose another video.',
        'もう一度お試しください。解決しない場合は別の動画を選んでください。',
      ),
    };
  }

  String angleLabel(String angle) {
    return switch (angle) {
      'downTheLine' => text('Down the line', '後方（飛球線沿い）'),
      'faceOn' => text('Face on', '正面'),
      'frontOblique' => text('Front oblique', '前方斜め'),
      'rearOblique' => text('Rear oblique', '後方斜め'),
      _ => text('Not sure', 'わからない'),
    };
  }
}

class ShotAnalysisIntro extends StatelessWidget {
  const ShotAnalysisIntro({
    super.key,
    required this.copy,
    required this.configured,
  });

  final ShotAnalysisCopy copy;
  final bool configured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LiquidGlassSurface(
      useNativeGlass: false,
      prominent: true,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.auto_awesome, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.text('AI swing review', 'AIスイング解析'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  copy.text(
                    'Upload one clear swing. You will get phase-by-phase observations and focused practice tips.',
                    '鮮明なスイング動画を1本選ぶと、動作ごとの所見と練習ポイントを確認できます。',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (!configured) ...[
                  const SizedBox(height: 12),
                  _InlineStatus(
                    icon: Icons.info_outline,
                    color: colors.error,
                    label: copy.text(
                      'The analysis service still needs to be configured.',
                      '解析サービスの設定が必要です。',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShotVideoPicker extends StatelessWidget {
  const ShotVideoPicker({
    super.key,
    required this.copy,
    required this.video,
    required this.busy,
    required this.recovering,
    required this.cameraEnabled,
    required this.galleryEnabled,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.onRemovePressed,
  });

  final ShotAnalysisCopy copy;
  final PickedVideo? video;
  final bool busy;
  final bool recovering;
  final bool cameraEnabled;
  final bool galleryEnabled;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedVideo = video;

    return LiquidGlassSurface(
      useNativeGlass: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.videocam_outlined, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  copy.text('1. Select a swing video', '1. スイング動画を選択'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            copy.text(
              'For the clearest feedback, keep the whole golfer and club in frame.',
              '正確な解析のため、全身とクラブ全体が画面に入るように撮影してください。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          if (recovering)
            _InlineStatus(
              icon: Icons.restore,
              color: colors.primary,
              label: copy.text(
                'Checking for an interrupted selection…',
                '中断された動画選択を確認しています…',
              ),
              loading: true,
            )
          else if (selectedVideo == null)
            _buildEmptyPicker(context)
          else
            _buildSelectedVideo(context, selectedVideo),
        ],
      ),
    );
  }

  Widget _buildEmptyPicker(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sports_golf,
            size: 44,
            color: colors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 12),
          Text(
            copy.text('Record or choose a short clip', '短い動画を撮影または選択'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              if (cameraEnabled)
                _SourceAction(
                  icon: Icons.photo_camera_outlined,
                  label: copy.text('Record video', '動画を撮影'),
                  semanticLabel: copy.text(
                    'Record a swing video with the camera',
                    'カメラでスイング動画を撮影',
                  ),
                  onPressed: busy ? null : onCameraPressed,
                ),
              if (galleryEnabled)
                _SourceAction(
                  icon: Icons.video_library_outlined,
                  label: copy.text('Choose from Photos', '写真から選択'),
                  semanticLabel: copy.text(
                    'Choose a swing video from Photos',
                    '写真からスイング動画を選択',
                  ),
                  onPressed: busy ? null : onGalleryPressed,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedVideo(BuildContext context, PickedVideo selectedVideo) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sourceLabel = switch (selectedVideo.source) {
      VideoInputSource.camera => copy.text('Camera', 'カメラ'),
      VideoInputSource.gallery => copy.text('Photos', '写真'),
      null when selectedVideo.recovered => copy.text('Recovered', '復元済み'),
      null => copy.text('Selected video', '選択した動画'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedVideo.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$sourceLabel · ${_formatFileSize(selectedVideo.sizeBytes)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: copy.text('Remove video', '動画を削除'),
                onPressed: busy ? null : onRemovePressed,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (cameraEnabled)
              OutlinedButton.icon(
                onPressed: busy ? null : onCameraPressed,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(copy.text('Record again', '撮り直す')),
              ),
            if (galleryEnabled)
              OutlinedButton.icon(
                onPressed: busy ? null : onGalleryPressed,
                icon: const Icon(Icons.video_library_outlined),
                label: Text(copy.text('Choose another', '別の動画を選択')),
              ),
          ],
        ),
      ],
    );
  }
}

class ShotContextForm extends StatelessWidget {
  const ShotContextForm({
    super.key,
    required this.copy,
    required this.clubController,
    required this.notesController,
    required this.cameraAngle,
    required this.onCameraAngleChanged,
    required this.enabled,
  });

  final ShotAnalysisCopy copy;
  final TextEditingController clubController;
  final TextEditingController notesController;
  final String cameraAngle;
  final ValueChanged<String> onCameraAngleChanged;
  final bool enabled;

  static const List<String> cameraAngles = [
    'downTheLine',
    'faceOn',
    'frontOblique',
    'rearOblique',
    'unknown',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LiquidGlassSurface(
      useNativeGlass: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  copy.text('2. Add swing context', '2. スイング情報を入力'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            copy.text(
              'These details help tailor the feedback. Notes are optional.',
              '入力内容をもとにフィードバックを調整します。メモは任意です。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('shotAnalysisClubField'),
            controller: clubController,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: copy.text('Club', 'クラブ'),
              hintText: copy.text('Example: 7 iron', '例：7番アイアン'),
              prefixIcon: const Icon(Icons.sports_golf),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          InputDecorator(
            key: const Key('shotAnalysisCameraAngleField'),
            decoration: InputDecoration(
              labelText: copy.text('Camera angle', '撮影アングル'),
              prefixIcon: const Icon(Icons.camera_outlined),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: cameraAngle,
                isExpanded: true,
                isDense: true,
                items: [
                  for (final angle in cameraAngles)
                    DropdownMenuItem(
                      value: angle,
                      child: Text(
                        copy.angleLabel(angle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) {
                          onCameraAngleChanged(value);
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.arrow_drop_down),
                menuMaxHeight: 360,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('shotAnalysisNotesField'),
            controller: notesController,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              alignLabelWithHint: true,
              labelText: copy.text('Notes (optional)', 'メモ（任意）'),
              hintText: copy.text(
                'Miss tendency, target, pain, or what you want to improve',
                'ミスの傾向、目標、痛み、改善したいポイントなど',
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Icon(Icons.notes),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShotAnalysisProgressView extends StatelessWidget {
  const ShotAnalysisProgressView({
    super.key,
    required this.copy,
    required this.stage,
    required this.videoFileName,
    required this.club,
    required this.cameraAngle,
  });

  final ShotAnalysisCopy copy;
  final AnalysisStage stage;
  final String videoFileName;
  final String club;
  final String cameraAngle;

  static const List<AnalysisStage> _stages = AnalysisStage.values;

  double get _progress => switch (stage) {
    AnalysisStage.validating => 0.12,
    AnalysisStage.uploading => 0.32,
    AnalysisStage.processing => 0.55,
    AnalysisStage.analyzing => 0.78,
    AnalysisStage.cleaningUp => 0.94,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentIndex = _stages.indexOf(stage);

    return Semantics(
      liveRegion: true,
      label: '${copy.stageLabel(stage)}. ${copy.stageDescription(stage)}',
      child: LiquidGlassSurface(
        useNativeGlass: false,
        prominent: true,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(colors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey(stage),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.stageLabel(stage),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy.stageDescription(stage),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              tween: Tween(end: _progress),
              duration: const Duration(milliseconds: 350),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: colors.primary.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, item) in _stages.indexed)
                  _StageChip(
                    label: copy.stageLabel(item),
                    complete: index < currentIndex,
                    active: index == currentIndex,
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 10),
            _MetadataRow(icon: Icons.video_file_outlined, label: videoFileName),
            const SizedBox(height: 8),
            _MetadataRow(
              icon: Icons.sports_golf,
              label: club.isEmpty
                  ? copy.text('Club not specified', 'クラブ指定なし')
                  : club,
            ),
            const SizedBox(height: 8),
            _MetadataRow(
              icon: Icons.camera_outlined,
              label: copy.angleLabel(cameraAngle),
            ),
            const SizedBox(height: 18),
            Text(
              copy.text(
                'Keep this screen open until the result is ready.',
                '結果が表示されるまで、この画面を開いたままにしてください。',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShotAnalysisErrorView extends StatelessWidget {
  const ShotAnalysisErrorView({
    super.key,
    required this.copy,
    required this.error,
    required this.onDismiss,
    this.onRetry,
    this.onOpenSettings,
    this.showTechnicalDetails = false,
  });

  final ShotAnalysisCopy copy;
  final ShotAnalysisException error;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;
  final bool showTechnicalDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final requiresSettings =
        error.code == ShotAnalysisErrorCode.permissionPermanentlyDenied;
    final details = error.technicalMessage?.trim();

    return Semantics(
      liveRegion: true,
      child: LiquidGlassSurface(
        useNativeGlass: false,
        tint: colors.error,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, color: colors.error),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.errorTitle(error.code),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        copy.errorMessage(error.code),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showTechnicalDetails && details != null && details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(copy.text('Technical details', '技術情報')),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SelectableText(
                        details,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: Text(copy.text('Dismiss', '閉じる')),
                ),
                if (requiresSettings && onOpenSettings != null)
                  OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(copy.text('Open Settings', '設定を開く')),
                  ),
                if (onRetry != null)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(copy.text('Try again', 'もう一度試す')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShotAnalysisResultView extends StatelessWidget {
  const ShotAnalysisResultView({
    super.key,
    required this.copy,
    required this.result,
    required this.onAnalyzeAgain,
    required this.onChooseAnother,
  });

  final ShotAnalysisCopy copy;
  final GolfSwingAnalysisResult result;
  final VoidCallback onAnalyzeAgain;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = result.summary.trim().isNotEmpty
        ? result.summary.trim()
        : result.rawResponse?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidGlassSurface(
          useNativeGlass: false,
          prominent: true,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome, color: colors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.text('Your swing review', 'スイング解析結果'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          copy.text(
                            'Use one or two cues at a time during practice.',
                            '練習では一度に1〜2個のポイントへ集中しましょう。',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                copy.text('Summary', '総評'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              SelectableText(
                summary.isEmpty
                    ? copy.text(
                        'The service returned no written summary.',
                        '解析サービスから文章の結果が返されませんでした。',
                      )
                    : summary,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 720;
            final itemWidth = twoColumns
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            final sections = <Widget>[
              if (result.strengths.isNotEmpty)
                _FeedbackSection(
                  width: itemWidth,
                  icon: Icons.check_circle_outline,
                  title: copy.text('What is working', '良いポイント'),
                  items: result.strengths,
                  color: const Color(0xFF31D17C),
                ),
              if (result.improvements.isNotEmpty)
                _FeedbackSection(
                  width: itemWidth,
                  icon: Icons.adjust,
                  title: copy.text('Focus areas', '改善ポイント'),
                  items: result.improvements,
                  color: const Color(0xFFFFA64D),
                ),
              if (result.recommendations.isNotEmpty)
                _FeedbackSection(
                  width: itemWidth,
                  icon: Icons.fitness_center,
                  title: copy.text('Practice next', 'おすすめ練習'),
                  items: result.recommendations,
                  color: colors.primary,
                  numbered: true,
                ),
              if (result.safetyNotes.isNotEmpty)
                _FeedbackSection(
                  width: itemWidth,
                  icon: Icons.health_and_safety_outlined,
                  title: copy.text('Safety notes', '安全上の注意'),
                  items: result.safetyNotes,
                  color: colors.error,
                ),
            ];

            return Wrap(spacing: 16, runSpacing: 16, children: sections);
          },
        ),
        if (result.observations.isNotEmpty) ...[
          const SizedBox(height: 16),
          _PhaseObservations(copy: copy, observations: result.observations),
        ],
        if (!result.hasStructuredFeedback && summary.isEmpty) ...[
          const SizedBox(height: 16),
          LiquidGlassSurface(
            useNativeGlass: false,
            child: Text(
              copy.text(
                'Try the analysis again or choose a clearer video.',
                'もう一度解析するか、より鮮明な動画を選んでください。',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              key: const Key('shotAnalysisChooseAnotherButton'),
              onPressed: onChooseAnother,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(copy.text('Choose another video', '別の動画を選択')),
            ),
            FilledButton.icon(
              key: const Key('shotAnalysisRunAgainButton'),
              onPressed: onAnalyzeAgain,
              icon: const Icon(Icons.refresh),
              label: Text(copy.text('Analyze again', 'もう一度解析')),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceAction extends StatelessWidget {
  const _SourceAction({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 210,
      child: LiquidGlassControl(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        useNativeGlass: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: onPressed == null ? colors.outline : colors.primary,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onPressed == null
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.color,
    required this.label,
    this.loading = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(icon, size: 19, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.complete,
    required this.active,
  });

  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final highlighted = complete || active;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primary.withValues(alpha: active ? 0.16 : 0.08)
            : colors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: active ? 0.50 : 0.22)
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete
                ? Icons.check_circle
                : active
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 15,
            color: highlighted ? colors.primary : colors.outline,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: highlighted ? colors.onSurface : colors.onSurfaceVariant,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({
    required this.width,
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
    this.numbered = false,
  });

  final double width;
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: LiquidGlassSurface(
        useNativeGlass: false,
        tint: color,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            for (final (index, item) in items.indexed)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: numbered
                          ? Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : Icon(Icons.arrow_forward, size: 13, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        item,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseObservations extends StatelessWidget {
  const _PhaseObservations({required this.copy, required this.observations});

  final ShotAnalysisCopy copy;
  final List<SwingPhaseObservation> observations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LiquidGlassSurface(
      useNativeGlass: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  copy.text('Swing phases', 'スイング動作ごとの所見'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (index, observation) in observations.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        if (index < observations.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              color: colors.primary.withValues(alpha: 0.20),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: index < observations.length - 1 ? 18 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  observation.phase.isEmpty
                                      ? copy.text('Observation', '所見')
                                      : observation.phase,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (observation.timestamp case final timestamp?)
                                Text(
                                  timestamp,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SelectableText(
                            observation.observation,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(kib >= 100 ? 0 : 1)} KB';
  }
  final mib = kib / 1024;
  if (mib < 1024) {
    return '${mib.toStringAsFixed(mib >= 100 ? 0 : 1)} MB';
  }
  final gib = mib / 1024;
  return '${gib.toStringAsFixed(1)} GB';
}
