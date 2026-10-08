import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

/// Builds the Material theme used underneath the app's liquid glass surfaces.
ThemeData buildLiquidGlassTheme(Brightness brightness) {
  final palette = _LiquidGlassPalette.forBrightness(brightness);
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        surface: palette.solidSurface,
        onSurface: palette.primaryText,
        outline: palette.border,
        outlineVariant: palette.border.withValues(alpha: 0.65),
      );

  final enabledInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: palette.border),
  );
  final focusedInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: palette.accent, width: 1.5),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: palette.solidSurface,
    disabledColor: palette.disabled,
    dividerColor: palette.border,
    focusColor: palette.accent.withValues(alpha: 0.20),
    hoverColor: palette.accent.withValues(alpha: 0.08),
    highlightColor: Colors.transparent,
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      foregroundColor: palette.primaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: palette.primaryText),
      actionsIconTheme: IconThemeData(color: palette.accent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: palette.fieldFill,
      labelStyle: TextStyle(color: palette.secondaryText),
      hintStyle: TextStyle(color: palette.secondaryText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: enabledInputBorder,
      enabledBorder: enabledInputBorder,
      focusedBorder: focusedInputBorder,
      disabledBorder: enabledInputBorder.copyWith(
        borderSide: BorderSide(color: palette.disabled),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? palette.disabled
              : palette.accentFill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? palette.secondaryText
              : palette.onAccent,
        ),
        overlayColor: WidgetStatePropertyAll(
          palette.onAccent.withValues(alpha: 0.08),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        foregroundColor: WidgetStatePropertyAll(palette.accent),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? palette.disabled
                : palette.accent,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(palette.accent),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? palette.disabled
              : palette.accent,
        ),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.onAccent
              : palette.primaryText,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accentFill
              : palette.fieldFill,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.solidSurface.withValues(alpha: 0.96),
      contentTextStyle: TextStyle(color: palette.primaryText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Paints the adaptive color field that gives glass surfaces visible depth.
class LiquidGlassBackdrop extends StatelessWidget {
  const LiquidGlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final highContrast = MediaQuery.highContrastOf(context);
    final palette = _LiquidGlassPalette.forBrightness(
      brightness,
      highContrast: highContrast,
    );

    return ColoredBox(
      color: palette.backdropMiddle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.backdropStart,
                    palette.backdropMiddle,
                    palette.backdropEnd,
                  ],
                  stops: const [0, 0.52, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -180,
            right: -120,
            width: 440,
            height: 440,
            child: _BackdropGlow(color: palette.topGlow),
          ),
          Positioned(
            left: -170,
            bottom: -230,
            width: 520,
            height: 520,
            child: _BackdropGlow(color: palette.bottomGlow),
          ),
          BackdropGroup(child: child),
        ],
      ),
    );
  }
}

/// A translucent surface with an optional iOS native liquid glass background.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.tint,
    this.prominent = false,
    this.useNativeGlass = true,
    this.interactive = false,
  }) : assert(radius >= 0);

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final bool prominent;
  final bool useNativeGlass;
  final bool interactive;

  bool get _canUseNativeGlass =>
      useNativeGlass && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final highContrast = MediaQuery.highContrastOf(context);
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final palette = _LiquidGlassPalette.forBrightness(
      brightness,
      highContrast: highContrast,
    );
    final borderRadius = BorderRadius.circular(radius);
    final effectiveTint = tint ?? palette.accent;
    final shadows = _surfaceShadows(palette);

    final surface = _canUseNativeGlass
        ? _buildNativeSurface(
            palette: palette,
            brightness: brightness,
            highContrast: highContrast,
            animationsDisabled: animationsDisabled,
            effectiveTint: effectiveTint,
          )
        : ClipRRect(
            borderRadius: borderRadius,
            child: _buildFlutterSurface(
              palette: palette,
              highContrast: highContrast,
              effectiveTint: effectiveTint,
            ),
          );

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: surface,
    );
  }

  Widget _buildNativeSurface({
    required _LiquidGlassPalette palette,
    required Brightness brightness,
    required bool highContrast,
    required bool animationsDisabled,
    required Color effectiveTint,
  }) {
    final fallbackColor = Color.alphaBlend(
      effectiveTint.withValues(alpha: prominent ? 0.10 : 0.05),
      palette.solidSurface,
    );
    final nativeTint = effectiveTint.withValues(alpha: prominent ? 0.22 : 0.13);
    final configuration = <String, Object>{
      'cornerRadius': radius,
      'tintColor': nativeTint.toARGB32(),
      'style': prominent || highContrast ? 'regular' : 'clear',
      'fallbackColor': fallbackColor.toARGB32(),
      'interactive': interactive && !animationsDisabled,
      'brightness': brightness.name,
    };

    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: _NativeLiquidGlassView(configuration: configuration),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: palette.border),
              ),
            ),
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    );
  }

  Widget _buildFlutterSurface({
    required _LiquidGlassPalette palette,
    required bool highContrast,
    required Color effectiveTint,
  }) {
    final baseFill = prominent ? palette.prominentFill : palette.glassFill;
    final tintStrength = highContrast
        ? 0.03
        : prominent
        ? 0.11
        : interactive
        ? 0.08
        : 0.055;
    final tintedFill = Color.alphaBlend(
      effectiveTint.withValues(alpha: tintStrength),
      baseFill,
    );
    final topFill = Color.alphaBlend(palette.highlight, tintedFill);
    final blur = highContrast
        ? 9.0
        : prominent
        ? 20.0
        : 14.0;

    return BackdropFilter.grouped(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topFill, tintedFill],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: palette.border),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  List<BoxShadow> _surfaceShadows(_LiquidGlassPalette palette) {
    return [
      BoxShadow(
        color: palette.shadow,
        blurRadius: prominent ? 34 : 24,
        spreadRadius: prominent ? 1 : 0,
        offset: Offset(0, prominent ? 16 : 10),
      ),
      if (interactive || prominent)
        BoxShadow(
          color: (tint ?? palette.accent).withValues(
            alpha: palette.brightness == Brightness.dark ? 0.08 : 0.05,
          ),
          blurRadius: 24,
        ),
    ];
  }
}

class _NativeLiquidGlassView extends StatefulWidget {
  const _NativeLiquidGlassView({required this.configuration});

  final Map<String, Object> configuration;

  @override
  State<_NativeLiquidGlassView> createState() => _NativeLiquidGlassViewState();
}

class _NativeLiquidGlassViewState extends State<_NativeLiquidGlassView> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(_NativeLiquidGlassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.configuration, widget.configuration)) {
      unawaited(_sendConfiguration());
    }
  }

  void _handlePlatformViewCreated(int viewId) {
    _channel = MethodChannel('blackshell/liquid_glass/$viewId');
    unawaited(_sendConfiguration());
  }

  Future<void> _sendConfiguration() async {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    try {
      await channel.invokeMethod<void>('update', widget.configuration);
    } on MissingPluginException {
      // Creation parameters still provide a complete, static configuration.
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'blackshell/liquid_glass',
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      creationParams: widget.configuration,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _handlePlatformViewCreated,
    );
  }
}

/// Adds a subtle press response without moving layout or intercepting semantics.
class LiquidGlassControl extends StatefulWidget {
  const LiquidGlassControl({
    super.key,
    required this.child,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.radius = 18,
    this.tint,
    this.prominent = false,
    this.useNativeGlass = true,
    this.semanticLabel,
    this.pressedScale = 0.975,
  }) : assert(radius >= 0),
       assert(pressedScale > 0 && pressedScale <= 1);

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final bool prominent;
  final bool useNativeGlass;
  final String? semanticLabel;
  final double pressedScale;

  @override
  State<LiquidGlassControl> createState() => _LiquidGlassControlState();
}

class _LiquidGlassControlState extends State<LiquidGlassControl> {
  bool _pressed = false;

  void _handleHighlightChanged(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onPressed != null;
    final scale = enabled && !animationsDisabled && _pressed
        ? widget.pressedScale
        : 1.0;
    final borderRadius = BorderRadius.circular(widget.radius);

    Widget result = AnimatedScale(
      scale: scale,
      duration: animationsDisabled
          ? Duration.zero
          : const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.none,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: enabled ? _handleHighlightChanged : null,
          borderRadius: borderRadius,
          canRequestFocus: enabled,
          splashFactory: animationsDisabled ? NoSplash.splashFactory : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: LiquidGlassSurface(
              padding: widget.padding,
              radius: widget.radius,
              tint: widget.tint,
              prominent: widget.prominent,
              useNativeGlass: widget.useNativeGlass,
              interactive: enabled,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    final semanticLabel = widget.semanticLabel;
    if (semanticLabel != null) {
      result = Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        child: ExcludeSemantics(child: result),
      );
    }

    return result;
  }
}

/// A drop-in background for an AppBar's [AppBar.flexibleSpace].
class LiquidGlassAppBarBackground extends StatelessWidget {
  const LiquidGlassAppBarBackground({
    super.key,
    this.tint,
    this.useNativeGlass = true,
  });

  final Color? tint;
  final bool useNativeGlass;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      padding: EdgeInsets.zero,
      radius: 0,
      tint: tint,
      prominent: true,
      useNativeGlass: useNativeGlass,
      child: const SizedBox.expand(),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassPalette {
  const _LiquidGlassPalette({
    required this.brightness,
    required this.accent,
    required this.accentFill,
    required this.onAccent,
    required this.primaryText,
    required this.secondaryText,
    required this.disabled,
    required this.solidSurface,
    required this.fieldFill,
    required this.glassFill,
    required this.prominentFill,
    required this.highlight,
    required this.border,
    required this.shadow,
    required this.backdropStart,
    required this.backdropMiddle,
    required this.backdropEnd,
    required this.topGlow,
    required this.bottomGlow,
  });

  factory _LiquidGlassPalette.forBrightness(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    if (brightness == Brightness.light) {
      return _LiquidGlassPalette(
        brightness: brightness,
        accent: const Color(0xFF006B3B),
        accentFill: const Color(0xFF69F0AE),
        onAccent: const Color(0xFF07140D),
        primaryText: const Color(0xFF101812),
        secondaryText: const Color(0xFF46564B),
        disabled: const Color(0xFF839087),
        solidSurface: const Color(0xFFF4F8F5),
        fieldFill: Colors.white.withValues(alpha: highContrast ? 0.92 : 0.58),
        glassFill: Colors.white.withValues(alpha: highContrast ? 0.92 : 0.54),
        prominentFill: Colors.white.withValues(
          alpha: highContrast ? 0.96 : 0.72,
        ),
        highlight: Colors.white.withValues(alpha: highContrast ? 0.34 : 0.22),
        border: const Color(
          0xFF274D39,
        ).withValues(alpha: highContrast ? 0.72 : 0.22),
        shadow: const Color(
          0xFF082515,
        ).withValues(alpha: highContrast ? 0.18 : 0.12),
        backdropStart: const Color(0xFFF7FBF8),
        backdropMiddle: const Color(0xFFE8F2EC),
        backdropEnd: const Color(0xFFF2F3EC),
        topGlow: const Color(
          0xFF5DE5A0,
        ).withValues(alpha: highContrast ? 0.12 : 0.24),
        bottomGlow: const Color(
          0xFF7F9DFF,
        ).withValues(alpha: highContrast ? 0.08 : 0.16),
      );
    }

    return _LiquidGlassPalette(
      brightness: brightness,
      accent: const Color(0xFF69F0AE),
      accentFill: const Color(0xFF69F0AE),
      onAccent: const Color(0xFF07140D),
      primaryText: const Color(0xFFF4FFF8),
      secondaryText: const Color(0xFFB8C8BE),
      disabled: const Color(0xFF718077),
      solidSurface: const Color(0xFF101813),
      fieldFill: Colors.white.withValues(alpha: highContrast ? 0.16 : 0.07),
      glassFill: Colors.white.withValues(alpha: highContrast ? 0.20 : 0.09),
      prominentFill: Colors.white.withValues(alpha: highContrast ? 0.26 : 0.14),
      highlight: Colors.white.withValues(alpha: highContrast ? 0.13 : 0.08),
      border: Colors.white.withValues(alpha: highContrast ? 0.46 : 0.18),
      shadow: Colors.black.withValues(alpha: highContrast ? 0.48 : 0.34),
      backdropStart: const Color(0xFF07140E),
      backdropMiddle: const Color(0xFF09110E),
      backdropEnd: const Color(0xFF11131B),
      topGlow: const Color(
        0xFF36D98B,
      ).withValues(alpha: highContrast ? 0.15 : 0.26),
      bottomGlow: const Color(
        0xFF5067D9,
      ).withValues(alpha: highContrast ? 0.10 : 0.20),
    );
  }

  final Brightness brightness;
  final Color accent;
  final Color accentFill;
  final Color onAccent;
  final Color primaryText;
  final Color secondaryText;
  final Color disabled;
  final Color solidSurface;
  final Color fieldFill;
  final Color glassFill;
  final Color prominentFill;
  final Color highlight;
  final Color border;
  final Color shadow;
  final Color backdropStart;
  final Color backdropMiddle;
  final Color backdropEnd;
  final Color topGlow;
  final Color bottomGlow;
}
