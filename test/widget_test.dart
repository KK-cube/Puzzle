import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/app/puzzle_lines_app.dart';
import 'package:flutter_application_1/app/background_music_controller.dart';
import 'package:flutter_application_1/game/application/game_providers.dart';
import 'package:flutter_application_1/game/domain/high_score_repository.dart';
import 'package:flutter_application_1/game/domain/leaderboard_repository.dart';
import 'package:flutter_application_1/game/domain/player_nickname_repository.dart';
import 'package:flutter_application_1/game/presentation/puzzle_board_stage.dart';

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
          backgroundMusicControllerProvider.overrideWithValue(
            SilentBackgroundMusicController(),
          ),
          leaderboardRepositoryProvider.overrideWithValue(
            InMemoryLeaderboardRepository(
              seedScores: {'Alice': 2401, 'Bob': 1800, 'Cara': 1300},
            ),
          ),
          playerNicknameRepositoryProvider.overrideWithValue(
            InMemoryPlayerNicknameRepository('Tester'),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    expect(find.text('ラインパルス'), findsOneWidget);
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('これまでに 3人 がプレイ'), findsOneWidget);
    expect(find.text('ランキング TOP3'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    await tester.ensureVisible(find.text('ゲーム開始'));
    await tester.tap(find.text('ゲーム開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('得点'), findsOneWidget);
    expect(find.text('残り回転'), findsOneWidget);
    expect(find.text('左回転'), findsOneWidget);
    expect(find.text('右回転'), findsOneWidget);
  });

  testWidgets('game screen remains usable on a phone-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          highScoreRepositoryProvider.overrideWithValue(
            InMemoryHighScoreRepository(),
          ),
          backgroundMusicControllerProvider.overrideWithValue(
            SilentBackgroundMusicController(),
          ),
          leaderboardRepositoryProvider.overrideWithValue(
            InMemoryLeaderboardRepository(
              seedScores: {'Alice': 2401, 'Bob': 1800, 'Cara': 1300},
            ),
          ),
          playerNicknameRepositoryProvider.overrideWithValue(
            InMemoryPlayerNicknameRepository('Tester'),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('ゲーム開始'));
    await tester.tap(find.text('ゲーム開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('左回転'), findsOneWidget);
    expect(find.text('右回転'), findsOneWidget);
    expect(find.text('回転'), findsOneWidget);
    expect(find.text('牌を横に動かすと列、縦に動かすと行をスライドできます。'), findsOneWidget);

    final boardStageSize = tester.getSize(find.byType(PuzzleBoardStage));
    expect(boardStageSize.width, greaterThan(370));
    expect(boardStageSize.height, boardStageSize.width);
  });

  testWidgets('start prompts for nickname when none is saved', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          highScoreRepositoryProvider.overrideWithValue(
            InMemoryHighScoreRepository(),
          ),
          backgroundMusicControllerProvider.overrideWithValue(
            SilentBackgroundMusicController(),
          ),
          leaderboardRepositoryProvider.overrideWithValue(
            InMemoryLeaderboardRepository(),
          ),
          playerNicknameRepositoryProvider.overrideWithValue(
            InMemoryPlayerNicknameRepository(),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('名前を決めて開始'));
    await tester.pumpAndSettle();

    expect(find.text('ニックネームを入力'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });
}
