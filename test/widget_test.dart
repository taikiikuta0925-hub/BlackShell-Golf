import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blackshell_golf/main.dart';

void main() {
  testWidgets('follows the system language and appearance', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('ja');
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const BlackShellGolfApp());
    await tester.pump();

    expect(find.text('次のラウンドへ'), findsOneWidget);
    final logoContext = tester.element(find.byKey(const Key('homeLogo')));
    expect(Theme.of(logoContext).brightness, Brightness.light);
  });

  testWidgets('creates a room and starts a scorecard', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(RoundStorage.clear);
    addTearDown(RoundStorage.clear);

    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BlackShellGolfApp());

    expect(find.byKey(const Key('homeLogo')), findsOneWidget);

    await tester.tap(find.text('Create Room'));
    await tester.pumpAndSettle();

    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Player 3'), findsOneWidget);

    final addPlayerButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('addPlayerButton')),
    );
    addPlayerButton.onPressed!();
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(5));

    final startScorecardButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('startScorecardButton')),
    );
    startScorecardButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Scorecard'), findsOneWidget);
    expect(find.text('Hole 1'), findsOneWidget);
    expect(
      find.text('BlackShell Golf Club  /  Standard scoring template'),
      findsOneWidget,
    );
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Not set'), findsNWidgets(3));
    expect(find.text('–'), findsNWidgets(3));

    final firstMinusControl = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.remove).first,
            matching: find.byType(IconButton),
          )
          .first,
    );
    final savedAfterFirstScore = await tester.runAsync(() async {
      firstMinusControl.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return RoundStorage.loadRounds();
    });
    await tester.pump();

    expect(find.text('Total -1'), findsOneWidget);
    expect(find.text('-1'), findsWidgets);
    expect(find.text('Birdie'), findsOneWidget);

    expect(savedAfterFirstScore, isNotNull);
    expect(savedAfterFirstScore, hasLength(1));
    expect(savedAfterFirstScore!.first.total['Player 1'], -1);

    IconButton scoreControl(IconData icon, int index) {
      return tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(icon).at(index),
              matching: find.byType(IconButton),
            )
            .first,
      );
    }

    final firstPlusControl = scoreControl(Icons.add, 0);
    final secondMinusControl = scoreControl(Icons.remove, 1);
    final secondPlusControl = scoreControl(Icons.add, 1);
    final thirdMinusControl = scoreControl(Icons.remove, 2);
    final thirdPlusControl = scoreControl(Icons.add, 2);
    await tester.runAsync(() async {
      firstPlusControl.onPressed!();
      secondMinusControl.onPressed!();
      secondPlusControl.onPressed!();
      thirdMinusControl.onPressed!();
      thirdPlusControl.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    });
    await tester.pump();

    expect(find.text('Total 0'), findsWidgets);
    expect(find.text('Par'), findsNWidgets(3));
    expect(find.text('Draw'), findsWidgets);

    final nextHoleControl = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ),
    );
    await tester.runAsync(() async {
      nextHoleControl.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Hole 2'), findsOneWidget);
    expect(
      find.text('BlackShell Golf Club  /  Standard scoring template'),
      findsOneWidget,
    );

    final savedRounds = await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return RoundStorage.loadRounds();
    });
    expect(savedRounds, isNotNull);
    final rounds = savedRounds!;
    expect(rounds, hasLength(1));
    expect(rounds.first.isAutoSaved, isTrue);
    expect(rounds.first.courseName, 'BlackShell Golf Club');
    expect(rounds.first.holesCount, 9);
    expect(rounds.first.players, contains('Player 1'));
    expect(rounds.first.total['Player 1'], 0);
  });

  testWidgets('requires unique player names', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BlackShellGolfApp());
    await tester.tap(find.text('Create Room'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(2), 'Player 1');
    await tester.tap(find.byKey(const Key('startScorecardButton')));
    await tester.pump();

    expect(find.text('Use a different name for each player.'), findsOneWidget);
    expect(find.text('Scorecard'), findsNothing);
  });
}
