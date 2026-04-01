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
import 'package:flutter_application_1/game/domain/models.dart';
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
    expect(find.text('残り回転'), findsNothing);
    expect(find.text('左回転'), findsNothing);
    expect(find.text('右回転'), findsNothing);
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

    expect(find.text('左回転'), findsNothing);
    expect(find.text('右回転'), findsNothing);
    expect(find.text('回転'), findsNothing);
    expect(find.text('FEVER'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('fever_button'))).width,
      lessThan(100),
    );
    expect(find.text('牌を横に動かすと列、縦に動かすと行をスライドできます。'), findsOneWidget);

    final boardStageSize = tester.getSize(find.byType(PuzzleBoardStage));
    expect(boardStageSize.width, greaterThan(370));
    expect(boardStageSize.height, boardStageSize.width);
  });

  testWidgets('help button pauses the game and reopens how-to-play', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
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
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ゲーム開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final pausedTime = container
        .read(gameSessionControllerProvider)
        .remainingTimeMs;

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('遊び方'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
    expect(container.read(gameSessionControllerProvider).isPaused, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(
      container.read(gameSessionControllerProvider).remainingTimeMs,
      pausedTime,
    );

    await tester.tap(find.text('閉じる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(gameSessionControllerProvider).isPaused, isFalse);

    await tester.pump(const Duration(seconds: 1));
    expect(
      container.read(gameSessionControllerProvider).remainingTimeMs,
      lessThan(pausedTime),
    );

    container.read(gameSessionControllerProvider.notifier).returnToTitle();
    await tester.pump();
  });

  testWidgets('fever start shows a temporary announcement banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _FeverAnnouncementGameSessionController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameSessionControllerProvider.overrideWith((ref) => controller),
          backgroundMusicControllerProvider.overrideWithValue(
            SilentBackgroundMusicController(),
          ),
        ],
        child: const PuzzleLinesApp(),
      ),
    );
    await tester.pump();

    expect(find.text('FEVER TIME'), findsNothing);

    controller.triggerFever();
    await tester.pump();
    await tester.pump();

    expect(find.text('FEVER TIME'), findsOneWidget);
    expect(find.text('今なら どこを動かしても そろう!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FEVER TIME'), findsNothing);
  });

  testWidgets(
    'start begins immediately without showing the how-to-play screen',
    (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('得点'), findsOneWidget);
      expect(find.text('遊び方'), findsNothing);
    },
  );

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

class _FeverAnnouncementGameSessionController extends GameSessionController {
  _FeverAnnouncementGameSessionController()
    : super(
        engine: PuzzleEngine(random: Random(11)),
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations.instant(),
      ) {
    final board = PuzzleEngine(
      random: Random(12),
    ).createInitialBoard(remainingRotations: kInitialRotationCharges);
    state = state.copyWith(
      phase: GamePhase.playing,
      board: board,
      score: 0,
      bestScore: 0,
      lastRunScore: 0,
      currentChain: 0,
      remainingRotations: kInitialRotationCharges,
      remainingTimeMs: kInitialRunTimeMs,
      feverGauge: 0,
      feverChargeGoal: kInitialFeverChargeGoal,
      feverRemainingMs: 0,
      activeHint: null,
      selectedRotationCenter: null,
      isPaused: false,
      inputLocked: false,
      chainBanner: null,
      runEndReason: null,
    );
  }

  void triggerFever() {
    state = state.copyWith(feverRemainingMs: kFeverDurationMs);
  }
}
