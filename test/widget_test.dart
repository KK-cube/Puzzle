import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/app/puzzle_lines_app.dart';
import 'package:flutter_application_1/app/background_music_controller.dart';
import 'package:flutter_application_1/game/application/board_animation_bus.dart';
import 'package:flutter_application_1/game/application/game_providers.dart';
import 'package:flutter_application_1/game/application/game_session_controller.dart';
import 'package:flutter_application_1/game/application/game_session_state.dart';
import 'package:flutter_application_1/game/domain/high_score_repository.dart';
import 'package:flutter_application_1/game/domain/how_to_play_repository.dart';
import 'package:flutter_application_1/game/domain/leaderboard_repository.dart';
import 'package:flutter_application_1/game/domain/music_settings_repository.dart';
import 'package:flutter_application_1/game/domain/player_nickname_repository.dart';
import 'package:flutter_application_1/game/domain/puzzle_engine.dart';
import 'package:flutter_application_1/game/presentation/puzzle_board_stage.dart';
import 'package:flutter_application_1/game/presentation/screens/result_screen.dart';

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
          howToPlayRepositoryProvider.overrideWithValue(
            InMemoryHowToPlayRepository(true),
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
    expect(find.text('累計 3 プレイ'), findsOneWidget);
    expect(find.text('ランキング TOP10'), findsOneWidget);
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
          howToPlayRepositoryProvider.overrideWithValue(
            InMemoryHowToPlayRepository(true),
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
    expect(find.text('FEVER'), findsOneWidget);
    expect(
      find.text('回転は通常時でも使えます。押せる向きでは、必ず 3 マス以上そろう 3x3 回転だけが発動します。'),
      findsOneWidget,
    );

    final boardStageSize = tester.getSize(find.byType(PuzzleBoardStage));
    expect(boardStageSize.width, greaterThan(370));
    expect(boardStageSize.height, boardStageSize.width);
  });

  testWidgets('how-to-play can be reopened from the game screen help button', (
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
            InMemoryHighScoreRepository(),
          ),
          backgroundMusicControllerProvider.overrideWithValue(
            SilentBackgroundMusicController(),
          ),
          leaderboardRepositoryProvider.overrideWithValue(
            InMemoryLeaderboardRepository(),
          ),
          howToPlayRepositoryProvider.overrideWithValue(
            InMemoryHowToPlayRepository(true),
          ),
          playerNicknameRepositoryProvider.overrideWithValue(
            InMemoryPlayerNicknameRepository('Tester'),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ゲーム開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('遊び方'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
  });

  testWidgets('first start shows the how-to-play screen before the run', (
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
            InMemoryHighScoreRepository(),
          ),
          backgroundMusicControllerProvider.overrideWithValue(
            SilentBackgroundMusicController(),
          ),
          leaderboardRepositoryProvider.overrideWithValue(
            InMemoryLeaderboardRepository(),
          ),
          howToPlayRepositoryProvider.overrideWithValue(
            InMemoryHowToPlayRepository(false),
          ),
          playerNicknameRepositoryProvider.overrideWithValue(
            InMemoryPlayerNicknameRepository('Tester'),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ゲーム開始'));
    await tester.pumpAndSettle();

    expect(find.text('遊び方'), findsOneWidget);
    expect(find.text('理解してスタート'), findsOneWidget);

    await tester.tap(find.text('理解してスタート'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('得点'), findsOneWidget);
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

  testWidgets('music setting can be toggled from the title screen', (
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
            InMemoryHighScoreRepository(),
          ),
          backgroundMusicControllerProvider.overrideWithValue(
            SilentBackgroundMusicController(),
          ),
          musicSettingsRepositoryProvider.overrideWithValue(
            InMemoryMusicSettingsRepository(),
          ),
          leaderboardRepositoryProvider.overrideWithValue(
            InMemoryLeaderboardRepository(),
          ),
          howToPlayRepositoryProvider.overrideWithValue(
            InMemoryHowToPlayRepository(true),
          ),
          playerNicknameRepositoryProvider.overrideWithValue(
            InMemoryPlayerNicknameRepository('Tester'),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    expect(find.text('音楽 ON'), findsOneWidget);

    await tester.tap(find.text('音楽 ON'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.text('音楽 OFF'), findsOneWidget);
  });

  testWidgets(
    'result screen scrolls and keeps retry and title actions usable on phone',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 1794);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _ResultGameSessionController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameSessionControllerProvider.overrideWith((ref) => controller),
            backgroundMusicControllerProvider.overrideWithValue(
              SilentBackgroundMusicController(),
            ),
            leaderboardRepositoryProvider.overrideWithValue(
              InMemoryLeaderboardRepository(
                seedSubmissions: [
                  for (var index = 0; index < 10; index += 1)
                    LeaderboardSubmission(
                      playerName: 'Player ${index + 1}',
                      score: 5000 - (index * 150),
                    ),
                ],
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ResultScreen())),
        ),
      );
      await tester.pump();
      await tester.pump();

      final scrollable = find.byType(Scrollable).first;
      await tester.dragUntilVisible(
        find.text('もう一度'),
        scrollable,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('もう一度'));
      await tester.pump();
      expect(controller.state.phase, GamePhase.playing);

      controller.showResult();
      await tester.pump();
      await tester.dragUntilVisible(
        find.text('タイトルへ'),
        scrollable,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('タイトルへ'));
      await tester.pump();
      expect(controller.state.phase, GamePhase.title);
    },
  );
}

class _ResultGameSessionController extends GameSessionController {
  _ResultGameSessionController()
    : super(
        engine: PuzzleEngine(random: Random(7)),
        highScoreRepository: InMemoryHighScoreRepository(1200),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations.instant(),
      ) {
    showResult();
  }

  void showResult() {
    final board = PuzzleEngine(
      random: Random(9),
    ).createInitialBoard(remainingRotations: 0);
    state = state.copyWith(
      phase: GamePhase.result,
      board: board,
      score: 980,
      bestScore: 1200,
      lastRunScore: 980,
      currentChain: 0,
      remainingRotations: 0,
      remainingTimeMs: 0,
      activeHint: null,
      selectedRotationCenter: null,
      inputLocked: false,
      chainBanner: null,
      runEndReason: RunEndReason.timeUp,
    );
  }
}
