import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blackshell_golf/main.dart';

void main() {
  testWidgets('creates a room and starts a scorecard', (
    WidgetTester tester,
  ) async {
    await RoundStorage.clear();
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
      find.text('BlackShell Golf Club  /  OUT  /  Par 4  /  385y'),
      findsOneWidget,
    );
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Not set'), findsNWidgets(3));
    expect(find.text('0'), findsWidgets);

    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pump();

    expect(find.text('Total -1'), findsOneWidget);
    expect(find.text('-1'), findsWidgets);
    expect(find.text('Birdie'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.remove).at(1));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).at(1));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.remove).at(2));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).at(2));
    await tester.pump();

    expect(find.text('Total 0'), findsWidgets);
    expect(find.text('Par'), findsNWidgets(3));
    expect(find.text('Draw'), findsWidgets);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hole 2'), findsOneWidget);
    expect(
      find.text('BlackShell Golf Club  /  OUT  /  Par 5  /  520y'),
      findsOneWidget,
    );

    final savedRounds = await RoundStorage.loadRounds();
    expect(savedRounds, hasLength(1));
    expect(savedRounds.first.isAutoSaved, isTrue);
    expect(savedRounds.first.courseName, 'BlackShell Golf Club');
    expect(savedRounds.first.holesCount, 9);
    expect(savedRounds.first.players, contains('Player 1'));
    expect(savedRounds.first.total['Player 1'], 0);

    Navigator.of(
      tester.element(find.byType(ScorePage)),
    ).popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pastRoundsButton')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Past Rounds'), findsOneWidget);
    expect(find.text('BlackShell Golf Club'), findsOneWidget);
  });
}
