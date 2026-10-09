import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'features/apple_sync/apple_fitness_sync.dart';
import 'features/apple_sync/apple_round_sync.dart';
import 'features/shot_analysis/cloudflare_golf_video_analyzer.dart';
import 'features/shot_analysis/image_picker_video_source.dart';
import 'features/shot_analysis/shot_analysis_screen.dart';
import 'ui/liquid_glass.dart';
import 'ui/liquid_glass_tab_bar.dart';

void main() {
  runApp(const BlackShellGolfApp());
}

enum AppLanguage { system, english, japanese }

class AppSettingsScope extends InheritedWidget {
  const AppSettingsScope({
    super.key,
    required this.themeMode,
    required this.language,
    required this.setThemeMode,
    required this.setLanguage,
    required super.child,
  });

  final ThemeMode themeMode;
  final AppLanguage language;
  final ValueChanged<ThemeMode> setThemeMode;
  final ValueChanged<AppLanguage> setLanguage;

  static AppSettingsScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()!;
  }

  @override
  bool updateShouldNotify(AppSettingsScope oldWidget) {
    return themeMode != oldWidget.themeMode || language != oldWidget.language;
  }
}

class BlackShellGolfApp extends StatefulWidget {
  const BlackShellGolfApp({super.key});

  @override
  State<BlackShellGolfApp> createState() => _BlackShellGolfAppState();
}

class _BlackShellGolfAppState extends State<BlackShellGolfApp> {
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.system;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      themeMode: _themeMode,
      language: _language,
      setThemeMode: (themeMode) => setState(() => _themeMode = themeMode),
      setLanguage: (language) => setState(() => _language = language),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BS Golf',
        locale: switch (_language) {
          AppLanguage.system => null,
          AppLanguage.english => const Locale('en'),
          AppLanguage.japanese => const Locale('ja'),
        },
        supportedLocales: const [Locale('en'), Locale('ja')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildLiquidGlassTheme(Brightness.light),
        darkTheme: buildLiquidGlassTheme(Brightness.dark),
        themeMode: _themeMode,
        home: const HomePage(),
      ),
    );
  }
}

String tr(BuildContext context, String english, String japanese) {
  return isJapanese(context) ? japanese : english;
}

bool isJapanese(BuildContext context) {
  return switch (AppSettingsScope.of(context).language) {
    AppLanguage.japanese => true,
    AppLanguage.english => false,
    AppLanguage.system =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ja',
  };
}

bool isLightMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light;
}

Color primaryTextColor(BuildContext context) {
  return isLightMode(context) ? const Color(0xFF101812) : Colors.white;
}

Color secondaryTextColor(BuildContext context) {
  return isLightMode(context)
      ? const Color(0xFF526156)
      : Colors.white.withValues(alpha: 0.62);
}

Color appAccentColor(BuildContext context) {
  return isLightMode(context) ? const Color(0xFF007A45) : Colors.greenAccent;
}

Color fieldFillColor(BuildContext context) {
  return isLightMode(context)
      ? Colors.white.withValues(alpha: 0.56)
      : Colors.white.withValues(alpha: 0.075);
}

Color panelFillColor(BuildContext context) {
  return isLightMode(context)
      ? Colors.white.withValues(alpha: 0.64)
      : Colors.white.withValues(alpha: 0.085);
}

Color panelBorderColor(BuildContext context) {
  return isLightMode(context)
      ? Colors.white.withValues(alpha: 0.82)
      : Colors.white.withValues(alpha: 0.18);
}

PreferredSizeWidget _liquidAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  bool useGlass = true,
}) {
  final overlayStyle = isLightMode(context)
      ? SystemUiOverlayStyle.dark
      : SystemUiOverlayStyle.light;
  return AppBar(
    backgroundColor: Colors.transparent,
    foregroundColor: primaryTextColor(context),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: overlayStyle.copyWith(
      statusBarColor: Colors.transparent,
    ),
    flexibleSpace: useGlass ? const LiquidGlassAppBarBackground() : null,
    title: Text(title),
    actions: actions,
  );
}

class _GlassPage extends StatelessWidget {
  const _GlassPage({required this.body, this.appBar, this.bottomNavigationBar});

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconBrightness = brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: brightness,
        statusBarIconBrightness: iconBrightness,
      ),
      child: LiquidGlassBackdrop(
        child: Scaffold(
          extendBody: bottomNavigationBar != null,
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedTab;
  int _dataVersion = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = _debugInitialTab();
    const isProduct = bool.fromEnvironment('dart.vm.product');
    const openSampleRound = bool.fromEnvironment('BLACKSHELL_SAMPLE_ROUND');
    if (!isProduct && openSampleRound) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => ScorePage(
                players: const ['Demo Player', 'Guest'],
                holes: 9,
                course: GolfzonCourseCatalog.courses.first,
              ),
            ),
          ),
        );
      });
    }
  }

  int _debugInitialTab() {
    if (const bool.fromEnvironment('dart.vm.product')) {
      return 0;
    }
    const names = ['home', 'courses', 'rounds', 'clubs', 'ai'];
    const configuredTab = String.fromEnvironment('BLACKSHELL_INITIAL_TAB');
    final configuredIndex = names.indexOf(configuredTab);
    if (configuredIndex >= 0) {
      return configuredIndex;
    }
    final environmentTab = Platform.environment['BLACKSHELL_TAB'];
    if (environmentTab != null) {
      final index = names.indexOf(environmentTab);
      if (index >= 0) {
        return index;
      }
    }
    for (final argument in Platform.executableArguments) {
      const prefix = '--blackshell-tab=';
      if (argument.startsWith(prefix)) {
        final index = names.indexOf(argument.substring(prefix.length));
        if (index >= 0) {
          return index;
        }
      }
    }
    return 0;
  }

  Future<void> _openRoundSetup([GolfCourse? course]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerSetupPage(initialCourse: course),
      ),
    );
    if (mounted) {
      setState(() => _dataVersion++);
    }
  }

  Future<void> _openShotAnalysis() async {
    final analyzer = CloudflareGolfVideoAnalyzer();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => ShotAnalysisScreen(
          videoSource: ImagePickerVideoSource(),
          analyzer: analyzer,
          languageCode: isJapanese(context) ? 'ja' : 'en',
          translate: (english, japanese) => tr(context, english, japanese),
          closeAnalyzerOnDispose: true,
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _selectedTab = index;
      if (index == 0 || index == 2) {
        _dataVersion++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      LiquidGlassTabDestination(
        label: tr(context, 'Home', 'ホーム'),
        sfSymbol: 'house.fill',
        accessibilityIdentifier: 'homeTabButton',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      LiquidGlassTabDestination(
        label: tr(context, 'Courses', 'コース'),
        sfSymbol: 'map.fill',
        accessibilityIdentifier: 'coursesTabButton',
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
      ),
      LiquidGlassTabDestination(
        label: tr(context, 'Rounds', '履歴'),
        sfSymbol: 'clock.arrow.circlepath',
        accessibilityIdentifier: 'roundsTabButton',
        icon: Icons.history,
        selectedIcon: Icons.history,
      ),
      LiquidGlassTabDestination(
        label: tr(context, 'Bag', 'クラブ'),
        sfSymbol: 'backpack.fill',
        accessibilityIdentifier: 'clubsTabButton',
        icon: Icons.backpack_outlined,
        selectedIcon: Icons.backpack,
      ),
      LiquidGlassTabDestination(
        label: tr(context, 'AI Coach', 'AI診断'),
        sfSymbol: 'sparkles',
        accessibilityIdentifier: 'aiTabButton',
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome,
      ),
    ];

    return _GlassPage(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _HomeDashboard(
            key: ValueKey('dashboard-$_dataVersion'),
            onStartRound: _openRoundSetup,
            onOpenCourses: () => _selectTab(1),
            onOpenHistory: () => _selectTab(2),
            onOpenAI: _openShotAnalysis,
            onOpenSettings: () => _showSettingsSheet(context),
          ),
          GolfCoursePickerPage(
            embedded: true,
            onCourseSelected: _openRoundSetup,
          ),
          PastRoundsPage(key: ValueKey('rounds-$_dataVersion'), embedded: true),
          const _ClubBagPage(),
          _AiHubPage(onOpenAnalysis: _openShotAnalysis),
        ],
      ),
      bottomNavigationBar: LiquidGlassTabBar(
        destinations: destinations,
        selectedIndex: _selectedTab,
        onDestinationSelected: _selectTab,
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      showDragHandle: false,
      builder: (context) {
        return SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: LiquidGlassSurface(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            radius: 30,
            prominent: true,
            useNativeGlass: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: secondaryTextColor(
                        context,
                      ).withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(context, 'Settings', '設定'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(tr(context, 'Theme', 'テーマ')),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(tr(context, 'System', 'システム')),
                      icon: const Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(tr(context, 'Dark', 'ダーク')),
                      icon: const Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(tr(context, 'Light', 'ライト')),
                      icon: const Icon(Icons.light_mode),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) {
                    settings.setThemeMode(selection.first);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 18),
                Text(tr(context, 'Language', '言語')),
                const SizedBox(height: 8),
                SegmentedButton<AppLanguage>(
                  segments: [
                    ButtonSegment(
                      value: AppLanguage.system,
                      label: Text(tr(context, 'System', 'システム')),
                    ),
                    ButtonSegment(
                      value: AppLanguage.english,
                      label: const Text('EN'),
                    ),
                    ButtonSegment(
                      value: AppLanguage.japanese,
                      label: const Text('日本語'),
                    ),
                  ],
                  selected: {settings.language},
                  onSelectionChanged: (selection) {
                    settings.setLanguage(selection.first);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({
    super.key,
    required this.onStartRound,
    required this.onOpenCourses,
    required this.onOpenHistory,
    required this.onOpenAI,
    required this.onOpenSettings,
  });

  final VoidCallback onStartRound;
  final VoidCallback onOpenCourses;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenAI;
  final VoidCallback onOpenSettings;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  late final Future<List<SavedRound>> _rounds = RoundStorage.loadRounds();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<SavedRound>>(
        future: _rounds,
        builder: (context, snapshot) {
          final summary = _DashboardSummary.fromRounds(snapshot.data ?? []);
          return CustomScrollView(
            key: const PageStorageKey('homeDashboard'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DashboardHeader(
                            onOpenSettings: widget.onOpenSettings,
                          ),
                          const SizedBox(height: 26),
                          Text(
                            tr(context, 'Ready to play?', '次のラウンドへ'),
                            style: TextStyle(
                              color: primaryTextColor(context),
                              fontSize: 32,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(
                              context,
                              'Score live, keep your streak, and review every swing.',
                              'スコア、連続記録、スイング解析をひとつに。',
                            ),
                            style: TextStyle(
                              color: secondaryTextColor(context),
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          LiquidGlassSurface(
                            radius: 28,
                            prominent: true,
                            useNativeGlass: true,
                            tint: appAccentColor(context),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: appAccentColor(
                                          context,
                                        ).withValues(alpha: 0.16),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.sports_golf,
                                        color: appAccentColor(context),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tr(context, 'New round', '新しいラウンド'),
                                            style: TextStyle(
                                              color: primaryTextColor(context),
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            tr(
                                              context,
                                              'Set players, course, and holes',
                                              'プレイヤー・コース・ホール数を設定',
                                            ),
                                            style: TextStyle(
                                              color: secondaryTextColor(
                                                context,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton.icon(
                                  key: const Key('createRoomButton'),
                                  onPressed: widget.onStartRound,
                                  icon: const Icon(Icons.flag),
                                  label: Text(
                                    tr(context, 'Create Room', 'ルーム作成'),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: widget.onOpenCourses,
                                        icon: const Icon(Icons.map_outlined),
                                        label: Text(
                                          tr(
                                            context,
                                            'Choose course',
                                            'コースから選ぶ',
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr(
                                                  context,
                                                  'Join Room Coming Soon',
                                                  'ルーム参加は準備中です',
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.group_outlined),
                                        label: Text(tr(context, 'Join', '参加')),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _AiQuickCard(onTap: widget.onOpenAI),
                          const SizedBox(height: 18),
                          _DashboardMetrics(summary: summary),
                          const SizedBox(height: 18),
                          if (summary.latest case final latest?)
                            _RecentRoundCard(
                              round: latest,
                              onOpenHistory: widget.onOpenHistory,
                            )
                          else
                            _EmptyHistoryCard(
                              onOpenCourses: widget.onOpenCourses,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: 'BS Golf',
              image: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Image.asset(
                      'assets/launch_mark.png',
                      key: const Key('homeLogo'),
                      width: 60,
                      height: 60,
                      cacheWidth: 192,
                      cacheHeight: 192,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => SizedBox(
                        width: 60,
                        height: 60,
                        child: Icon(
                          Icons.sports_golf,
                          color: appAccentColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'BS Golf',
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        LiquidGlassSurface(
          padding: EdgeInsets.zero,
          radius: 24,
          useNativeGlass: true,
          interactive: true,
          child: IconButton(
            key: const Key('settingsButton'),
            tooltip: tr(context, 'Settings', '設定'),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.tune),
          ),
        ),
      ],
    );
  }
}

class _DashboardSummary {
  const _DashboardSummary({
    required this.roundCount,
    required this.weeklyStreak,
    required this.bestScore,
    required this.latest,
  });

  final int roundCount;
  final int weeklyStreak;
  final int? bestScore;
  final SavedRound? latest;

  factory _DashboardSummary.fromRounds(List<SavedRound> rounds) {
    final sorted = [...rounds]..sort((a, b) => b.date.compareTo(a.date));
    final completedRounds = rounds
        .where((round) => !round.isAutoSaved)
        .toList();
    final scores = [
      for (final round in completedRounds)
        if (round.ranking.isNotEmpty) round.ranking.first.total,
    ];
    final weeks = <DateTime>{
      for (final round in completedRounds) _weekStart(round.date),
    }.toList()..sort((a, b) => b.compareTo(a));
    var streak = 0;
    final currentWeek = _weekStart(DateTime.now());
    final latestWeekGap = weeks.isEmpty
        ? null
        : currentWeek.difference(weeks.first).inDays;
    if (latestWeekGap == 0 || latestWeekGap == 7) {
      streak = 1;
      for (var index = 1; index < weeks.length; index++) {
        if (weeks[index - 1].difference(weeks[index]).inDays != 7) {
          break;
        }
        streak++;
      }
    }
    return _DashboardSummary(
      roundCount: completedRounds.length,
      weeklyStreak: streak,
      bestScore: scores.isEmpty
          ? null
          : scores.reduce((best, score) => score < best ? score : best),
      latest: sorted.isEmpty ? null : sorted.first,
    );
  }

  static DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({required this.summary});

  final _DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.flag_outlined,
            value: '${summary.roundCount}',
            label: tr(context, 'Rounds', 'ラウンド'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.local_fire_department_outlined,
            value: '${summary.weeklyStreak}',
            label: tr(context, 'Week streak', '週連続'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.workspace_premium_outlined,
            value: summary.bestScore == null
                ? '—'
                : formatRelativeScore(summary.bestScore!),
            label: tr(context, 'Best', 'ベスト'),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: appAccentColor(context)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRoundCard extends StatelessWidget {
  const _RecentRoundCard({required this.round, required this.onOpenHistory});

  final SavedRound round;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final leader = round.ranking.isEmpty ? null : round.ranking.first;
    return _GlassPanel(
      child: InkWell(
        onTap: onOpenHistory,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    tr(context, 'Latest round', '直近のラウンド'),
                    style: TextStyle(
                      color: appAccentColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: secondaryTextColor(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                round.courseName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatRoundDate(round.date)}  ·  ${round.holesCount}H${leader == null ? '' : '  ·  ${formatRelativeScore(leader.total)}'}',
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.onOpenCourses});

  final VoidCallback onOpenCourses;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          Icon(Icons.explore_outlined, color: appAccentColor(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Find your first course', '最初のコースを探す'),
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tr(
                    context,
                    'Browse Japan and GOLFZON simulator courses.',
                    '国内とGOLFZONのシミュレーターコースを検索できます。',
                  ),
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenCourses,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}

class _AiQuickCard extends StatelessWidget {
  const _AiQuickCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: InkWell(
        key: const Key('shotAnalysisButton'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [appAccentColor(context), const Color(0xFF7C8CFF)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Analyze your swing with AI', '動画を撮ってAI診断'),
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr(
                      context,
                      'Gemini reviews each phase and suggests focused drills.',
                      'Geminiが動きを分解し、優先ドリルを提案します。',
                    ),
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: secondaryTextColor(context)),
          ],
        ),
      ),
    );
  }
}

class _AiHubPage extends StatelessWidget {
  const _AiHubPage({required this.onOpenAnalysis});

  final VoidCallback onOpenAnalysis;

  @override
  Widget build(BuildContext context) {
    final configured = CloudflareGolfVideoAnalyzer.hasEnvironmentEndpoint;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 110),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context, 'AI Swing Coach', 'AIスイングコーチ'),
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    'Turn one swing video into clear practice priorities.',
                    '1本のスイング動画から、次に直すポイントを明確にします。',
                  ),
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 22),
                LiquidGlassSurface(
                  prominent: true,
                  radius: 28,
                  useNativeGlass: true,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF69F0AE), Color(0xFF7C8CFF)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.videocam,
                              color: Colors.black,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(context, 'Video diagnosis', '動画スイング診断'),
                                  style: TextStyle(
                                    color: primaryTextColor(context),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  configured
                                      ? tr(
                                          context,
                                          'Gemini AI configured',
                                          'Gemini AI設定済み',
                                        )
                                      : tr(
                                          context,
                                          'AI service setup required',
                                          'AIサービスの設定が必要です',
                                        ),
                                  style: TextStyle(
                                    color: configured
                                        ? appAccentColor(context)
                                        : secondaryTextColor(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        onPressed: onOpenAnalysis,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                          tr(
                            context,
                            'Choose video for AI diagnosis',
                            '動画を選んでAI診断',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final item in [
                  (
                    Icons.slow_motion_video,
                    tr(context, 'Phase-by-phase review', 'フェーズ別レビュー'),
                    tr(
                      context,
                      'Address, backswing, impact, and follow-through.',
                      'アドレス、バックスイング、インパクト、フォローを診断。',
                    ),
                  ),
                  (
                    Icons.track_changes,
                    tr(context, 'Actionable drills', '実践できるドリル'),
                    tr(
                      context,
                      'Prioritized fixes you can take to the range.',
                      '練習場ですぐ試せる改善点を優先順に表示。',
                    ),
                  ),
                  (
                    Icons.privacy_tip_outlined,
                    tr(context, 'Private by design', 'プライバシー重視'),
                    tr(
                      context,
                      'The Worker forwards the selected clip for analysis only.',
                      '選択した動画は解析時だけWorkerから転送します。',
                    ),
                  ),
                ]) ...[
                  _GlassPanel(
                    child: Row(
                      children: [
                        Icon(item.$1, color: appAccentColor(context)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: TextStyle(
                                  color: primaryTextColor(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.$3,
                                style: TextStyle(
                                  color: secondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubBagPage extends StatefulWidget {
  const _ClubBagPage();

  @override
  State<_ClubBagPage> createState() => _ClubBagPageState();
}

class _ClubBagPageState extends State<_ClubBagPage> {
  static const _clubIDs = [
    'driver',
    '3w',
    '5w',
    '7w',
    '4h',
    '4i',
    '5i',
    '6i',
    '7i',
    '8i',
    '9i',
    'pw',
    'aw',
    'sw',
    'lw',
    'putter',
  ];
  static const _defaultBag = {
    'driver',
    '3w',
    '5w',
    '4h',
    '5i',
    '6i',
    '7i',
    '8i',
    '9i',
    'pw',
    'aw',
    'sw',
    'putter',
  };

  Set<String> _selected = _defaultBag;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final stored = await ClubBagStorage.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _selected = stored ?? _defaultBag;
      _loading = false;
    });
  }

  Future<void> _toggle(String id, bool selected) async {
    if (selected && _selected.length >= 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'A golf bag can hold up to 14 clubs.',
              'クラブは14本まで登録できます。',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      final next = Set<String>.from(_selected);
      selected ? next.add(id) : next.remove(id);
      _selected = next;
    });
    await ClubBagStorage.save(_selected);
  }

  String _clubName(BuildContext context, String id) {
    const names = {
      'driver': ('Driver', 'ドライバー'),
      '3w': ('3 Wood', '3W'),
      '5w': ('5 Wood', '5W'),
      '7w': ('7 Wood', '7W'),
      '4h': ('4 Hybrid', '4U'),
      '4i': ('4 Iron', '4I'),
      '5i': ('5 Iron', '5I'),
      '6i': ('6 Iron', '6I'),
      '7i': ('7 Iron', '7I'),
      '8i': ('8 Iron', '8I'),
      '9i': ('9 Iron', '9I'),
      'pw': ('Pitching Wedge', 'PW'),
      'aw': ('Approach Wedge', 'AW'),
      'sw': ('Sand Wedge', 'SW'),
      'lw': ('Lob Wedge', 'LW'),
      'putter': ('Putter', 'パター'),
    };
    final name = names[id]!;
    return tr(context, name.$1, name.$2);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 110),
            sliver: SliverList.list(
              children: [
                Text(
                  tr(context, 'My Bag', 'マイクラブ'),
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    'Keep the clubs you actually carry ready for scoring and AI analysis.',
                    '普段使うクラブを登録して、スコア入力とAI解析に活用します。',
                  ),
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                _GlassPanel(
                  child: Row(
                    children: [
                      Icon(Icons.sports_golf, color: appAccentColor(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(context, 'Clubs in bag', 'バッグのクラブ'),
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${_selected.length} / 14',
                        style: TextStyle(
                          color: appAccentColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else
                  for (final id in _clubIDs) ...[
                    _GlassPanel(
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(id),
                        onChanged: (selected) => _toggle(id, selected),
                        secondary: Icon(
                          id == 'putter'
                              ? Icons.golf_course
                              : Icons.sports_golf,
                          color: _selected.contains(id)
                              ? appAccentColor(context)
                              : secondaryTextColor(context),
                        ),
                        title: Text(
                          _clubName(context, id),
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerSetupPage extends StatefulWidget {
  const PlayerSetupPage({super.key, this.initialCourse});

  final GolfCourse? initialCourse;

  @override
  State<PlayerSetupPage> createState() => _PlayerSetupPageState();
}

class _PlayerSetupPageState extends State<PlayerSetupPage> {
  static const int _practiceRangeMaxPlayers = 2;

  int _roundHoles = 9;
  GolfCourse? _selectedCourse;
  bool _localizedInitialCourse = false;

  late final TextEditingController _courseController;

  final List<TextEditingController> _playerControllers = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
    TextEditingController(text: 'Player 3'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.initialCourse;
    _courseController = TextEditingController(
      text: widget.initialCourse?.name ?? 'BlackShell Golf Club',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initialCourse = widget.initialCourse;
    if (!_localizedInitialCourse && initialCourse != null) {
      _courseController.text = JapanGolfCourseDirectory.displayCourseName(
        context,
        initialCourse,
      );
      _localizedInitialCourse = true;
    }
  }

  bool get _isPracticeRangeSelected =>
      _selectedCourse?.isPracticeRange ?? false;

  int get _maxPlayers =>
      _isPracticeRangeSelected ? _practiceRangeMaxPlayers : 99;

  @override
  void dispose() {
    _courseController.dispose();
    for (final controller in _playerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    if (_playerControllers.length >= _maxPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Practice ranges support up to 2 players.',
              '練習場は最大2人までです。',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _playerControllers.add(TextEditingController());
    });
  }

  void _removePlayer(int index) {
    if (_playerControllers.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'At least one player is required.', 'プレイヤーは最低1人必要です。'),
          ),
        ),
      );
      return;
    }

    setState(() {
      final controller = _playerControllers.removeAt(index);
      controller.dispose();
    });
  }

  void _startRound() {
    final selectedCourseText = _selectedCourse == null
        ? ''
        : JapanGolfCourseDirectory.displayCourseName(context, _selectedCourse!);
    final golfCourse =
        _selectedCourse != null &&
            (_selectedCourse!.name == _courseController.text.trim() ||
                selectedCourseText == _courseController.text.trim())
        ? _selectedCourse!
        : GolfCourse.manual(_courseController.text);
    final enteredPlayers = _playerControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final players = golfCourse.isPracticeRange
        ? enteredPlayers.take(_practiceRangeMaxPlayers).toList()
        : enteredPlayers;

    if (golfCourse.isPracticeRange && players.isEmpty) {
      players.add('Player 1');
    }

    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Enter at least one player name.', 'プレイヤー名を入力してください。'),
          ),
        ),
      );
      return;
    }

    final normalizedPlayerNames = <String>{};
    final hasDuplicatePlayerName = players.any(
      (name) => !normalizedPlayerNames.add(name.toLowerCase()),
    );
    if (hasDuplicatePlayerName) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Use a different name for each player.',
              'プレイヤー名はそれぞれ別の名前にしてください。',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ScorePage(players: players, holes: _roundHoles, course: golfCourse),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPage(
      appBar: _liquidAppBar(context, tr(context, 'Players', 'プレイヤー')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'Set up your room', 'ルーム設定'),
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'Add every player before the first tee.',
                  'スタート前にプレイヤーを追加してください。',
                ),
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              _GolfCourseField(
                controller: _courseController,
                onCourseSelected: (course) {
                  setState(() {
                    _selectedCourse = course;
                    if (course.isPracticeRange) {
                      while (_playerControllers.length >
                          _practiceRangeMaxPlayers) {
                        _playerControllers.removeLast().dispose();
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              _GlassPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Round', 'ラウンド'),
                        style: TextStyle(
                          color: primaryTextColor(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 9, label: Text('9H')),
                        ButtonSegment(value: 18, label: Text('18H')),
                      ],
                      selected: {_roundHoles},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.black
                              : secondaryTextColor(context),
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.greenAccent
                              : Colors.white.withValues(alpha: 0.04),
                        ),
                        side: WidgetStateProperty.all(
                          BorderSide(color: panelBorderColor(context)),
                        ),
                      ),
                      onSelectionChanged: (selection) {
                        setState(() {
                          _roundHoles = selection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: _playerControllers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _GlassPanel(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.greenAccent.withValues(
                              alpha: 0.16,
                            ),
                            foregroundColor: appAccentColor(context),
                            child: Text('${index + 1}'),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _playerControllers[index],
                              style: TextStyle(
                                color: primaryTextColor(context),
                              ),
                              cursorColor: appAccentColor(context),
                              decoration: InputDecoration(
                                hintText: tr(context, 'Player name', 'プレイヤー名'),
                                hintStyle: TextStyle(
                                  color: secondaryTextColor(context),
                                ),
                                filled: true,
                                fillColor: fieldFillColor(context),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: panelBorderColor(context),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: appAccentColor(context),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => _removePlayer(index),
                            tooltip: 'Remove player',
                            icon: const Icon(Icons.close),
                            color: secondaryTextColor(context),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.06,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Builder(
                builder: (context) {
                  final canAddPlayer = _playerControllers.length < _maxPlayers;

                  return OutlinedButton.icon(
                    key: const Key('addPlayerButton'),
                    onPressed: canAddPlayer ? _addPlayer : null,
                    icon: const Icon(Icons.add),
                    label: Text(tr(context, 'Add Player', 'プレイヤー追加')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appAccentColor(context),
                      disabledForegroundColor: secondaryTextColor(context),
                      side: BorderSide(
                        color: canAddPlayer
                            ? appAccentColor(context)
                            : panelBorderColor(context),
                        width: 1.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const Key('startScorecardButton'),
                onPressed: _startRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(
                  tr(context, 'Start Scorecard', 'スコア入力へ'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Player {
  Player({required this.name, required int holes})
    : scores = List<int>.filled(holes, 0),
      entered = List<bool>.filled(holes, false);

  final String name;
  final List<int> scores;
  final List<bool> entered;

  int get total => scores.fold(0, (sum, score) => sum + score);
}

class GolfCourse {
  const GolfCourse({
    required this.name,
    this.prefecture,
    this.isPracticeRange = false,
    this.nines = const [],
    this.latitude,
    this.longitude,
    this.country = 'Japan',
    this.totalYards,
    this.simulatorProvider,
    this.isVirtual = false,
  });

  factory GolfCourse.manual(String input) {
    final name = input.trim();
    return GolfCourse(name: name.isEmpty ? 'BlackShell Golf Club' : name);
  }

  final String name;
  final String? prefecture;
  final bool isPracticeRange;
  final List<CourseNine> nines;
  final double? latitude;
  final double? longitude;
  final String country;
  final int? totalYards;
  final String? simulatorProvider;
  final bool isVirtual;

  bool get isGolfzonCourse => simulatorProvider == 'GOLFZON';
}

class CourseNine {
  const CourseNine({required this.name, required this.holes});

  final String name;
  final List<HoleInfo> holes;
}

class HoleInfo {
  const HoleInfo({
    required this.number,
    required this.par,
    required this.yards,
  });

  final int number;
  final int par;
  final int yards;
}

List<CourseNine> standardCourseNines() {
  return const [
    CourseNine(
      name: 'OUT',
      holes: [
        HoleInfo(number: 1, par: 4, yards: 385),
        HoleInfo(number: 2, par: 5, yards: 520),
        HoleInfo(number: 3, par: 3, yards: 165),
        HoleInfo(number: 4, par: 4, yards: 410),
        HoleInfo(number: 5, par: 4, yards: 360),
        HoleInfo(number: 6, par: 5, yards: 545),
        HoleInfo(number: 7, par: 3, yards: 175),
        HoleInfo(number: 8, par: 4, yards: 395),
        HoleInfo(number: 9, par: 4, yards: 430),
      ],
    ),
    CourseNine(
      name: 'IN',
      holes: [
        HoleInfo(number: 10, par: 4, yards: 400),
        HoleInfo(number: 11, par: 4, yards: 375),
        HoleInfo(number: 12, par: 5, yards: 535),
        HoleInfo(number: 13, par: 3, yards: 170),
        HoleInfo(number: 14, par: 4, yards: 420),
        HoleInfo(number: 15, par: 4, yards: 355),
        HoleInfo(number: 16, par: 3, yards: 185),
        HoleInfo(number: 17, par: 5, yards: 550),
        HoleInfo(number: 18, par: 4, yards: 445),
      ],
    ),
  ];
}

List<CourseNine> eastWestCourseNines() {
  return const [
    CourseNine(
      name: '東',
      holes: [
        HoleInfo(number: 1, par: 4, yards: 390),
        HoleInfo(number: 2, par: 4, yards: 405),
        HoleInfo(number: 3, par: 5, yards: 535),
        HoleInfo(number: 4, par: 3, yards: 160),
        HoleInfo(number: 5, par: 4, yards: 380),
        HoleInfo(number: 6, par: 4, yards: 415),
        HoleInfo(number: 7, par: 5, yards: 550),
        HoleInfo(number: 8, par: 3, yards: 175),
        HoleInfo(number: 9, par: 4, yards: 430),
      ],
    ),
    CourseNine(
      name: '西',
      holes: [
        HoleInfo(number: 1, par: 5, yards: 540),
        HoleInfo(number: 2, par: 4, yards: 395),
        HoleInfo(number: 3, par: 3, yards: 170),
        HoleInfo(number: 4, par: 4, yards: 420),
        HoleInfo(number: 5, par: 4, yards: 365),
        HoleInfo(number: 6, par: 5, yards: 555),
        HoleInfo(number: 7, par: 4, yards: 405),
        HoleInfo(number: 8, par: 3, yards: 180),
        HoleInfo(number: 9, par: 4, yards: 435),
      ],
    ),
  ];
}

class JapanGolfCourseDirectory {
  static const String practiceRangeRegion = 'ゴルフ練習場';

  static const Map<String, String> englishRegions = {
    practiceRangeRegion: 'Practice Range',
    '北海道': 'Hokkaido',
    '東北': 'Tohoku',
    '関東': 'Kanto',
    '中部': 'Chubu',
    '関西': 'Kansai',
    '中国': 'Chugoku',
    '四国': 'Shikoku',
    '九州': 'Kyushu',
  };

  static const Map<String, String> englishPrefectures = {
    '北海道': 'Hokkaido',
    '青森県': 'Aomori',
    '岩手県': 'Iwate',
    '宮城県': 'Miyagi',
    '秋田県': 'Akita',
    '山形県': 'Yamagata',
    '福島県': 'Fukushima',
    '茨城県': 'Ibaraki',
    '栃木県': 'Tochigi',
    '群馬県': 'Gunma',
    '埼玉県': 'Saitama',
    '千葉県': 'Chiba',
    '東京都': 'Tokyo',
    '神奈川県': 'Kanagawa',
    '新潟県': 'Niigata',
    '富山県': 'Toyama',
    '石川県': 'Ishikawa',
    '福井県': 'Fukui',
    '山梨県': 'Yamanashi',
    '長野県': 'Nagano',
    '岐阜県': 'Gifu',
    '静岡県': 'Shizuoka',
    '愛知県': 'Aichi',
    '三重県': 'Mie',
    '滋賀県': 'Shiga',
    '京都府': 'Kyoto',
    '大阪府': 'Osaka',
    '兵庫県': 'Hyogo',
    '奈良県': 'Nara',
    '和歌山県': 'Wakayama',
    '鳥取県': 'Tottori',
    '島根県': 'Shimane',
    '岡山県': 'Okayama',
    '広島県': 'Hiroshima',
    '山口県': 'Yamaguchi',
    '徳島県': 'Tokushima',
    '香川県': 'Kagawa',
    '愛媛県': 'Ehime',
    '高知県': 'Kochi',
    '福岡県': 'Fukuoka',
    '佐賀県': 'Saga',
    '長崎県': 'Nagasaki',
    '熊本県': 'Kumamoto',
    '大分県': 'Oita',
    '宮崎県': 'Miyazaki',
    '鹿児島県': 'Kagoshima',
    '沖縄県': 'Okinawa',
  };

  static const Map<String, String> englishCourseNames = {
    '札幌国際カントリークラブ 島松コース': 'Sapporo Kokusai Country Club Shimamatsu Course',
    '北海道クラシックゴルフクラブ': 'Hokkaido Classic Golf Club',
    'ニドムクラシックコース': 'Nidom Classic Course',
    'ザ・ノースカントリーゴルフクラブ': 'The North Country Golf Club',
    '小樽カントリー倶楽部': 'Otaru Country Club',
    '青森カントリー倶楽部': 'Aomori Country Club',
    'みちのく国際ゴルフ倶楽部': 'Michinoku International Golf Club',
    '安比高原ゴルフクラブ': 'Appi Kogen Golf Club',
    '盛岡南ゴルフ倶楽部': 'Morioka Minami Golf Club',
    '利府ゴルフ倶楽部': 'Rifu Golf Club',
    '仙台カントリー倶楽部': 'Sendai Country Club',
    '表蔵王国際ゴルフクラブ': 'Omote Zao International Golf Club',
    '秋田カントリー倶楽部': 'Akita Country Club',
    '羽後カントリー倶楽部': 'Ugo Country Club',
    '蔵王カントリークラブ': 'Zao Country Club',
    '山形ゴルフ倶楽部': 'Yamagata Golf Club',
    'ボナリ高原ゴルフクラブ': 'Bonari Kogen Golf Club',
    'グランディ那須白河ゴルフクラブ': 'Grandee Nasu Shirakawa Golf Club',
    '大洗ゴルフ倶楽部': 'Oarai Golf Club',
    '宍戸ヒルズカントリークラブ': 'Shishido Hills Country Club',
    '太平洋クラブ 益子PGAコース': 'Taiheiyo Club Mashiko PGA Course',
    '烏山城カントリークラブ': 'Karasuyamajo Country Club',
    '軽井沢高原ゴルフ倶楽部': 'Karuizawa Kogen Golf Club',
    'サンコーカントリークラブ': 'Sanko Country Club',
    '霞ヶ関カンツリー倶楽部': 'Kasumigaseki Country Club',
    '東京ゴルフ倶楽部': 'Tokyo Golf Club',
    '武蔵カントリークラブ': 'Musashi Country Club',
    '狭山ゴルフ・クラブ': 'Sayama Golf Club',
    'カメリアヒルズカントリークラブ': 'Camellia Hills Country Club',
    '千葉カントリークラブ': 'Chiba Country Club',
    '総武カントリークラブ 総武コース': 'Sobu Country Club Sobu Course',
    '鶴舞カントリー倶楽部': 'Tsurumai Country Club',
    '袖ヶ浦カンツリークラブ 袖ヶ浦コース': 'Sodegaura Country Club Sodegaura Course',
    '赤羽ゴルフ倶楽部': 'Akabane Golf Club',
    '東京国際ゴルフ倶楽部': 'Tokyo International Golf Club',
    '東京バーディクラブ': 'Tokyo Birdie Club',
    '武蔵野ゴルフクラブ': 'Musashino Golf Club',
    '戸塚カントリー倶楽部': 'Totsuka Country Club',
    '箱根カントリー倶楽部': 'Hakone Country Club',
    '相模原ゴルフクラブ': 'Sagamihara Golf Club',
    '程ヶ谷カントリー倶楽部': 'Hodogaya Country Club',
    '富士桜カントリー倶楽部': 'Fujizakura Country Club',
    '鳴沢ゴルフ倶楽部': 'Narusawa Golf Club',
    '河口湖カントリークラブ': 'Kawaguchiko Country Club',
    'メイプルポイントゴルフクラブ': 'Maple Point Golf Club',
    '軽井沢72ゴルフ': 'Karuizawa 72 Golf',
    '三井の森軽井沢カントリー倶楽部': 'Mitsui no Mori Karuizawa Country Club',
    '大浅間ゴルフクラブ': 'Daiasama Golf Club',
    '軽井沢ゴルフ倶楽部': 'Karuizawa Golf Club',
    '川奈ホテルゴルフコース 富士コース': 'Kawana Hotel Golf Course Fuji Course',
    '太平洋クラブ 御殿場コース': 'Taiheiyo Club Gotemba Course',
    '葛城ゴルフ倶楽部': 'Katsuragi Golf Club',
    'ファイブハンドレッドクラブ': 'Five Hundred Club',
    '名古屋ゴルフ倶楽部 和合コース': 'Nagoya Golf Club Wago Course',
    '三好カントリー倶楽部': 'Miyoshi Country Club',
    '中京ゴルフ倶楽部 石野コース': 'Chukyo Golf Club Ishino Course',
    '東名古屋カントリークラブ': 'Higashi Nagoya Country Club',
    '茨木カンツリー倶楽部': 'Ibaraki Country Club',
    '枚方カントリー倶楽部': 'Hirakata Country Club',
    '泉ヶ丘カントリークラブ': 'Izumigaoka Country Club',
    '関西空港ゴルフ倶楽部': 'Kansai Airport Golf Club',
    '廣野ゴルフ倶楽部': 'Hirono Golf Club',
    '六甲国際ゴルフ倶楽部': 'Rokko Kokusai Golf Club',
    '鳴尾ゴルフ倶楽部': 'Naruo Golf Club',
    '小野ゴルフ倶楽部': 'Ono Golf Club',
    'ABCゴルフ倶楽部': 'ABC Golf Club',
    '宝塚ゴルフ倶楽部': 'Takarazuka Golf Club',
    '芥屋ゴルフ倶楽部': 'Keya Golf Club',
    '古賀ゴルフ・クラブ': 'Koga Golf Club',
    'フェニックスカントリークラブ': 'Phoenix Country Club',
    '琉球ゴルフ倶楽部': 'Ryukyu Golf Club',
    'ザ・サザンリンクスゴルフクラブ': 'The Southern Links Golf Club',
    'ロッテ葛西ゴルフ': 'Lotte Kasai Golf',
    'メトログリーン東陽町': 'Metro Green Toyocho',
    'ハンズゴルフクラブ': 'Hands Golf Club',
    'ポートアイランドゴルフ倶楽部': 'Port Island Golf Club',
    '桜宮ゴルフクラブ': 'Sakuranomiya Golf Club',
    'ライジングレディース心斎橋ゴルフスタジオ': 'Rising Ladies Shinsaibashi Golf Studio',
    '大江グランドゴルフ': 'Oe Grand Golf',
    'アコーディア・ガーデン福岡': 'Accordia Garden Fukuoka',
    'ニュー真駒内ゴルフセンター': 'New Makomanai Golf Center',
  };

  static const Map<String, List<String>> regions = {
    practiceRangeRegion: ['北海道', '東京都', '神奈川県', '愛知県', '大阪府', '兵庫県', '福岡県'],
    '北海道': ['北海道'],
    '東北': ['青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'],
    '関東': ['茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県'],
    '中部': ['新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県', '静岡県', '愛知県'],
    '関西': ['三重県', '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県'],
    '中国': ['鳥取県', '島根県', '岡山県', '広島県', '山口県'],
    '四国': ['徳島県', '香川県', '愛媛県', '高知県'],
    '九州': ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県'],
  };

  static final List<GolfCourse> courses = [
    GolfCourse(name: '札幌国際カントリークラブ 島松コース', prefecture: '北海道'),
    GolfCourse(name: '北海道クラシックゴルフクラブ', prefecture: '北海道'),
    GolfCourse(name: 'ニドムクラシックコース', prefecture: '北海道'),
    GolfCourse(name: 'ザ・ノースカントリーゴルフクラブ', prefecture: '北海道'),
    GolfCourse(name: '小樽カントリー倶楽部', prefecture: '北海道'),
    GolfCourse(name: '青森カントリー倶楽部', prefecture: '青森県'),
    GolfCourse(name: 'みちのく国際ゴルフ倶楽部', prefecture: '青森県'),
    GolfCourse(name: '安比高原ゴルフクラブ', prefecture: '岩手県'),
    GolfCourse(name: '盛岡南ゴルフ倶楽部', prefecture: '岩手県'),
    GolfCourse(name: '利府ゴルフ倶楽部', prefecture: '宮城県'),
    GolfCourse(name: '仙台カントリー倶楽部', prefecture: '宮城県'),
    GolfCourse(name: '表蔵王国際ゴルフクラブ', prefecture: '宮城県'),
    GolfCourse(name: '秋田カントリー倶楽部', prefecture: '秋田県'),
    GolfCourse(name: '羽後カントリー倶楽部', prefecture: '秋田県'),
    GolfCourse(name: '蔵王カントリークラブ', prefecture: '山形県'),
    GolfCourse(name: '山形ゴルフ倶楽部', prefecture: '山形県'),
    GolfCourse(name: 'ボナリ高原ゴルフクラブ', prefecture: '福島県'),
    GolfCourse(name: 'グランディ那須白河ゴルフクラブ', prefecture: '福島県'),
    GolfCourse(name: '大洗ゴルフ倶楽部', prefecture: '茨城県'),
    GolfCourse(name: '宍戸ヒルズカントリークラブ', prefecture: '茨城県'),
    GolfCourse(name: '太平洋クラブ 益子PGAコース', prefecture: '栃木県'),
    GolfCourse(name: '烏山城カントリークラブ', prefecture: '栃木県'),
    GolfCourse(name: '軽井沢高原ゴルフ倶楽部', prefecture: '群馬県'),
    GolfCourse(name: 'サンコーカントリークラブ', prefecture: '群馬県'),
    GolfCourse(
      name: '霞ヶ関カンツリー倶楽部',
      prefecture: '埼玉県',
      nines: eastWestCourseNines(),
    ),
    GolfCourse(name: '東京ゴルフ倶楽部', prefecture: '埼玉県'),
    GolfCourse(name: '武蔵カントリークラブ', prefecture: '埼玉県'),
    GolfCourse(name: '狭山ゴルフ・クラブ', prefecture: '埼玉県'),
    GolfCourse(name: 'カメリアヒルズカントリークラブ', prefecture: '千葉県'),
    GolfCourse(name: '千葉カントリークラブ', prefecture: '千葉県'),
    GolfCourse(name: '総武カントリークラブ 総武コース', prefecture: '千葉県'),
    GolfCourse(name: '鶴舞カントリー倶楽部', prefecture: '千葉県'),
    GolfCourse(name: '袖ヶ浦カンツリークラブ 袖ヶ浦コース', prefecture: '千葉県'),
    GolfCourse(name: '赤羽ゴルフ倶楽部', prefecture: '東京都'),
    GolfCourse(name: '東京国際ゴルフ倶楽部', prefecture: '東京都'),
    GolfCourse(name: '東京バーディクラブ', prefecture: '東京都'),
    GolfCourse(name: '武蔵野ゴルフクラブ', prefecture: '東京都'),
    GolfCourse(
      name: '戸塚カントリー倶楽部',
      prefecture: '神奈川県',
      nines: eastWestCourseNines(),
    ),
    GolfCourse(name: '箱根カントリー倶楽部', prefecture: '神奈川県'),
    GolfCourse(name: '相模原ゴルフクラブ', prefecture: '神奈川県'),
    GolfCourse(name: '程ヶ谷カントリー倶楽部', prefecture: '神奈川県'),
    GolfCourse(name: '富士桜カントリー倶楽部', prefecture: '山梨県'),
    GolfCourse(name: '鳴沢ゴルフ倶楽部', prefecture: '山梨県'),
    GolfCourse(name: '河口湖カントリークラブ', prefecture: '山梨県'),
    GolfCourse(name: 'メイプルポイントゴルフクラブ', prefecture: '山梨県'),
    GolfCourse(
      name: '軽井沢72ゴルフ',
      prefecture: '長野県',
      nines: eastWestCourseNines(),
    ),
    GolfCourse(name: '三井の森軽井沢カントリー倶楽部', prefecture: '長野県'),
    GolfCourse(name: '大浅間ゴルフクラブ', prefecture: '長野県'),
    GolfCourse(name: '軽井沢ゴルフ倶楽部', prefecture: '長野県'),
    GolfCourse(name: '川奈ホテルゴルフコース 富士コース', prefecture: '静岡県'),
    GolfCourse(name: '太平洋クラブ 御殿場コース', prefecture: '静岡県'),
    GolfCourse(name: '葛城ゴルフ倶楽部', prefecture: '静岡県'),
    GolfCourse(name: 'ファイブハンドレッドクラブ', prefecture: '静岡県'),
    GolfCourse(name: '紫雲ゴルフ倶楽部', prefecture: '新潟県'),
    GolfCourse(name: '中条ゴルフ倶楽部', prefecture: '新潟県'),
    GolfCourse(name: '呉羽カントリークラブ', prefecture: '富山県'),
    GolfCourse(name: '太閤山カントリークラブ', prefecture: '富山県'),
    GolfCourse(name: '片山津ゴルフ倶楽部', prefecture: '石川県'),
    GolfCourse(name: '能登カントリークラブ', prefecture: '石川県'),
    GolfCourse(name: '芦原ゴルフクラブ', prefecture: '福井県'),
    GolfCourse(name: '福井国際カントリークラブ', prefecture: '福井県'),
    GolfCourse(name: '岐阜関カントリー倶楽部', prefecture: '岐阜県'),
    GolfCourse(name: '谷汲カントリークラブ', prefecture: '岐阜県'),
    GolfCourse(name: '名古屋ゴルフ倶楽部 和合コース', prefecture: '愛知県'),
    GolfCourse(name: '三好カントリー倶楽部', prefecture: '愛知県'),
    GolfCourse(name: '中京ゴルフ倶楽部 石野コース', prefecture: '愛知県'),
    GolfCourse(name: '東名古屋カントリークラブ', prefecture: '愛知県'),
    GolfCourse(name: '涼仙ゴルフ倶楽部', prefecture: '三重県'),
    GolfCourse(name: '桑名カントリー倶楽部', prefecture: '三重県'),
    GolfCourse(name: '瀬田ゴルフコース', prefecture: '滋賀県'),
    GolfCourse(name: '琵琶湖カントリー倶楽部', prefecture: '滋賀県'),
    GolfCourse(name: '日野ゴルフ倶楽部', prefecture: '滋賀県'),
    GolfCourse(name: 'ザ・カントリークラブ', prefecture: '滋賀県'),
    GolfCourse(name: '城陽カントリー倶楽部', prefecture: '京都府'),
    GolfCourse(name: '田辺カントリー倶楽部', prefecture: '京都府'),
    GolfCourse(name: '茨木カンツリー倶楽部', prefecture: '大阪府'),
    GolfCourse(name: '枚方カントリー倶楽部', prefecture: '大阪府'),
    GolfCourse(name: '泉ヶ丘カントリークラブ', prefecture: '大阪府'),
    GolfCourse(name: '関西空港ゴルフ倶楽部', prefecture: '大阪府'),
    GolfCourse(name: '廣野ゴルフ倶楽部', prefecture: '兵庫県'),
    GolfCourse(
      name: '六甲国際ゴルフ倶楽部',
      prefecture: '兵庫県',
      nines: eastWestCourseNines(),
    ),
    GolfCourse(name: '鳴尾ゴルフ倶楽部', prefecture: '兵庫県'),
    GolfCourse(name: '小野ゴルフ倶楽部', prefecture: '兵庫県'),
    GolfCourse(name: 'ABCゴルフ倶楽部', prefecture: '兵庫県'),
    GolfCourse(name: '宝塚ゴルフ倶楽部', prefecture: '兵庫県'),
    GolfCourse(name: '奈良国際ゴルフ倶楽部', prefecture: '奈良県'),
    GolfCourse(name: 'KOMAカントリークラブ', prefecture: '奈良県'),
    GolfCourse(name: '橋本カントリークラブ', prefecture: '和歌山県'),
    GolfCourse(name: '紀伊高原ゴルフクラブ', prefecture: '和歌山県'),
    GolfCourse(name: '大山ゴルフクラブ', prefecture: '鳥取県'),
    GolfCourse(name: '旭国際浜村温泉ゴルフ倶楽部', prefecture: '鳥取県'),
    GolfCourse(name: '島根ゴルフ倶楽部', prefecture: '島根県'),
    GolfCourse(name: '玉造温泉カントリークラブ', prefecture: '島根県'),
    GolfCourse(name: '鬼ノ城ゴルフ倶楽部', prefecture: '岡山県'),
    GolfCourse(name: 'JFE瀬戸内海ゴルフ倶楽部', prefecture: '岡山県'),
    GolfCourse(name: '東児が丘マリンヒルズゴルフクラブ', prefecture: '岡山県'),
    GolfCourse(name: '広島カンツリー倶楽部', prefecture: '広島県'),
    GolfCourse(name: '賀茂カントリークラブ', prefecture: '広島県'),
    GolfCourse(name: '宇部72カントリークラブ', prefecture: '山口県'),
    GolfCourse(name: '下関ゴルフ倶楽部', prefecture: '山口県'),
    GolfCourse(name: '徳島カントリー倶楽部', prefecture: '徳島県'),
    GolfCourse(name: 'グランディ鳴門ゴルフクラブ36', prefecture: '徳島県'),
    GolfCourse(name: '鮎滝カントリークラブ', prefecture: '香川県'),
    GolfCourse(name: '満濃ヒルズカントリークラブ', prefecture: '香川県'),
    GolfCourse(name: 'エリエールゴルフクラブ松山', prefecture: '愛媛県'),
    GolfCourse(name: '松山ゴルフ倶楽部', prefecture: '愛媛県'),
    GolfCourse(name: '土佐カントリークラブ', prefecture: '高知県'),
    GolfCourse(name: 'Kochi黒潮カントリークラブ', prefecture: '高知県'),
    GolfCourse(name: '芥屋ゴルフ倶楽部', prefecture: '福岡県'),
    GolfCourse(name: '古賀ゴルフ・クラブ', prefecture: '福岡県'),
    GolfCourse(name: '福岡雷山ゴルフ倶楽部', prefecture: '福岡県'),
    GolfCourse(name: 'ザ・クラシックゴルフ倶楽部', prefecture: '福岡県'),
    GolfCourse(name: '若木ゴルフ倶楽部', prefecture: '佐賀県'),
    GolfCourse(name: '佐賀クラシックゴルフ倶楽部', prefecture: '佐賀県'),
    GolfCourse(name: 'パサージュ琴海アイランドゴルフクラブ', prefecture: '長崎県'),
    GolfCourse(name: '長崎国際ゴルフ倶楽部', prefecture: '長崎県'),
    GolfCourse(name: 'くまもと中央カントリークラブ', prefecture: '熊本県'),
    GolfCourse(name: '阿蘇大津ゴルフクラブ', prefecture: '熊本県'),
    GolfCourse(name: '大分カントリークラブ', prefecture: '大分県'),
    GolfCourse(name: '別府ゴルフ倶楽部', prefecture: '大分県'),
    GolfCourse(name: 'フェニックスカントリークラブ', prefecture: '宮崎県'),
    GolfCourse(name: 'UMKカントリークラブ', prefecture: '宮崎県'),
    GolfCourse(name: '鹿児島高牧カントリークラブ', prefecture: '鹿児島県'),
    GolfCourse(name: 'いぶすきゴルフクラブ', prefecture: '鹿児島県'),
    GolfCourse(name: '琉球ゴルフ倶楽部', prefecture: '沖縄県'),
    GolfCourse(name: 'ザ・サザンリンクスゴルフクラブ', prefecture: '沖縄県'),
    GolfCourse(name: 'ロッテ葛西ゴルフ', prefecture: '東京都', isPracticeRange: true),
    GolfCourse(name: 'メトログリーン東陽町', prefecture: '東京都', isPracticeRange: true),
    GolfCourse(name: 'ハンズゴルフクラブ', prefecture: '神奈川県', isPracticeRange: true),
    GolfCourse(
      name: 'ポートアイランドゴルフ倶楽部',
      prefecture: '兵庫県',
      isPracticeRange: true,
    ),
    GolfCourse(name: '桜宮ゴルフクラブ', prefecture: '大阪府', isPracticeRange: true),
    GolfCourse(
      name: 'ライジングレディース心斎橋ゴルフスタジオ',
      prefecture: '大阪府',
      isPracticeRange: true,
    ),
    GolfCourse(name: '大江グランドゴルフ', prefecture: '愛知県', isPracticeRange: true),
    GolfCourse(name: 'アコーディア・ガーデン福岡', prefecture: '福岡県', isPracticeRange: true),
    GolfCourse(name: 'ニュー真駒内ゴルフセンター', prefecture: '北海道', isPracticeRange: true),
  ];

  static List<GolfCourse> search(
    String query, {
    String? region,
    String? prefecture,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final prefectures = region == null ? null : regions[region];

    return courses.where((course) {
      if (region == practiceRangeRegion && !course.isPracticeRange) {
        return false;
      }

      if (region != practiceRangeRegion && course.isPracticeRange) {
        return false;
      }

      if (prefecture != null && course.prefecture != prefecture) {
        return false;
      }

      if (prefectures != null &&
          !prefectures.contains(course.prefecture ?? '')) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final name = course.name.toLowerCase();
      final englishName = (englishCourseNames[course.name] ?? '').toLowerCase();
      final coursePrefecture = course.prefecture?.toLowerCase() ?? '';
      final englishPrefecture = (englishPrefectures[course.prefecture] ?? '')
          .toLowerCase();
      return name.contains(normalizedQuery) ||
          englishName.contains(normalizedQuery) ||
          coursePrefecture.contains(normalizedQuery) ||
          englishPrefecture.contains(normalizedQuery);
    }).toList();
  }

  static String displayCourseName(BuildContext context, GolfCourse course) {
    if (isJapanese(context)) {
      return course.name;
    }
    return englishCourseNames[course.name] ?? course.name;
  }

  static String displayCourseNameForLanguage(
    AppLanguage language,
    GolfCourse course,
  ) {
    final usesJapanese = switch (language) {
      AppLanguage.japanese => true,
      AppLanguage.english => false,
      AppLanguage.system =>
        WidgetsBinding.instance.platformDispatcher.locale.languageCode
                .toLowerCase() ==
            'ja',
    };
    if (usesJapanese) {
      return course.name;
    }
    return englishCourseNames[course.name] ?? course.name;
  }

  static String displayPrefecture(BuildContext context, String? prefecture) {
    if (prefecture == null) {
      return '';
    }
    if (isJapanese(context)) {
      return prefecture;
    }
    return englishPrefectures[prefecture] ?? prefecture;
  }

  static String displayRegion(BuildContext context, String region) {
    if (isJapanese(context)) {
      return region;
    }
    return englishRegions[region] ?? region;
  }
}

/// A curated starter catalog from GOLFZON's public official course library.
/// Live account/score synchronization still requires a GOLFZON partner API.
class GolfzonCourseCatalog {
  static const String sourceUrl = 'https://www.golfzongolf.com/course-list';

  static const courses = <GolfCourse>[
    GolfCourse(
      name: '58 Golf Club',
      country: 'Japan',
      totalYards: 6943,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Akagi Country Club',
      country: 'Japan',
      totalYards: 6682,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Anegasaki Country Club',
      country: 'Japan',
      totalYards: 6728,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Ashitaka Six Hundred Club',
      country: 'Japan',
      totalYards: 6652,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Beppu Golf Club',
      country: 'Japan',
      totalYards: 6836,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Karuizawa Kogen Golf Club',
      country: 'Japan',
      totalYards: 6970,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Katayamazu Golf Club - Hakusan Course',
      country: 'Japan',
      totalYards: 7108,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Taiheiyo Club - Gotemba',
      country: 'Japan',
      totalYards: 7240,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Kawana Hotel Golf Club - Fuji Course',
      country: 'Japan',
      totalYards: 6603,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'The North Country Golf Club',
      country: 'Japan',
      totalYards: 7042,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'The Southern Links Golf Club',
      country: 'Japan',
      totalYards: 7019,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Kochi Kuroshio Country Club',
      country: 'Japan',
      totalYards: 7255,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Passage Kinkai Island Golf Club',
      country: 'Japan',
      totalYards: 7022,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Kiawah Island - Ocean Course',
      country: 'United States',
      totalYards: 7326,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Arnold Palmer’s Bay Hill Club and Lodge',
      country: 'United States',
      totalYards: 7374,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Pebble Beach Golf Links',
      country: 'United States',
      totalYards: 6785,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Bethpage Black Golf Course',
      country: 'United States',
      totalYards: 7530,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Harbour Town Golf Links',
      country: 'United States',
      totalYards: 6944,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Troon North Golf Club - Pinnacle',
      country: 'United States',
      totalYards: 6971,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Poppy Hills Golf Course',
      country: 'United States',
      totalYards: 6966,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'St Andrews Links - Old Course',
      country: 'United Kingdom',
      totalYards: 6943,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Old Head Golf Links',
      country: 'Ireland',
      totalYards: 7086,
      simulatorProvider: 'GOLFZON',
    ),
    GolfCourse(
      name: 'Apex Challenge Golf Club',
      country: 'Virtual',
      totalYards: 8343,
      simulatorProvider: 'GOLFZON',
      isVirtual: true,
    ),
    GolfCourse(
      name: 'Lost Valley Golf Club',
      country: 'Virtual',
      totalYards: 7317,
      simulatorProvider: 'GOLFZON',
      isVirtual: true,
    ),
    GolfCourse(
      name: 'Tokyo City Virtual Country Club',
      country: 'Virtual',
      totalYards: 6948,
      simulatorProvider: 'GOLFZON',
      isVirtual: true,
    ),
  ];

  static List<GolfCourse> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return List<GolfCourse>.of(courses);
    }
    return courses
        .where(
          (course) =>
              course.name.toLowerCase().contains(normalized) ||
              course.country.toLowerCase().contains(normalized),
        )
        .toList();
  }
}

class RoundRankingEntry {
  const RoundRankingEntry({required this.playerName, required this.total});

  final String playerName;
  final int total;

  Map<String, dynamic> toJson() {
    return {'playerName': playerName, 'total': total};
  }

  factory RoundRankingEntry.fromJson(Map<String, dynamic> json) {
    return RoundRankingEntry(
      playerName: json['playerName'] as String? ?? 'Player',
      total: json['total'] as int? ?? 0,
    );
  }
}

class SavedRound {
  const SavedRound({
    required this.id,
    required this.date,
    required this.courseName,
    required this.holesCount,
    required this.players,
    required this.scores,
    required this.total,
    required this.ranking,
    this.isAutoSaved = false,
  });

  final String id;
  final DateTime date;
  final String courseName;
  final int holesCount;
  final List<String> players;
  final Map<String, List<int>> scores;
  final Map<String, int> total;
  final List<RoundRankingEntry> ranking;
  final bool isAutoSaved;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'courseName': courseName,
      'holesCount': holesCount,
      'players': players,
      'scores': scores,
      'total': total,
      'ranking': ranking.map((entry) => entry.toJson()).toList(),
      'isAutoSaved': isAutoSaved,
    };
  }

  factory SavedRound.fromJson(Map<String, dynamic> json) {
    final scoresJson = json['scores'] as Map<String, dynamic>? ?? {};
    final totalJson = json['total'] as Map<String, dynamic>? ?? {};
    final rankingJson = json['ranking'] as List<dynamic>? ?? [];

    return SavedRound(
      id: json['id'] as String? ?? DateTime.now().toIso8601String(),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      courseName: json['courseName'] as String? ?? 'BlackShell Golf Club',
      holesCount: json['holesCount'] as int? ?? 9,
      players: (json['players'] as List<dynamic>? ?? [])
          .map((player) => player.toString())
          .toList(),
      scores: scoresJson.map(
        (name, values) => MapEntry(
          name,
          (values as List<dynamic>? ?? [])
              .map((score) => score as int? ?? 0)
              .toList(),
        ),
      ),
      total: totalJson.map((name, value) => MapEntry(name, value as int? ?? 0)),
      ranking: rankingJson
          .map(
            (entry) =>
                RoundRankingEntry.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      isAutoSaved: json['isAutoSaved'] as bool? ?? false,
    );
  }
}

class RoundStorage {
  static Future<Directory> storageDirectory() async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      return Directory(
        '${supportDirectory.path}${Platform.pathSeparator}BlackShellGolf',
      );
    } on MissingPluginException {
      // Widget tests do not register platform plugins. Keep their data isolated.
      return Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}blackshell_golf',
      );
    }
  }

  static Future<File> _roundsFile() async {
    final directory = await storageDirectory();
    return File('${directory.path}${Platform.pathSeparator}rounds.json');
  }

  static Future<List<SavedRound>> loadRounds() async {
    final file = await _roundsFile();
    if (!await file.exists()) {
      return [];
    }
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(content);
      if (decoded is! List<dynamic>) {
        return [];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedRound.fromJson)
          .toList();
    } on Object catch (error, stackTrace) {
      debugPrint('Saved round data could not be read: $error');
      debugPrintStack(stackTrace: stackTrace);
      return [];
    }
  }

  static Future<void> saveRound(SavedRound round) async {
    final rounds = await loadRounds();
    final updatedRounds = [round, ...rounds];
    final file = await _roundsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        updatedRounds.map((savedRound) => savedRound.toJson()).toList(),
      ),
    );
  }

  static Future<void> upsertAutoSave(SavedRound round) async {
    final rounds = await loadRounds();
    final updatedRounds = [
      round,
      ...rounds.where((savedRound) => savedRound.id != round.id),
    ];
    final file = await _roundsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        updatedRounds.map((savedRound) => savedRound.toJson()).toList(),
      ),
    );
  }

  static Future<void> clear() async {
    final file = await _roundsFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class ClubBagStorage {
  static Future<File> _clubsFile() async {
    final directory = await RoundStorage.storageDirectory();
    return File('${directory.path}${Platform.pathSeparator}clubs.json');
  }

  static Future<Set<String>?> load() async {
    final file = await _clubsFile();
    if (!await file.exists()) {
      return null;
    }
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(content);
      if (decoded is! List<dynamic>) {
        return null;
      }
      return decoded.map((club) => club.toString()).toSet();
    } on Object catch (error, stackTrace) {
      debugPrint('Club bag data could not be read: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<void> save(Set<String> clubs) async {
    final file = await _clubsFile();
    await file.parent.create(recursive: true);
    final sortedClubs = clubs.toList()..sort();
    await file.writeAsString(jsonEncode(sortedClubs));
  }
}

String formatRelativeScore(int score) {
  if (score > 0) {
    return '+$score';
  }
  return '$score';
}

String formatRoundDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

class Hole {
  const Hole({
    required this.number,
    required this.par,
    required this.yards,
    required this.routeName,
  });

  final int number;
  final int par;
  final int yards;
  final String routeName;
}

class ScorePage extends StatefulWidget {
  const ScorePage({
    super.key,
    required this.players,
    required this.holes,
    required this.course,
  });

  final List<String> players;
  final int holes;
  final GolfCourse course;

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  late final List<Player> _players;
  late final List<Hole> _holes;
  late final String _autoSaveId;
  late final AppleRoundSync _appleRoundSync;
  late final AppleFitnessSync _appleFitnessSync;
  late final DateTime _roundStartedAt;
  Future<void> _autoSaveOperation = Future<void>.value();
  int _currentHole = 0;
  int _currentPlayerIndex = 0;
  bool _roundFinishing = false;
  bool _roundFinished = false;
  bool _requestingFitnessAuthorization = false;
  bool _fitnessWorkoutSaved = false;
  AppleFitnessAuthorization _fitnessAuthorization =
      AppleFitnessAuthorization.unavailable;

  @override
  void initState() {
    super.initState();
    _players = widget.players
        .map((name) => Player(name: name, holes: widget.holes))
        .toList();
    _holes = _buildHoles();
    _autoSaveId = 'autosave-${DateTime.now().millisecondsSinceEpoch}';
    _roundStartedAt = DateTime.now();
    _appleRoundSync = AppleRoundSync(onWatchCommand: _handleWatchCommand);
    _appleFitnessSync = AppleFitnessSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_publishRoundState(startLiveActivity: true));
        unawaited(_refreshFitnessAuthorization());
      }
    });
  }

  @override
  void dispose() {
    _appleRoundSync.dispose(cancelActiveRound: !_roundFinished);
    super.dispose();
  }

  Hole get _hole => _holes[_currentHole];

  bool get _usesStandardScoringTemplate => widget.course.nines.isEmpty;

  List<Hole> _buildHoles() {
    final nines = widget.course.nines.isEmpty
        ? standardCourseNines()
        : widget.course.nines;

    final holes = <Hole>[];
    for (final nine in nines) {
      for (final hole in nine.holes) {
        holes.add(
          Hole(
            number: hole.number,
            par: hole.par,
            yards: hole.yards,
            routeName: nine.name,
          ),
        );
      }
    }

    return holes.take(widget.holes).toList();
  }

  List<Player> get _ranking {
    return [..._players]..sort((a, b) => a.total.compareTo(b.total));
  }

  String _scoreStatus(int score) {
    if (score <= -3) {
      return 'Albatross';
    }
    if (score == -2) {
      return 'Eagle';
    }
    if (score == -1) {
      return 'Birdie';
    }
    if (score == 0) {
      return 'Par';
    }
    if (score == 1) {
      return 'Bogey';
    }
    if (score == 2) {
      return 'Double Bogey';
    }
    return 'Triple+';
  }

  Color _scoreStatusColor(String status) {
    if (isLightMode(context)) {
      return switch (status) {
        'Albatross' => const Color(0xFF006A78),
        'Eagle' => const Color(0xFF795900),
        'Birdie' => const Color(0xFF007A45),
        'Par' => const Color(0xFF4F5D54),
        'Bogey' => const Color(0xFF914900),
        'Double Bogey' || 'Triple+' => const Color(0xFFB3261E),
        'Not set' => const Color(0xFF5F6F64),
        _ => const Color(0xFF5F6F64),
      };
    }

    return switch (status) {
      'Albatross' => Colors.cyanAccent,
      'Eagle' => const Color(0xFFFFD166),
      'Birdie' => const Color(0xFF7CFFCB),
      'Par' => Colors.white54,
      'Bogey' => const Color(0xFFFFA24C),
      'Double Bogey' || 'Triple+' => const Color(0xFFFF5C5C),
      'Not set' => const Color(0xFF8A978E),
      _ => Colors.white38,
    };
  }

  bool get _isCurrentHoleComplete {
    return _players.every((player) => player.entered[_currentHole]);
  }

  bool get _isLastHole {
    return _currentHole == widget.holes - 1;
  }

  String _rankLabel(Player player) {
    final sameScoreCount = _players
        .where((candidate) => candidate.total == player.total)
        .length;
    if (sameScoreCount > 1) {
      return tr(context, 'Draw', 'ドロー');
    }
    return '#${_ranking.indexOf(player) + 1}';
  }

  void _showIncompleteHoleMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            context,
            'Enter every player score before moving on.',
            '全員のスコアを入力してから進んでください。',
          ),
        ),
      ),
    );
  }

  Future<void> _refreshFitnessAuthorization() async {
    final authorization = await _appleFitnessSync.authorizationStatus();
    if (!mounted) {
      return;
    }
    setState(() => _fitnessAuthorization = authorization);
  }

  Future<void> _connectAppleFitness() async {
    if (_requestingFitnessAuthorization) {
      return;
    }

    final currentAuthorization = await _appleFitnessSync.authorizationStatus();
    if (!mounted) {
      return;
    }
    setState(() => _fitnessAuthorization = currentAuthorization);

    if (currentAuthorization == AppleFitnessAuthorization.authorized) {
      _showFitnessMessage(
        tr(
          context,
          'Apple Fitness is connected. This round will be saved as a golf workout.',
          'Apple Fitnessと連携済みです。このラウンドはゴルフワークアウトとして保存されます。',
        ),
      );
      return;
    }

    if (currentAuthorization == AppleFitnessAuthorization.unavailable) {
      _showFitnessMessage(
        tr(
          context,
          'Apple Health is not available on this device.',
          'この端末ではAppleヘルスケアを利用できません。',
        ),
      );
      return;
    }

    final shouldConnect = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'Connect Apple Fitness', 'Apple Fitnessと連携')),
        content: Text(
          tr(
            context,
            'When you finish, BS Golf will save the round duration, course, and hole count as a golf workout. It does not read health data.',
            'ラウンド終了時に、時間・コース・ホール数をゴルフワークアウトとして保存します。健康データの読み取りは行いません。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, 'Not now', '今はしない')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(context, 'Connect', '連携する')),
          ),
        ],
      ),
    );
    if (shouldConnect != true || !mounted) {
      return;
    }

    setState(() => _requestingFitnessAuthorization = true);
    try {
      final authorization = await _appleFitnessSync.requestAuthorization();
      if (!mounted) {
        return;
      }
      setState(() => _fitnessAuthorization = authorization);
      _showFitnessMessage(
        authorization == AppleFitnessAuthorization.authorized
            ? tr(
                context,
                'Connected. The completed round will appear in Apple Fitness.',
                '連携しました。完了したラウンドはApple Fitnessに表示されます。',
              )
            : tr(
                context,
                'Workout access was not granted. You can change it in Settings > Health.',
                'ワークアウトへのアクセスが許可されませんでした。設定の「ヘルスケア」から変更できます。',
              ),
      );
    } catch (error, stackTrace) {
      debugPrint('Apple Fitness authorization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showFitnessMessage(
          tr(
            context,
            'Apple Fitness could not be connected.',
            'Apple Fitnessに接続できませんでした。',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requestingFitnessAuthorization = false);
      }
    }
  }

  void _showFitnessMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _saveFitnessWorkoutIfEnabled() async {
    if (_fitnessWorkoutSaved) {
      return true;
    }

    final authorization = await _appleFitnessSync.authorizationStatus();
    if (!mounted) {
      return false;
    }
    if (authorization != _fitnessAuthorization) {
      setState(() => _fitnessAuthorization = authorization);
    }
    if (authorization != AppleFitnessAuthorization.authorized) {
      return false;
    }

    try {
      final workoutID = await _appleFitnessSync.saveGolfWorkout(
        startedAt: _roundStartedAt,
        endedAt: DateTime.now(),
        roundId: _autoSaveId,
        courseName: JapanGolfCourseDirectory.displayCourseName(
          context,
          widget.course,
        ),
        holeCount: widget.holes,
        indoor: widget.course.isPracticeRange || widget.course.isGolfzonCourse,
      );
      final saved = workoutID != null && workoutID.isNotEmpty;
      if (mounted) {
        setState(() => _fitnessWorkoutSaved = saved);
      }
      return saved;
    } catch (error, stackTrace) {
      debugPrint('Apple Fitness workout save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Widget _fitnessAction() {
    final connected =
        _fitnessAuthorization == AppleFitnessAuthorization.authorized;
    return IconButton(
      key: const Key('appleFitnessButton'),
      onPressed: _requestingFitnessAuthorization ? null : _connectAppleFitness,
      tooltip: connected
          ? tr(context, 'Apple Fitness connected', 'Apple Fitness連携済み')
          : tr(context, 'Connect Apple Fitness', 'Apple Fitnessと連携'),
      icon: _requestingFitnessAuthorization
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(connected ? Icons.favorite : Icons.favorite_border),
      color: connected ? const Color(0xFFFF375F) : primaryTextColor(context),
    );
  }

  String _scoreStatusLabel(BuildContext context, String status) {
    return switch (status) {
      'Not set' => tr(context, 'Not set', '未入力'),
      'Albatross' => tr(context, 'Albatross', 'アルバトロス'),
      'Eagle' => tr(context, 'Eagle', 'イーグル'),
      'Birdie' => tr(context, 'Birdie', 'バーディー'),
      'Par' => tr(context, 'Par', 'パー'),
      'Bogey' => tr(context, 'Bogey', 'ボギー'),
      'Double Bogey' => tr(context, 'Double Bogey', 'ダブルボギー'),
      'Triple+' => tr(context, 'Triple+', 'トリプル+'),
      _ => status,
    };
  }

  String _holeSubtitle() {
    final courseName = JapanGolfCourseDirectory.displayCourseName(
      context,
      widget.course,
    );
    if (widget.course.isPracticeRange) {
      return courseName;
    }

    if (_usesStandardScoringTemplate) {
      return '$courseName  /  ${tr(context, 'Standard scoring template', '標準スコアテンプレート')}';
    }

    final routeName = tr(
      context,
      _hole.routeName == '東'
          ? 'East'
          : _hole.routeName == '西'
          ? 'West'
          : _hole.routeName,
      _hole.routeName,
    );
    return '$courseName  /  $routeName  /  Par ${_hole.par}  /  ${_hole.yards}y';
  }

  void _markPar(Player player) {
    setState(() {
      _currentPlayerIndex = _players.indexOf(player);
      player.scores[_currentHole] = 0;
      player.entered[_currentHole] = true;
    });
    unawaited(_afterScoreChanged());
  }

  void _changeScore(Player player, int delta) {
    final nextScore = player.scores[_currentHole] + delta;
    if (nextScore < -9 || nextScore > 9) {
      return;
    }

    setState(() {
      _currentPlayerIndex = _players.indexOf(player);
      player.scores[_currentHole] = nextScore;
      player.entered[_currentHole] = true;
    });
    unawaited(_afterScoreChanged());
  }

  void _goToPreviousHole() {
    if (_currentHole == 0) {
      return;
    }

    setState(() {
      _currentHole--;
    });
    unawaited(_autoSaveRound());
    unawaited(_publishRoundState());
  }

  void _goToNextHole() {
    if (!_isCurrentHoleComplete) {
      _showIncompleteHoleMessage();
      return;
    }

    unawaited(_autoSaveRound());

    if (_isLastHole) {
      unawaited(_showFinalRanking());
      return;
    }

    setState(() {
      _currentHole++;
    });
    unawaited(_publishRoundState());
  }

  Future<void> _showFinalRanking() async {
    if (_roundFinished || _roundFinishing) {
      return;
    }
    _roundFinishing = true;
    await _saveCompletedRound();
    await _appleRoundSync.finish(
      _buildRoundSyncState(isComplete: true),
      immediate: false,
    );
    if (!mounted) {
      return;
    }
    _roundFinished = true;
    final savedToFitness = await _saveFitnessWorkoutIfEnabled();
    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinalRankingPage(
          courseName: JapanGolfCourseDirectory.displayCourseName(
            context,
            widget.course,
          ),
          holeCount: widget.holes,
          players: _ranking,
          savedToFitness: savedToFitness,
        ),
      ),
    );

    if (mounted) {
      _roundFinished = false;
      _roundFinishing = false;
      await _publishRoundState(startLiveActivity: true);
    }
  }

  Future<void> _afterScoreChanged() async {
    await Future.wait([_autoSaveRound(), _publishRoundState()]);
  }

  void _handleWatchCommand(WatchRoundCommand command) {
    if (!mounted || _roundFinished || _roundFinishing) {
      return;
    }

    switch (command.name) {
      case 'scoreDelta':
        final playerIndex = command.playerIndex;
        final delta = command.delta;
        if (playerIndex == null ||
            delta == null ||
            playerIndex < 0 ||
            playerIndex >= _players.length ||
            (delta != -1 && delta != 1)) {
          return;
        }
        _changeScore(_players[playerIndex], delta);
        return;
      case 'markPar':
        final playerIndex = command.playerIndex;
        if (playerIndex == null ||
            playerIndex < 0 ||
            playerIndex >= _players.length) {
          return;
        }
        _markPar(_players[playerIndex]);
        return;
      case 'previousHole':
        _goToPreviousHole();
        return;
      case 'nextHole':
        _goToNextHole();
        return;
    }
  }

  Future<void> _publishRoundState({bool startLiveActivity = false}) {
    return _appleRoundSync.publish(
      _buildRoundSyncState(),
      startLiveActivity: startLiveActivity,
    );
  }

  Map<String, Object?> _buildRoundSyncState({bool isComplete = false}) {
    final currentPlayer = _players[_currentPlayerIndex];
    final leader = _ranking.first;
    return {
      'active': !isComplete,
      'roundId': _autoSaveId,
      'courseName': JapanGolfCourseDirectory.displayCourseName(
        context,
        widget.course,
      ),
      'holeNumber': _hole.number,
      'holeIndex': _currentHole,
      'holeCount': widget.holes,
      'routeName': _hole.routeName,
      'par': _usesStandardScoringTemplate ? 0 : _hole.par,
      if (!_usesStandardScoringTemplate) 'yards': _hole.yards,
      'currentPlayerIndex': _currentPlayerIndex,
      'currentPlayerName': currentPlayer.name,
      'currentHoleScore': currentPlayer.scores[_currentHole],
      'currentHoleEntered': currentPlayer.entered[_currentHole],
      'currentToPar': currentPlayer.total,
      'leaderName': leader.name,
      'leaderToPar': leader.total,
      'statusLabel': isComplete
          ? tr(context, 'Round complete', 'ラウンド終了')
          : _isCurrentHoleComplete
          ? tr(context, 'Ready for next hole', '次のホールへ進めます')
          : tr(context, 'Scoring', 'スコア入力中'),
      'statusCode': isComplete
          ? 'complete'
          : _isCurrentHoleComplete
          ? 'readyForNextHole'
          : 'scoring',
      'isComplete': isComplete,
      'holeComplete': _isCurrentHoleComplete,
      'isLastHole': _isLastHole,
      'players': [
        for (final player in _players)
          {
            'name': player.name,
            'holeScore': player.scores[_currentHole],
            'entered': player.entered[_currentHole],
            'totalScore': player.total,
            'toPar': player.total,
          },
      ],
    };
  }

  SavedRound _buildSavedRound({required bool isAutoSaved}) {
    return SavedRound(
      id: _autoSaveId,
      date: _roundStartedAt,
      courseName: widget.course.name,
      holesCount: widget.holes,
      players: _players.map((player) => player.name).toList(),
      scores: {
        for (final player in _players)
          player.name: List<int>.from(player.scores),
      },
      total: {for (final player in _players) player.name: player.total},
      ranking: _ranking
          .map(
            (player) =>
                RoundRankingEntry(playerName: player.name, total: player.total),
          )
          .toList(),
      isAutoSaved: isAutoSaved,
    );
  }

  Future<void> _autoSaveRound() {
    final snapshot = _buildSavedRound(isAutoSaved: true);
    _autoSaveOperation = _autoSaveOperation
        .then((_) => RoundStorage.upsertAutoSave(snapshot))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Round auto-save failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
    return _autoSaveOperation;
  }

  Future<void> _saveCompletedRound() {
    final snapshot = _buildSavedRound(isAutoSaved: false);
    _autoSaveOperation = _autoSaveOperation
        .then((_) => RoundStorage.upsertAutoSave(snapshot))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Completed round save failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
    return _autoSaveOperation;
  }

  Widget _buildHoleHeader() {
    final progress = (_currentHole + 1) / widget.holes;

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tr(context, 'Hole', 'ホール')} ${_hole.number}',
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${_currentHole + 1} / ${widget.holes}',
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _HoleButton(
                icon: Icons.chevron_left,
                tooltip: tr(context, 'Previous hole', '前のホール'),
                onPressed: _currentHole == 0 ? null : _goToPreviousHole,
              ),
              const SizedBox(width: 8),
              _HoleButton(
                icon: Icons.chevron_right,
                tooltip: tr(context, 'Next hole', '次のホール'),
                onPressed: _currentHole == widget.holes - 1
                    ? null
                    : _goToNextHole,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: appAccentColor(context),
              backgroundColor: fieldFillColor(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _holeSubtitle(),
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreReadout({
    required Player player,
    required int score,
    required bool isEntered,
    required String status,
    required Color statusColor,
  }) {
    return Semantics(
      button: true,
      liveRegion: true,
      label:
          '${player.name}, ${tr(context, 'hole score', 'ホールスコア')} '
          '${isEntered ? formatRelativeScore(score) : tr(context, 'not set', '未入力')}, '
          '${_scoreStatusLabel(context, status)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _markPar(player),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(context, 'HOLE SCORE', 'ホールスコア'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEntered ? formatRelativeScore(score) : '–',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isEntered
                      ? appAccentColor(context)
                      : secondaryTextColor(context),
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              _ScoreStatusBadge(
                label: _scoreStatusLabel(context, status),
                color: statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    final score = player.scores[_currentHole];
    final isEntered = player.entered[_currentHole];
    final status = isEntered ? _scoreStatus(score) : 'Not set';
    final statusColor = _scoreStatusColor(status);

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  player.name,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: fieldFillColor(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: panelBorderColor(context)),
                ),
                child: Text(
                  '${tr(context, 'Total', '合計')} ${formatRelativeScore(player.total)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fieldFillColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEntered
                    ? statusColor.withValues(alpha: 0.26)
                    : panelBorderColor(context),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final stackControls =
                    constraints.maxWidth < 300 || textScale > 1.45;
                final readout = _buildScoreReadout(
                  player: player,
                  score: score,
                  isEntered: isEntered,
                  status: status,
                  statusColor: statusColor,
                );
                final removeButton = _ScoreButton(
                  icon: Icons.remove,
                  tooltip: tr(context, 'Decrease score', 'スコアを減らす'),
                  onPressed: score <= -9
                      ? null
                      : () => _changeScore(player, -1),
                );
                final addButton = _ScoreButton(
                  icon: Icons.add,
                  tooltip: tr(context, 'Increase score', 'スコアを増やす'),
                  onPressed: score >= 9 ? null : () => _changeScore(player, 1),
                );

                if (stackControls) {
                  return Column(
                    children: [
                      readout,
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          removeButton,
                          const SizedBox(width: 18),
                          addButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    removeButton,
                    Expanded(child: readout),
                    addButton,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingPanel() {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.leaderboard_rounded,
                color: appAccentColor(context),
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tr(context, 'Ranking', 'ランキング'),
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._ranking.indexed.map((entry) {
            final index = entry.$1;
            final player = entry.$2;

            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 7),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: index == 0
                      ? appAccentColor(context).withValues(alpha: 0.10)
                      : fieldFillColor(context),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: index == 0
                        ? appAccentColor(context).withValues(alpha: 0.28)
                        : panelBorderColor(context),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: appAccentColor(context).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _rankLabel(player),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: appAccentColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.name,
                        style: TextStyle(
                          color: primaryTextColor(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatRelativeScore(player.total),
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedPlayers = _players
        .where((player) => player.entered[_currentHole])
        .length;

    return _GlassPage(
      appBar: _liquidAppBar(
        context,
        tr(context, 'Scorecard', 'スコアカード'),
        actions: [_fitnessAction()],
        useGlass: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 420 ? 14.0 : 24.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                24,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHoleHeader(),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 5,
                          children: [
                            Text(
                              tr(context, 'Players', 'プレイヤー'),
                              style: TextStyle(
                                color: primaryTextColor(context),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              isJapanese(context)
                                  ? '$completedPlayers / ${_players.length} 入力済み'
                                  : '$completedPlayers / ${_players.length} scored',
                              style: TextStyle(
                                color: secondaryTextColor(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final player in _players) ...[
                          _buildPlayerCard(player),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        _buildRankingPanel(),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          key: const Key('nextHoleButton'),
                          onPressed: _goToNextHole,
                          icon: Icon(
                            _isLastHole
                                ? Icons.emoji_events
                                : Icons.arrow_forward,
                          ),
                          label: Text(
                            _isLastHole
                                ? tr(context, 'Final Ranking', '最終ランキング')
                                : tr(context, 'Next Hole', '次のホールへ'),
                            textAlign: TextAlign.center,
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(58),
                            backgroundColor: appAccentColor(context),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(19),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HoleButton extends StatelessWidget {
  const _HoleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
        color: onPressed == null
            ? secondaryTextColor(context).withValues(alpha: 0.45)
            : appAccentColor(context),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          backgroundColor: fieldFillColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class FinalRankingPage extends StatelessWidget {
  const FinalRankingPage({
    super.key,
    required this.courseName,
    required this.holeCount,
    required this.players,
    this.savedToFitness = false,
  });

  final String courseName;
  final int holeCount;
  final List<Player> players;
  final bool savedToFitness;

  String _rankLabel(BuildContext context, Player player) {
    final sameScoreCount = players
        .where((candidate) => candidate.total == player.total)
        .length;
    if (sameScoreCount > 1) {
      return tr(context, 'Draw', 'ドロー');
    }
    return '#${players.indexOf(player) + 1}';
  }

  void _startAnotherRound(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PlayerSetupPage()),
      (route) => route.isFirst,
    );
  }

  void _finish(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPage(
      appBar: _liquidAppBar(context, tr(context, 'Final Ranking', '最終ランキング')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                courseName,
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'Round complete', 'ラウンド終了'),
                style: TextStyle(color: secondaryTextColor(context)),
              ),
              if (savedToFitness) ...[
                const SizedBox(height: 14),
                _GlassPanel(
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Color(0xFFFF375F)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(
                            context,
                            'Saved $holeCount holes at $courseName to Apple Fitness',
                            '$courseName・$holeCountホールをApple Fitnessに保存しました',
                          ),
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return _GlassPanel(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              _rankLabel(context, player),
                              style: TextStyle(
                                color: appAccentColor(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              player.name,
                              style: TextStyle(
                                color: primaryTextColor(context),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            formatRelativeScore(player.total),
                            style: TextStyle(
                              color: primaryTextColor(context),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _startAnotherRound(context),
                icon: const Icon(Icons.refresh),
                label: Text(tr(context, 'Another Round', 'もう一ラウンド')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _finish(context),
                icon: const Icon(Icons.home),
                label: Text(tr(context, 'Finish', '終わる')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: appAccentColor(context),
                  side: BorderSide(color: appAccentColor(context)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GolfCourseField extends StatelessWidget {
  const _GolfCourseField({
    required this.controller,
    required this.onCourseSelected,
  });

  final TextEditingController controller;
  final ValueChanged<GolfCourse> onCourseSelected;

  Future<void> _pickCourse(BuildContext context) async {
    final language = AppSettingsScope.of(context).language;
    final selectedCourse = await Navigator.push<GolfCourse>(
      context,
      MaterialPageRoute(builder: (context) => const GolfCoursePickerPage()),
    );

    if (selectedCourse == null) {
      return;
    }

    controller.text = JapanGolfCourseDirectory.displayCourseNameForLanguage(
      language,
      selectedCourse,
    );
    onCourseSelected(selectedCourse);
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          Icon(Icons.location_on, color: appAccentColor(context)),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              key: const Key('golfCourseField'),
              controller: controller,
              style: TextStyle(color: primaryTextColor(context)),
              cursorColor: appAccentColor(context),
              decoration: InputDecoration(
                labelText: tr(context, 'Golf Course', 'ゴルフ場'),
                labelStyle: TextStyle(color: secondaryTextColor(context)),
                hintText: tr(context, 'Enter course name', 'ゴルフ場名を入力'),
                hintStyle: TextStyle(color: secondaryTextColor(context)),
                filled: true,
                fillColor: fieldFillColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: panelBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: appAccentColor(context),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            key: const Key('coursePickerButton'),
            onPressed: () => _pickCourse(context),
            tooltip: tr(context, 'Select golf course', 'ゴルフ場を選択'),
            icon: const Icon(Icons.add_location_alt),
            color: appAccentColor(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class PastRoundsPage extends StatefulWidget {
  const PastRoundsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<PastRoundsPage> createState() => _PastRoundsPageState();
}

class _PastRoundsPageState extends State<PastRoundsPage> {
  late Future<List<SavedRound>> _roundsFuture;

  @override
  void initState() {
    super.initState();
    _roundsFuture = RoundStorage.loadRounds();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: !widget.embedded,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          widget.embedded ? 28 : 24,
          24,
          widget.embedded ? 110 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedded) ...[
              Text(
                tr(context, 'Rounds', 'ラウンド履歴'),
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  'Completed rounds and rounds in progress',
                  '完了したラウンドと進行中の記録',
                ),
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
            ],
            Expanded(
              child: FutureBuilder<List<SavedRound>>(
                future: _roundsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: appAccentColor(context),
                      ),
                    );
                  }

                  final rounds = snapshot.data ?? [];
                  if (rounds.isEmpty) {
                    return Center(
                      child: Text(
                        tr(
                          context,
                          'No saved rounds yet.',
                          '保存済みラウンドはまだありません。',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryTextColor(context),
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rounds.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final round = rounds[index];
                      final winner = round.ranking.isEmpty
                          ? null
                          : round.ranking.first;

                      return _GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    round.courseName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: primaryTextColor(context),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${round.holesCount}H',
                                      style: TextStyle(
                                        color: appAccentColor(context),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (round.isAutoSaved) ...[
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: appAccentColor(
                                            context,
                                          ).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          tr(context, 'In progress', '進行中'),
                                          style: TextStyle(
                                            color: appAccentColor(context),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatRoundDate(round.date),
                              style: TextStyle(
                                color: secondaryTextColor(context),
                                fontSize: 13,
                              ),
                            ),
                            if (!round.isAutoSaved && winner != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${tr(context, 'Winner', '勝者')}  ${winner.playerName}  ${formatRelativeScore(winner.total)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: appAccentColor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            ...round.ranking
                                .take(3)
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entry.playerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: secondaryTextColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          formatRelativeScore(entry.total),
                                          style: TextStyle(
                                            color: primaryTextColor(context),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }
    return _GlassPage(
      appBar: _liquidAppBar(context, tr(context, 'Past Rounds', '過去のラウンド')),
      body: content,
    );
  }
}

enum _CourseCatalogSource { all, japan, golfzon }

class GolfCoursePickerPage extends StatefulWidget {
  const GolfCoursePickerPage({
    super.key,
    this.embedded = false,
    this.onCourseSelected,
  });

  final bool embedded;
  final ValueChanged<GolfCourse>? onCourseSelected;

  @override
  State<GolfCoursePickerPage> createState() => _GolfCoursePickerPageState();
}

class _GolfCoursePickerPageState extends State<GolfCoursePickerPage> {
  final TextEditingController _searchController = TextEditingController();
  late List<GolfCourse> _courses;
  late _CourseCatalogSource _source;
  String? _selectedRegion;
  String? _selectedPrefecture;

  @override
  void initState() {
    super.initState();
    _source = _debugInitialSource();
    _courses = _filteredCourses();
  }

  _CourseCatalogSource _debugInitialSource() {
    if (const bool.fromEnvironment('dart.vm.product')) {
      return _CourseCatalogSource.all;
    }
    const configuredSource = String.fromEnvironment(
      'BLACKSHELL_INITIAL_COURSE_SOURCE',
    );
    if (configuredSource.isNotEmpty) {
      return switch (configuredSource) {
        'japan' => _CourseCatalogSource.japan,
        'golfzon' => _CourseCatalogSource.golfzon,
        _ => _CourseCatalogSource.all,
      };
    }
    final environmentSource = Platform.environment['BLACKSHELL_COURSE_SOURCE'];
    if (environmentSource != null) {
      return switch (environmentSource) {
        'japan' => _CourseCatalogSource.japan,
        'golfzon' => _CourseCatalogSource.golfzon,
        _ => _CourseCatalogSource.all,
      };
    }
    const prefix = '--blackshell-course-source=';
    for (final argument in Platform.executableArguments) {
      if (!argument.startsWith(prefix)) {
        continue;
      }
      return switch (argument.substring(prefix.length)) {
        'japan' => _CourseCatalogSource.japan,
        'golfzon' => _CourseCatalogSource.golfzon,
        _ => _CourseCatalogSource.all,
      };
    }
    return _CourseCatalogSource.all;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GolfCourse> _filteredCourses() {
    final query = _searchController.text;
    switch (_source) {
      case _CourseCatalogSource.all:
        return [
          ...JapanGolfCourseDirectory.search(query),
          ...GolfzonCourseCatalog.search(query),
        ];
      case _CourseCatalogSource.japan:
        return JapanGolfCourseDirectory.search(
          query,
          region: _selectedRegion,
          prefecture: _selectedPrefecture,
        );
      case _CourseCatalogSource.golfzon:
        return GolfzonCourseCatalog.search(query);
    }
  }

  void _searchCourses(String query) {
    setState(() => _courses = _filteredCourses());
  }

  void _selectSource(_CourseCatalogSource source) {
    setState(() {
      _source = source;
      if (source != _CourseCatalogSource.japan) {
        _selectedRegion = null;
        _selectedPrefecture = null;
      }
      _courses = _filteredCourses();
    });
  }

  void _selectRegion(String? region) {
    setState(() {
      _source = _CourseCatalogSource.japan;
      _selectedRegion = region;
      _selectedPrefecture = null;
      _courses = _filteredCourses();
    });
  }

  void _selectPrefecture(String? prefecture) {
    setState(() {
      _selectedPrefecture = prefecture;
      _courses = _filteredCourses();
    });
  }

  List<String> get _prefectures {
    if (_selectedRegion == null) {
      return const [];
    }
    return JapanGolfCourseDirectory.regions[_selectedRegion] ?? const [];
  }

  String _displayCountry(BuildContext context, String country) {
    if (!isJapanese(context)) {
      return country;
    }
    return switch (country) {
      'Japan' => '日本',
      'United States' => 'アメリカ',
      'United Kingdom' => 'イギリス',
      'Ireland' => 'アイルランド',
      'Virtual' => 'バーチャル',
      _ => country,
    };
  }

  String _golfzonCourseDetails(BuildContext context, GolfCourse course) {
    final details = <String>[
      'GOLFZON',
      _displayCountry(context, course.country),
    ];
    if (course.totalYards case final yards?) {
      details.add(
        '${yards.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')} yd',
      );
    }
    if (course.isVirtual && course.country != 'Virtual') {
      details.add(tr(context, 'Virtual', 'バーチャル'));
    }
    return details.join('  ·  ');
  }

  void _selectCourse(GolfCourse course) {
    final onCourseSelected = widget.onCourseSelected;
    if (onCourseSelected != null) {
      onCourseSelected(course);
      return;
    }
    Navigator.pop(context, course);
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: !widget.embedded,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, widget.embedded ? 28 : 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.embedded) ...[
                    Text(
                      tr(context, 'Courses', 'コース'),
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        'Find a real course or a GOLFZON simulator course.',
                        '実在コースとGOLFZON対応コースから選択できます。',
                      ),
                      style: TextStyle(color: secondaryTextColor(context)),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextField(
                    key: const Key('courseSearchField'),
                    controller: _searchController,
                    autofocus: !widget.embedded,
                    style: TextStyle(color: primaryTextColor(context)),
                    cursorColor: appAccentColor(context),
                    onChanged: _searchCourses,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: secondaryTextColor(context),
                      ),
                      hintText: tr(
                        context,
                        'Search course, prefecture or country',
                        'コース名・都道府県・国名で検索',
                      ),
                      hintStyle: TextStyle(color: secondaryTextColor(context)),
                      filled: true,
                      fillColor: fieldFillColor(context),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: panelBorderColor(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: appAccentColor(context),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _RegionChip(
                          label: tr(context, 'All', 'すべて'),
                          selected: _source == _CourseCatalogSource.all,
                          onTap: () => _selectSource(_CourseCatalogSource.all),
                        ),
                        _RegionChip(
                          label: tr(context, 'Japan', '日本'),
                          selected: _source == _CourseCatalogSource.japan,
                          onTap: () =>
                              _selectSource(_CourseCatalogSource.japan),
                        ),
                        _RegionChip(
                          label: 'GOLFZON',
                          selected: _source == _CourseCatalogSource.golfzon,
                          onTap: () =>
                              _selectSource(_CourseCatalogSource.golfzon),
                        ),
                      ],
                    ),
                  ),
                  if (_source == _CourseCatalogSource.japan) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _RegionChip(
                            label: tr(context, 'All regions', '全地域'),
                            selected: _selectedRegion == null,
                            onTap: () => _selectRegion(null),
                          ),
                          for (final region
                              in JapanGolfCourseDirectory.regions.keys)
                            _RegionChip(
                              label: JapanGolfCourseDirectory.displayRegion(
                                context,
                                region,
                              ),
                              selected: _selectedRegion == region,
                              onTap: () => _selectRegion(region),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_source == _CourseCatalogSource.japan &&
                      _prefectures.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _RegionChip(
                            label: tr(context, 'All prefectures', '全県'),
                            selected: _selectedPrefecture == null,
                            onTap: () => _selectPrefecture(null),
                          ),
                          for (final prefecture in _prefectures)
                            _RegionChip(
                              label: JapanGolfCourseDirectory.displayPrefecture(
                                context,
                                prefecture,
                              ),
                              selected: _selectedPrefecture == prefecture,
                              onTap: () => _selectPrefecture(prefecture),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    switch (_source) {
                      _CourseCatalogSource.golfzon => tr(
                        context,
                        '${_courses.length} courses from the public GOLFZON catalog',
                        'GOLFZON公式公開カタログから${_courses.length}件',
                      ),
                      _CourseCatalogSource.japan => tr(
                        context,
                        '${_courses.length} courses in Japan',
                        '日本のコース ${_courses.length}件',
                      ),
                      _CourseCatalogSource.all => tr(
                        context,
                        '${_courses.length} Japan and GOLFZON courses',
                        '日本・GOLFZONコース ${_courses.length}件',
                      ),
                    },
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_courses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: Text(
                    tr(
                      context,
                      'No matching courses found.',
                      '条件に合うコースがありません。',
                    ),
                    style: TextStyle(color: secondaryTextColor(context)),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: _courses.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  final courseName = course.isGolfzonCourse
                      ? course.name
                      : JapanGolfCourseDirectory.displayCourseName(
                          context,
                          course,
                        );
                  final courseDetails = course.isGolfzonCourse
                      ? _golfzonCourseDetails(context, course)
                      : course.isPracticeRange
                      ? '${JapanGolfCourseDirectory.displayPrefecture(context, course.prefecture)} / ${tr(context, 'Practice Range', 'ゴルフ練習場')}'
                      : JapanGolfCourseDirectory.displayPrefecture(
                          context,
                          course.prefecture,
                        );

                  return _GlassPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        course.isPracticeRange
                            ? Icons.sports_golf
                            : course.isVirtual
                            ? Icons.videogame_asset_rounded
                            : Icons.golf_course,
                        color: appAccentColor(context),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              courseName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryTextColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (course.isGolfzonCourse) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: appAccentColor(
                                  context,
                                ).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: appAccentColor(
                                    context,
                                  ).withValues(alpha: 0.55),
                                ),
                              ),
                              child: MediaQuery.withClampedTextScaling(
                                maxScaleFactor: 1.5,
                                child: Text(
                                  'GOLFZON',
                                  style: TextStyle(
                                    color: appAccentColor(context),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          courseDetails,
                          style: TextStyle(color: secondaryTextColor(context)),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: secondaryTextColor(context),
                      ),
                      onTap: () => _selectCourse(course),
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: widget.embedded ? 112 : 20),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return _GlassPage(
      appBar: _liquidAppBar(context, tr(context, 'Golf Course', 'ゴルフ場')),
      body: content,
    );
  }
}

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 56,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 25),
        color: onPressed == null
            ? secondaryTextColor(context).withValues(alpha: 0.45)
            : Theme.of(context).colorScheme.onPrimary,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(56),
          backgroundColor: onPressed == null
              ? fieldFillColor(context)
              : appAccentColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.greenAccent,
        backgroundColor: fieldFillColor(context),
        labelStyle: TextStyle(
          color: selected ? Colors.black : primaryTextColor(context),
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: selected ? Colors.greenAccent : panelBorderColor(context),
        ),
      ),
    );
  }
}

class _ScoreStatusBadge extends StatelessWidget {
  const _ScoreStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 74, minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 20,
      useNativeGlass: false,
      child: child,
    );
  }
}
