import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../ui/liquid_glass.dart';
import 'shot_analysis_ports.dart';
import 'shot_analysis_widgets.dart';

/// End-to-end UI for selecting and analyzing a golf swing video.
///
/// The host owns the [videoSource] and [analyzer] by default. Set
/// [closeAnalyzerOnDispose] when this screen is their only owner.
class ShotAnalysisScreen extends StatefulWidget {
  const ShotAnalysisScreen({
    super.key,
    required this.videoSource,
    required this.analyzer,
    this.languageCode = 'en',
    this.translate,
    this.initialClub = '',
    this.initialCameraAngle = 'downTheLine',
    this.initialNotes = '',
    this.cameraEnabled = true,
    this.galleryEnabled = true,
    this.recoverLostVideoOnStart = true,
    this.closeAnalyzerOnDispose = false,
    this.showTechnicalErrorDetails = false,
    this.onOpenSettings,
    this.onResult,
    this.onError,
  });

  final VideoSourceGateway videoSource;
  final GolfVideoAnalyzer analyzer;
  final String languageCode;
  final ShotAnalysisTranslator? translate;
  final String initialClub;
  final String initialCameraAngle;
  final String initialNotes;
  final bool cameraEnabled;
  final bool galleryEnabled;
  final bool recoverLostVideoOnStart;
  final bool closeAnalyzerOnDispose;
  final bool showTechnicalErrorDetails;
  final Future<void> Function()? onOpenSettings;
  final ValueChanged<GolfSwingAnalysisResult>? onResult;
  final ValueChanged<ShotAnalysisException>? onError;

  @override
  State<ShotAnalysisScreen> createState() => _ShotAnalysisScreenState();
}

class _ShotAnalysisScreenState extends State<ShotAnalysisScreen> {
  late final TextEditingController _clubController;
  late final TextEditingController _notesController;
  late String _cameraAngle;

  PickedVideo? _video;
  GolfSwingAnalysisResult? _result;
  ShotAnalysisException? _error;
  AnalysisStage _stage = AnalysisStage.validating;
  bool _picking = false;
  bool _recovering = false;
  bool _analyzing = false;
  int _operation = 0;

  ShotAnalysisCopy get _copy => ShotAnalysisCopy(
    languageCode: widget.languageCode,
    translate: widget.translate,
  );

  bool get _busy => _picking || _recovering || _analyzing;

  @override
  void initState() {
    super.initState();
    _clubController = TextEditingController(text: widget.initialClub);
    _notesController = TextEditingController(text: widget.initialNotes);
    _cameraAngle =
        ShotContextForm.cameraAngles.contains(widget.initialCameraAngle)
        ? widget.initialCameraAngle
        : 'unknown';

    if (widget.recoverLostVideoOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_recoverLostVideo());
      });
    }
  }

  @override
  void didUpdateWidget(ShotAnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analyzer != widget.analyzer &&
        oldWidget.closeAnalyzerOnDispose) {
      oldWidget.analyzer.close();
    }
  }

  @override
  void dispose() {
    _operation++;
    _clubController.dispose();
    _notesController.dispose();
    if (widget.closeAnalyzerOnDispose) {
      widget.analyzer.close();
    }
    super.dispose();
  }

  Future<void> _recoverLostVideo() async {
    if (_busy || _video != null) {
      return;
    }
    final operation = ++_operation;
    setState(() {
      _recovering = true;
      _error = null;
    });

    try {
      final recovered = await widget.videoSource.recoverLostVideo();
      if (!_isCurrent(operation)) {
        return;
      }
      setState(() {
        _recovering = false;
        if (recovered != null) {
          _video = recovered;
          _result = null;
        }
      });
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      _showError(_asAnalysisException(error));
      setState(() => _recovering = false);
    }
  }

  Future<void> _pickVideo(VideoInputSource source) async {
    if (_busy) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final operation = ++_operation;
    setState(() {
      _picking = true;
      _error = null;
    });

    try {
      final video = await widget.videoSource.pickVideo(source);
      if (!_isCurrent(operation)) {
        return;
      }
      setState(() {
        _picking = false;
        if (video != null) {
          _video = video;
          _result = null;
        }
      });
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      setState(() => _picking = false);
      _showError(_asAnalysisException(error));
    }
  }

  Future<void> _analyze() async {
    if (_busy) {
      return;
    }
    final video = _video;
    if (video == null) {
      _showError(
        const ShotAnalysisException(
          ShotAnalysisErrorCode.selectionFailed,
          technicalMessage: 'No video selected.',
          retryable: false,
        ),
      );
      return;
    }
    if (!widget.analyzer.isConfigured) {
      _showError(
        const ShotAnalysisException(
          ShotAnalysisErrorCode.notConfigured,
          retryable: false,
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final operation = ++_operation;
    final context = ShotAnalysisContext(
      languageCode: _normalizedLanguageCode,
      club: _clubController.text.trim(),
      cameraAngle: _cameraAngleForAnalysis,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _analyzing = true;
      _stage = AnalysisStage.validating;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.analyzer.analyze(
        video: video.file,
        context: context,
        onStage: (stage) {
          if (_isCurrent(operation) && _analyzing && _stage != stage) {
            setState(() => _stage = stage);
          }
        },
      );
      if (!_isCurrent(operation)) {
        return;
      }
      setState(() {
        _analyzing = false;
        _result = result;
      });
      widget.onResult?.call(result);
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      setState(() => _analyzing = false);
      _showError(_asAnalysisException(error));
    }
  }

  bool _isCurrent(int operation) => mounted && operation == _operation;

  String get _normalizedLanguageCode {
    return widget.languageCode.toLowerCase().startsWith('ja') ? 'ja' : 'en';
  }

  String get _cameraAngleForAnalysis => switch (_cameraAngle) {
    'downTheLine' => 'down the line',
    'faceOn' => 'face on',
    'frontOblique' => 'front oblique',
    'rearOblique' => 'rear oblique',
    _ => 'not specified',
  };

  ShotAnalysisException _asAnalysisException(Object error) {
    return error is ShotAnalysisException
        ? error
        : ShotAnalysisException.unknown(error);
  }

  void _showError(ShotAnalysisException error) {
    if (!mounted) {
      return;
    }
    setState(() => _error = error);
    widget.onError?.call(error);
  }

  void _dismissError() {
    setState(() => _error = null);
  }

  void _removeVideo() {
    if (_busy) {
      return;
    }
    setState(() {
      _video = null;
      _result = null;
      _error = null;
    });
  }

  void _chooseAnotherVideo() {
    setState(() {
      _video = null;
      _result = null;
      _error = null;
      _stage = AnalysisStage.validating;
    });
  }

  void _resetAll() {
    if (_busy) {
      return;
    }
    setState(() {
      _video = null;
      _result = null;
      _error = null;
      _stage = AnalysisStage.validating;
      _cameraAngle = 'downTheLine';
      _clubController.clear();
      _notesController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    return LiquidGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(copy.text('Shot Analysis', 'ショット解析')),
          flexibleSpace: const LiquidGlassAppBarBackground(),
          actions: [
            if (_video != null || _result != null)
              IconButton(
                tooltip: copy.text('Reset analysis', '解析をリセット'),
                onPressed: _busy ? null : _resetAll,
                icon: const Icon(Icons.restart_alt),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _analyzing
                ? _buildProgress(copy)
                : _result != null
                ? _buildResult(copy, _result!)
                : _buildSetup(copy),
          ),
        ),
      ),
    );
  }

  Widget _buildSetup(ShotAnalysisCopy copy) {
    return LayoutBuilder(
      key: const ValueKey('shotAnalysisSetup'),
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                32,
              ),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShotAnalysisIntro(
                          copy: copy,
                          configured: widget.analyzer.isConfigured,
                        ),
                        if (_error case final error?) ...[
                          const SizedBox(height: 16),
                          ShotAnalysisErrorView(
                            copy: copy,
                            error: error,
                            onDismiss: _dismissError,
                            onRetry: error.retryable && _video != null
                                ? _analyze
                                : null,
                            onOpenSettings:
                                error.code ==
                                        ShotAnalysisErrorCode
                                            .permissionPermanentlyDenied &&
                                    widget.onOpenSettings != null
                                ? () => unawaited(widget.onOpenSettings!.call())
                                : null,
                            showTechnicalDetails:
                                widget.showTechnicalErrorDetails,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _ResponsiveSetupFields(
                          videoPicker: ShotVideoPicker(
                            copy: copy,
                            video: _video,
                            busy: _busy,
                            recovering: _recovering,
                            cameraEnabled: widget.cameraEnabled,
                            galleryEnabled: widget.galleryEnabled,
                            onCameraPressed: () =>
                                unawaited(_pickVideo(VideoInputSource.camera)),
                            onGalleryPressed: () =>
                                unawaited(_pickVideo(VideoInputSource.gallery)),
                            onRemovePressed: _removeVideo,
                          ),
                          contextForm: ShotContextForm(
                            copy: copy,
                            clubController: _clubController,
                            notesController: _notesController,
                            cameraAngle: _cameraAngle,
                            enabled: !_busy,
                            onCameraAngleChanged: (value) {
                              setState(() => _cameraAngle = value);
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildAnalyzeAction(copy),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyzeAction(ShotAnalysisCopy copy) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canAnalyze = _video != null && !_busy && widget.analyzer.isConfigured;

    return LiquidGlassSurface(
      useNativeGlass: false,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final guidance = Row(
            children: [
              Icon(
                canAnalyze ? Icons.check_circle_outline : Icons.info_outline,
                size: 20,
                color: canAnalyze ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _video == null
                      ? copy.text(
                          'Select a video to continue.',
                          '解析する動画を選択してください。',
                        )
                      : !widget.analyzer.isConfigured
                      ? copy.text(
                          'Connect the analysis service to continue.',
                          '解析サービスを接続してください。',
                        )
                      : copy.text(
                          'Your video and notes are ready.',
                          '動画と入力内容を解析できます。',
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            key: const Key('startShotAnalysisButton'),
            onPressed: canAnalyze ? () => unawaited(_analyze()) : null,
            icon: const Icon(Icons.auto_awesome),
            label: Text(copy.text('Analyze swing', 'スイングを解析')),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [guidance, const SizedBox(height: 14), action],
            );
          }

          return Row(
            children: [
              Expanded(child: guidance),
              const SizedBox(width: 18),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgress(ShotAnalysisCopy copy) {
    return SingleChildScrollView(
      key: const ValueKey('shotAnalysisProgress'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ShotAnalysisProgressView(
            copy: copy,
            stage: _stage,
            videoFileName: _video?.fileName ?? '',
            club: _clubController.text.trim(),
            cameraAngle: _cameraAngle,
          ),
        ),
      ),
    );
  }

  Widget _buildResult(ShotAnalysisCopy copy, GolfSwingAnalysisResult result) {
    return LayoutBuilder(
      key: const ValueKey('shotAnalysisResult'),
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            36,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error case final error?) ...[
                    ShotAnalysisErrorView(
                      copy: copy,
                      error: error,
                      onDismiss: _dismissError,
                      onRetry: error.retryable ? _analyze : null,
                      showTechnicalDetails: widget.showTechnicalErrorDetails,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ShotAnalysisResultView(
                    copy: copy,
                    result: result,
                    onAnalyzeAgain: () => unawaited(_analyze()),
                    onChooseAnother: _chooseAnotherVideo,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResponsiveSetupFields extends StatelessWidget {
  const _ResponsiveSetupFields({
    required this.videoPicker,
    required this.contextForm,
  });

  final Widget videoPicker;
  final Widget contextForm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [videoPicker, const SizedBox(height: 16), contextForm],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: videoPicker),
            const SizedBox(width: 16),
            Expanded(child: contextForm),
          ],
        );
      },
    );
  }
}
