import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class LiquidGlassTabDestination {
  const LiquidGlassTabDestination({
    required this.label,
    required this.sfSymbol,
    required this.icon,
    required this.selectedIcon,
    this.accessibilityIdentifier,
  });

  final String label;
  final String sfSymbol;
  final IconData icon;
  final IconData selectedIcon;

  /// A stable identifier exposed to VoiceOver automation and XCTest.
  ///
  /// When omitted, the SF Symbol name is used to derive one. Supplying an
  /// explicit value is useful if a symbol might change while the tab's
  /// product identity stays the same.
  final String? accessibilityIdentifier;

  String get effectiveAccessibilityIdentifier =>
      accessibilityIdentifier ?? 'main-tab-$sfSymbol';
}

/// Uses a real UIKit UITabBar on iOS so current Apple releases provide their
/// native Liquid Glass material, motion, safe-area behavior, and accessibility.
/// Other platforms use Material navigation with the same destinations.
class LiquidGlassTabBar extends StatelessWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<LiquidGlassTabDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    assert(
      destinations
              .map(
                (destination) => destination.effectiveAccessibilityIdentifier,
              )
              .toSet()
              .length ==
          destinations.length,
      'LiquidGlassTabDestination accessibility identifiers must be unique.',
    );
    assert(
      destinations.isEmpty ||
          (selectedIndex >= 0 && selectedIndex < destinations.length),
      'selectedIndex must refer to a destination.',
    );

    final isNativeIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isNativeIOS) {
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      return SizedBox(
        key: const ValueKey('main-liquid-tab-bar'),
        height: kBottomNavigationBarHeight + bottomInset,
        child: _UIKitLiquidTabBar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          accentColor: Theme.of(context).colorScheme.primary,
          brightness: Theme.of(context).brightness,
          onDestinationSelected: onDestinationSelected,
        ),
      );
    }

    return NavigationBar(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.90),
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            key: ValueKey(destination.effectiveAccessibilityIdentifier),
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }
}

class _UIKitLiquidTabBar extends StatefulWidget {
  const _UIKitLiquidTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.accentColor,
    required this.brightness,
    required this.onDestinationSelected,
  });

  final List<LiquidGlassTabDestination> destinations;
  final int selectedIndex;
  final Color accentColor;
  final Brightness brightness;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<_UIKitLiquidTabBar> createState() => _UIKitLiquidTabBarState();
}

class _UIKitLiquidTabBarState extends State<_UIKitLiquidTabBar> {
  MethodChannel? _channel;

  Map<String, Object> get _configuration => {
    'selectedIndex': widget.selectedIndex,
    'accentColor': widget.accentColor.toARGB32(),
    'brightness': widget.brightness.name,
    'items': [
      for (final destination in widget.destinations)
        {
          'label': destination.label,
          'symbol': destination.sfSymbol,
          'accessibilityIdentifier':
              destination.effectiveAccessibilityIdentifier,
        },
    ],
  };

  @override
  void didUpdateWidget(_UIKitLiquidTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        !_destinationsMatch(oldWidget.destinations, widget.destinations) ||
        oldWidget.accentColor != widget.accentColor ||
        oldWidget.brightness != widget.brightness) {
      _channel?.invokeMethod<void>('update', _configuration);
    }
  }

  bool _destinationsMatch(
    List<LiquidGlassTabDestination> previous,
    List<LiquidGlassTabDestination> current,
  ) {
    if (previous.length != current.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      final before = previous[index];
      final after = current[index];
      if (before.label != after.label ||
          before.sfSymbol != after.sfSymbol ||
          before.effectiveAccessibilityIdentifier !=
              after.effectiveAccessibilityIdentifier) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int viewID) {
    final channel = MethodChannel('blackshell/liquid_tab_bar/$viewID');
    channel.setMethodCallHandler((call) async {
      if (call.method != 'selectionChanged') {
        return;
      }
      final index = (call.arguments as num?)?.toInt();
      if (index != null && index >= 0 && index < widget.destinations.length) {
        widget.onDestinationSelected(index);
      }
    });
    _channel = channel;
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      key: const ValueKey('main-liquid-tab-bar-platform-view'),
      viewType: 'blackshell/liquid_tab_bar',
      creationParams: _configuration,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
