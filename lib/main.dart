import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const BlackShellGolfApp());
}

enum AppLanguage { english, japanese }

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
  ThemeMode _themeMode = ThemeMode.dark;
  AppLanguage _language = AppLanguage.english;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      themeMode: _themeMode,
      language: _language,
      setThemeMode: (themeMode) => setState(() => _themeMode = themeMode),
      setLanguage: (language) => setState(() => _language = language),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BlackShell Golf',
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: _themeMode,
        home: const HomePage(),
      ),
    );
  }
}

String tr(BuildContext context, String english, String japanese) {
  return AppSettingsScope.of(context).language == AppLanguage.japanese
      ? japanese
      : english;
}

bool isJapanese(BuildContext context) {
  return AppSettingsScope.of(context).language == AppLanguage.japanese;
}

Color appBackgroundColor(BuildContext context) {
  final settings = AppSettingsScope.of(context);
  return settings.themeMode == ThemeMode.light
      ? const Color(0xFFF4F7F3)
      : const Color(0xFF0D0D0D);
}

bool isLightMode(BuildContext context) {
  return AppSettingsScope.of(context).themeMode == ThemeMode.light;
}

Color primaryTextColor(BuildContext context) {
  return isLightMode(context) ? const Color(0xFF101812) : Colors.white;
}

Color secondaryTextColor(BuildContext context) {
  return isLightMode(context)
      ? const Color(0xFF526156)
      : Colors.white.withValues(alpha: 0.62);
}

Color fieldFillColor(BuildContext context) {
  return isLightMode(context)
      ? const Color(0xFFE5EFE8)
      : Colors.white.withValues(alpha: 0.04);
}

Color panelFillColor(BuildContext context) {
  return isLightMode(context)
      ? Colors.white.withValues(alpha: 0.72)
      : Colors.white.withValues(alpha: 0.07);
}

Color panelBorderColor(BuildContext context) {
  return isLightMode(context)
      ? const Color(0xFFB8D3C2)
      : Colors.white.withValues(alpha: 0.12);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackgroundColor(context),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                key: const Key('settingsButton'),
                tooltip: tr(context, 'Settings', '設定'),
                onPressed: () => _showSettingsSheet(context),
                icon: const Icon(Icons.settings),
                color: Colors.greenAccent,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppSettingsScope.of(context).themeMode == ThemeMode.light
                        ? 'assets/logolight.png'
                        : 'assets/logo.png',
                    key: const Key('homeLogo'),
                    width: 520,
                    fit: BoxFit.contain,
                    semanticLabel: 'BlackShell Golf',
                    errorBuilder: (context, error, stackTrace) {
                      return Text(
                        'BlackShell Golf',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    tr(context, 'Live Multiplayer Golf Scoring', 'ライブ対応ゴルフスコア'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),

                  const SizedBox(height: 50),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlayerSetupPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                    ),
                    child: Text(
                      tr(context, 'Create Room', 'ルーム作成'),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),

                  const SizedBox(height: 20),

                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr(context, 'Join Room Coming Soon', 'ルーム参加は準備中です'),
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                    ),
                    child: Text(
                      tr(context, 'Join Room', 'ルーム参加'),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    key: const Key('pastRoundsButton'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PastRoundsPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                    child: Text(
                      tr(context, 'Past Rounds', '過去のラウンド'),
                      style: const TextStyle(fontSize: 18),
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

  void _showSettingsSheet(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                segments: const [
                  ButtonSegment(value: AppLanguage.english, label: Text('EN')),
                  ButtonSegment(value: AppLanguage.japanese, label: Text('JP')),
                ],
                selected: {settings.language},
                onSelectionChanged: (selection) {
                  settings.setLanguage(selection.first);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class PlayerSetupPage extends StatefulWidget {
  const PlayerSetupPage({super.key});

  @override
  State<PlayerSetupPage> createState() => _PlayerSetupPageState();
}

class _PlayerSetupPageState extends State<PlayerSetupPage> {
  static const int _practiceRangeMaxPlayers = 2;

  int _roundHoles = 9;
  GolfCourse? _selectedCourse;

  final TextEditingController _courseController = TextEditingController(
    text: 'BlackShell Golf Club',
  );

  final List<TextEditingController> _playerControllers = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
    TextEditingController(text: 'Player 3'),
  ];

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
    return Scaffold(
      backgroundColor: appBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(tr(context, 'Players', 'プレイヤー')),
      ),
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
                            foregroundColor: Colors.greenAccent,
                            child: Text('${index + 1}'),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _playerControllers[index],
                              style: TextStyle(
                                color: primaryTextColor(context),
                              ),
                              cursorColor: Colors.greenAccent,
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
                                  borderSide: const BorderSide(
                                    color: Colors.greenAccent,
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
                      foregroundColor: isLightMode(context)
                          ? const Color(0xFF07995D)
                          : Colors.greenAccent,
                      disabledForegroundColor: secondaryTextColor(context),
                      side: BorderSide(
                        color: canAddPlayer
                            ? (isLightMode(context)
                                  ? const Color(0xFF07995D)
                                  : Colors.greenAccent)
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
    return displayCourseNameForLanguage(
      AppSettingsScope.of(context).language,
      course,
    );
  }

  static String displayCourseNameForLanguage(
    AppLanguage language,
    GolfCourse course,
  ) {
    if (language == AppLanguage.japanese) {
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
  static File get _file {
    final appData = Platform.environment['APPDATA'];
    final directory = appData == null || appData.isEmpty
        ? Directory(
            '${Directory.systemTemp.path}${Platform.pathSeparator}blackshell_golf',
          )
        : Directory('$appData${Platform.pathSeparator}BlackShellGolf');

    return File('${directory.path}${Platform.pathSeparator}rounds.json');
  }

  static Future<List<SavedRound>> loadRounds() async {
    final file = _file;
    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }

    final jsonList = jsonDecode(content) as List<dynamic>;
    return jsonList
        .map((entry) => SavedRound.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveRound(SavedRound round) async {
    final rounds = await loadRounds();
    final updatedRounds = [round, ...rounds];
    final file = _file;
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
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        updatedRounds.map((savedRound) => savedRound.toJson()).toList(),
      ),
    );
  }

  static Future<void> clear() async {
    final file = _file;
    if (await file.exists()) {
      await file.delete();
    }
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
  int _currentHole = 0;

  @override
  void initState() {
    super.initState();
    _players = widget.players
        .map((name) => Player(name: name, holes: widget.holes))
        .toList();
    _holes = _buildHoles();
    _autoSaveId = 'autosave-${DateTime.now().millisecondsSinceEpoch}';
  }

  Hole get _hole => _holes[_currentHole];

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
    return switch (status) {
      'Albatross' => Colors.cyanAccent,
      'Eagle' => const Color(0xFFFFD166),
      'Birdie' => const Color(0xFF7CFFCB),
      'Par' => isLightMode(context) ? const Color(0xFF4F5D54) : Colors.white54,
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
      player.scores[_currentHole] = 0;
      player.entered[_currentHole] = true;
    });
  }

  void _changeScore(Player player, int delta) {
    final nextScore = player.scores[_currentHole] + delta;
    if (nextScore < -9 || nextScore > 9) {
      return;
    }

    setState(() {
      player.scores[_currentHole] = nextScore;
      player.entered[_currentHole] = true;
    });
  }

  void _goToPreviousHole() {
    if (_currentHole == 0) {
      return;
    }

    setState(() {
      _currentHole--;
    });
    _autoSaveRound();
  }

  void _goToNextHole() {
    if (!_isCurrentHoleComplete) {
      _showIncompleteHoleMessage();
      return;
    }

    _autoSaveRound();

    if (_isLastHole) {
      _showFinalRanking();
      return;
    }

    setState(() {
      _currentHole++;
    });
  }

  void _showFinalRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinalRankingPage(
          courseName: JapanGolfCourseDirectory.displayCourseName(
            context,
            widget.course,
          ),
          players: _ranking,
        ),
      ),
    );
  }

  SavedRound _buildSavedRound({required bool isAutoSaved}) {
    return SavedRound(
      id: isAutoSaved ? _autoSaveId : DateTime.now().toIso8601String(),
      date: DateTime.now(),
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

  Future<void> _autoSaveRound() async {
    await RoundStorage.upsertAutoSave(_buildSavedRound(isAutoSaved: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(tr(context, 'Scorecard', 'スコアカード')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hole ${_hole.number}',
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _HoleButton(
                    icon: Icons.chevron_left,
                    onPressed: _currentHole == 0 ? null : _goToPreviousHole,
                  ),
                  const SizedBox(width: 8),
                  _HoleButton(
                    icon: Icons.chevron_right,
                    onPressed: _currentHole == widget.holes - 1
                        ? null
                        : _goToNextHole,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _holeSubtitle(),
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.separated(
                  itemCount: _players.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final player = _players[index];
                    final score = player.scores[_currentHole];
                    final isEntered = player.entered[_currentHole];
                    final status = isEntered ? _scoreStatus(score) : 'Not set';
                    final statusColor = _scoreStatusColor(status);

                    return _GlassPanel(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.name,
                                  style: TextStyle(
                                    color: primaryTextColor(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${tr(context, 'Total', '合計')} ${formatRelativeScore(player.total)}',
                                  style: TextStyle(
                                    color: secondaryTextColor(context),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ScoreButton(
                            icon: Icons.remove,
                            onPressed: () => _changeScore(player, -1),
                          ),
                          SizedBox(
                            width: 64,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _markPar(player),
                              child: Text(
                                formatRelativeScore(score),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isEntered
                                      ? Colors.greenAccent
                                      : secondaryTextColor(context),
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          _ScoreStatusBadge(
                            label: _scoreStatusLabel(context, status),
                            color: statusColor,
                          ),
                          const SizedBox(width: 10),
                          _ScoreButton(
                            icon: Icons.add,
                            onPressed: () => _changeScore(player, 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(context, 'Ranking', 'ランキング'),
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._ranking.indexed.map((entry) {
                      final player = entry.$2;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(
                                _rankLabel(player),
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                player.name,
                                style: TextStyle(
                                  color: secondaryTextColor(context),
                                ),
                              ),
                            ),
                            Text(
                              formatRelativeScore(player.total),
                              style: TextStyle(
                                color: primaryTextColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const Key('nextHoleButton'),
                onPressed: _goToNextHole,
                icon: Icon(
                  _isLastHole ? Icons.emoji_events : Icons.arrow_forward,
                ),
                label: Text(
                  _isLastHole
                      ? tr(context, 'Final Ranking', '最終ランキング')
                      : tr(context, 'Next Hole', '次のホールへ'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
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

class _HoleButton extends StatelessWidget {
  const _HoleButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: onPressed == null ? Colors.white24 : Colors.greenAccent,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}

class FinalRankingPage extends StatelessWidget {
  const FinalRankingPage({
    super.key,
    required this.courseName,
    required this.players,
  });

  final String courseName;
  final List<Player> players;

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
    return Scaffold(
      backgroundColor: appBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(tr(context, 'Final Ranking', '最終ランキング')),
      ),
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
                              style: const TextStyle(
                                color: Colors.greenAccent,
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
                  foregroundColor: isLightMode(context)
                      ? const Color(0xFF07995D)
                      : Colors.greenAccent,
                  side: BorderSide(
                    color: isLightMode(context)
                        ? const Color(0xFF07995D)
                        : Colors.greenAccent,
                  ),
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
          const Icon(Icons.location_on, color: Colors.greenAccent),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              key: const Key('golfCourseField'),
              controller: controller,
              style: TextStyle(color: primaryTextColor(context)),
              cursorColor: Colors.greenAccent,
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
                  borderSide: const BorderSide(
                    color: Colors.greenAccent,
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
            color: Colors.greenAccent,
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
  const PastRoundsPage({super.key});

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
    return Scaffold(
      backgroundColor: appBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(tr(context, 'Past Rounds', '過去のラウンド')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<List<SavedRound>>(
            future: _roundsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                );
              }

              final rounds = snapshot.data ?? [];
              if (rounds.isEmpty) {
                return Center(
                  child: Text(
                    tr(context, 'No saved rounds yet.', '保存済みラウンドはまだありません。'),
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                );
              }

              return ListView.separated(
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
                          children: [
                            Expanded(
                              child: Text(
                                round.courseName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${round.holesCount}H',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatRoundDate(round.date),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (winner != null)
                          Text(
                            '${tr(context, 'Winner', '勝者')}  ${winner.playerName}  ${formatRelativeScore(winner.total)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatRelativeScore(entry.total),
                                      style: const TextStyle(
                                        color: Colors.white,
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
      ),
    );
  }
}

class GolfCoursePickerPage extends StatefulWidget {
  const GolfCoursePickerPage({super.key});

  @override
  State<GolfCoursePickerPage> createState() => _GolfCoursePickerPageState();
}

class _GolfCoursePickerPageState extends State<GolfCoursePickerPage> {
  final TextEditingController _searchController = TextEditingController();
  List<GolfCourse> _courses = JapanGolfCourseDirectory.courses;
  String? _selectedRegion;
  String? _selectedPrefecture;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchCourses(String query) {
    setState(() {
      _courses = JapanGolfCourseDirectory.search(
        query,
        region: _selectedRegion,
        prefecture: _selectedPrefecture,
      );
    });
  }

  void _selectRegion(String? region) {
    setState(() {
      _selectedRegion = region;
      _selectedPrefecture = null;
      _courses = JapanGolfCourseDirectory.search(
        _searchController.text,
        region: _selectedRegion,
      );
    });
  }

  void _selectPrefecture(String? prefecture) {
    setState(() {
      _selectedPrefecture = prefecture;
      _courses = JapanGolfCourseDirectory.search(
        _searchController.text,
        region: _selectedRegion,
        prefecture: _selectedPrefecture,
      );
    });
  }

  List<String> get _prefectures {
    if (_selectedRegion == null) {
      return const [];
    }
    return JapanGolfCourseDirectory.regions[_selectedRegion] ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(tr(context, 'Golf Course', 'ゴルフ場')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('courseSearchField'),
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: primaryTextColor(context)),
                cursorColor: Colors.greenAccent,
                onChanged: _searchCourses,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    color: secondaryTextColor(context),
                  ),
                  hintText: tr(
                    context,
                    'Search by course or prefecture',
                    'ゴルフ場名・都道府県で検索',
                  ),
                  hintStyle: TextStyle(color: secondaryTextColor(context)),
                  filled: true,
                  fillColor: fieldFillColor(context),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: panelBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.greenAccent,
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
                      selected: _selectedRegion == null,
                      onTap: () => _selectRegion(null),
                    ),
                    for (final region in JapanGolfCourseDirectory.regions.keys)
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
              if (_prefectures.isNotEmpty) ...[
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
                tr(
                  context,
                  '${_courses.length} courses shown. Full Japan sync can be connected to Rakuten GORA API later.',
                  '${_courses.length}件表示中。開発中のためホールごとのヤード数はずれることがあります。',
                ),
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _courses.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final course = _courses[index];

                    return _GlassPanel(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          course.isPracticeRange
                              ? Icons.sports_golf
                              : Icons.golf_course,
                          color: Colors.greenAccent,
                        ),
                        title: Text(
                          JapanGolfCourseDirectory.displayCourseName(
                            context,
                            course,
                          ),
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          course.isPracticeRange
                              ? '${JapanGolfCourseDirectory.displayPrefecture(context, course.prefecture)} / ${tr(context, 'Practice Range', 'ゴルフ練習場')}'
                              : JapanGolfCourseDirectory.displayPrefecture(
                                  context,
                                  course.prefecture,
                                ),
                          style: TextStyle(color: secondaryTextColor(context)),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                        ),
                        onTap: () => Navigator.pop(context, course),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: onPressed == null ? Colors.white24 : Colors.black,
      style: IconButton.styleFrom(
        backgroundColor: onPressed == null
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.greenAccent,
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
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: panelFillColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: panelBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
