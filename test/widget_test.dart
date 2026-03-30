import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/app/puzzle_lines_app.dart';
import 'package:flutter_application_1/game/application/game_providers.dart';
import 'package:flutter_application_1/game/domain/high_score_repository.dart';

void main() {
  testWidgets('title screen starts a run and shows the board HUD', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          highScoreRepositoryProvider.overrideWithValue(
            InMemoryHighScoreRepository(1200),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Line Pulse'), findsOneWidget);
    expect(find.text('1200'), findsOneWidget);

    await tester.tap(find.text('Start Run'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Score'), findsOneWidget);
    expect(find.text('Rotations'), findsOneWidget);
    expect(find.text('Rotate CCW'), findsOneWidget);
    expect(find.text('Rotate CW'), findsOneWidget);
  });
}
