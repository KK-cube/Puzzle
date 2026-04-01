import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game/application/board_animation_bus.dart';
import 'package:flutter_application_1/game/application/game_session_controller.dart';
import 'package:flutter_application_1/game/application/game_session_state.dart';
import 'package:flutter_application_1/game/domain/high_score_repository.dart';
import 'package:flutter_application_1/game/domain/models.dart';
import 'package:flutter_application_1/game/domain/puzzle_engine.dart';

void main() {
  test('runs start with player rotations disabled', () async {
    final engine = _FakeRotationEngine();
    final controller = GameSessionController(
      engine: engine,
      highScoreRepository: InMemoryHighScoreRepository(),
      animationBus: BoardAnimationBus(),
      durations: const GameSessionDurations.instant(),
    );
    addTearDown(controller.dispose);

    controller.startNewGame();

    expect(controller.state.remainingRotations, 0);

    await controller.rotateSelection(RotationDirection.clockwise);

    expect(controller.state.remainingRotations, 0);
    expect(controller.state.phase, GamePhase.playing);
    expect(controller.state.selectedRotationCenter, isNull);
    expect(engine.applyMoveCalls, 0);
  });

  test(
    'fever unlock cost steps up by 500 points and lasts for 7.5 seconds',
    () {
      fakeAsync((async) {
        final controller = GameSessionController(
          engine: _FakeClearEngine(clearedTiles: 3, scoreDelta: 250),
          highScoreRepository: InMemoryHighScoreRepository(),
          animationBus: BoardAnimationBus(),
          durations: const GameSessionDurations.instant(),
        );
        addTearDown(controller.dispose);

        controller.startNewGame();
        async.flushMicrotasks();

        expect(controller.state.feverChargeGoal, kInitialFeverChargeGoal);

        for (var index = 0; index < 2; index++) {
          unawaited(controller.swapRows(0, 1));
          async.elapse(Duration.zero);
          async.flushMicrotasks();
        }

        expect(controller.state.feverGauge, 500);
        expect(controller.state.canActivateFever, isTrue);

        controller.activateFever();
        expect(controller.state.isFeverActive, isTrue);
        expect(controller.state.feverGauge, 0);
        expect(
          controller.state.feverChargeGoal,
          kInitialFeverChargeGoal + kFeverChargeGoalStep,
        );
        expect(controller.state.feverRemainingMs, kFeverDurationMs);

        async.elapse(const Duration(milliseconds: 7400));
        async.flushMicrotasks();
        expect(controller.state.isFeverActive, isTrue);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(controller.state.isFeverActive, isFalse);
        expect(controller.state.feverRemainingMs, 0);

        for (var index = 0; index < 4; index++) {
          unawaited(controller.swapRows(0, 1));
          async.elapse(Duration.zero);
          async.flushMicrotasks();
        }

        expect(controller.state.feverGauge, 1000);
        expect(controller.state.feverChargeGoal, 1000);
        expect(controller.state.canActivateFever, isTrue);
      });
    },
  );

  test('run starts at 30 seconds and ends when the timer reaches zero', () {
    fakeAsync((async) {
      final controller = GameSessionController(
        engine: _FakeClearEngine(clearedTiles: 3),
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations.instant(),
      );
      addTearDown(controller.dispose);

      controller.startNewGame();
      async.flushMicrotasks();

      expect(controller.state.remainingTimeMs, kInitialRunTimeMs);

      async.elapse(const Duration(seconds: 1));
      expect(controller.state.remainingTimeMs, 29000);

      async.elapse(const Duration(seconds: 29));
      async.flushMicrotasks();

      expect(controller.state.remainingTimeMs, 0);
      expect(controller.state.phase, GamePhase.result);
      expect(controller.state.runEndReason, RunEndReason.timeUp);
    });
  });

  test('pausing the game stops the timer until it is resumed', () {
    fakeAsync((async) {
      final controller = GameSessionController(
        engine: _FakeClearEngine(clearedTiles: 3),
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations.instant(),
      );
      addTearDown(controller.dispose);

      controller.startNewGame();
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 1));
      expect(controller.state.remainingTimeMs, 29000);

      expect(controller.pauseGame(), isTrue);
      expect(controller.state.isPaused, isTrue);

      async.elapse(const Duration(seconds: 5));
      expect(controller.state.remainingTimeMs, 29000);

      controller.resumeGame();
      expect(controller.state.isPaused, isFalse);

      async.elapse(const Duration(seconds: 1));
      expect(controller.state.remainingTimeMs, 28000);
    });
  });

  test('clearing three and four tiles grants time bonuses', () async {
    final threeTileController = GameSessionController(
      engine: _FakeClearEngine(clearedTiles: 3),
      highScoreRepository: InMemoryHighScoreRepository(),
      animationBus: BoardAnimationBus(),
      durations: const GameSessionDurations.instant(),
    );
    addTearDown(threeTileController.dispose);
    threeTileController.startNewGame();

    await threeTileController.swapRows(0, 1);
    expect(threeTileController.state.remainingTimeMs, 30500);

    final fourTileController = GameSessionController(
      engine: _FakeClearEngine(clearedTiles: 4),
      highScoreRepository: InMemoryHighScoreRepository(),
      animationBus: BoardAnimationBus(),
      durations: const GameSessionDurations.instant(),
    );
    addTearDown(fourTileController.dispose);
    fourTileController.startNewGame();

    await fourTileController.swapRows(0, 1);
    expect(fourTileController.state.remainingTimeMs, 31000);
  });

  test('shows a hint after 5 seconds without clearing', () {
    fakeAsync((async) {
      final controller = GameSessionController(
        engine: _FakeClearEngine(clearedTiles: 3),
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations.instant(),
      );
      addTearDown(controller.dispose);

      controller.startNewGame();
      async.elapse(const Duration(seconds: 5));

      expect(controller.state.activeHint, isNotNull);
      expect(controller.state.activeHint!.move.type, MoveType.swapRow);
      expect(controller.state.activeHint!.move.primaryIndex, 0);
      expect(controller.state.activeHint!.move.secondaryIndex, 1);
    });
  });

  test('interaction clears the active hint and resets the hint timer', () {
    fakeAsync((async) {
      final controller = GameSessionController(
        engine: _FakeClearEngine(clearedTiles: 3),
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations.instant(),
      );
      addTearDown(controller.dispose);

      controller.startNewGame();
      async.elapse(const Duration(seconds: 5));
      expect(controller.state.activeHint, isNotNull);

      controller.noteInteraction();
      expect(controller.state.activeHint, isNull);

      async.elapse(const Duration(seconds: 4));
      expect(controller.state.activeHint, isNull);

      async.elapse(const Duration(seconds: 1));
      expect(controller.state.activeHint, isNotNull);
    });
  });

  test('no-move game over pauses on the board before the result screen', () {
    fakeAsync((async) {
      final controller = GameSessionController(
        engine: _NoMoreMovesAfterClearEngine(clearedTiles: 3),
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations(
          move: Duration.zero,
          revert: Duration.zero,
          clear: Duration.zero,
          settle: Duration.zero,
          gameOverHold: Duration(milliseconds: 900),
          chainBannerHold: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);

      controller.startNewGame();
      async.flushMicrotasks();

      unawaited(controller.swapRows(0, 1));
      async.elapse(Duration.zero);
      async.flushMicrotasks();

      expect(controller.state.phase, GamePhase.resolving);
      expect(controller.state.runEndReason, RunEndReason.noMoreMoves);

      async.elapse(const Duration(milliseconds: 850));
      async.flushMicrotasks();
      expect(controller.state.phase, GamePhase.resolving);

      async.elapse(const Duration(milliseconds: 50));
      async.flushMicrotasks();
      expect(controller.state.phase, GamePhase.result);
    });
  });
}

class _FakeRotationEngine extends PuzzleEngine {
  _FakeRotationEngine({this.validRotations = kInitialRotationCharges})
    : super(random: Random(1));

  final int validRotations;
  final BoardMatrix _board = _boardFromRows(const [
    'ABCDEAB',
    'BCDEABC',
    'CDEABCD',
    'DEABCDE',
    'EABCDEA',
    'ABCDEAB',
    'BCDEABC',
  ]);

  int applyMoveCalls = 0;

  @override
  BoardMatrix createInitialBoard({
    int remainingRotations = kInitialRotationCharges,
  }) {
    return cloneBoard(_board);
  }

  @override
  MoveValidation validateMove(
    BoardMatrix board,
    MoveCommand move, {
    required int remainingRotations,
    bool feverActive = false,
  }) {
    if (move.type == MoveType.rotate3x3) {
      final canRotate =
          remainingRotations > 0 &&
          move.center != null &&
          move.center!.isRotationCenter;
      final createsMatch = applyMoveCalls < validRotations;

      return MoveValidation(
        isValid: canRotate && createsMatch,
        previewBoard: cloneBoard(board),
        matchedPositions: createsMatch
            ? {const BoardPosition(0, 0)}
            : const <BoardPosition>{},
        consumesRotation: canRotate && createsMatch,
      );
    }

    return MoveValidation(
      isValid: true,
      previewBoard: cloneBoard(board),
      matchedPositions: {const BoardPosition(0, 0)},
      consumesRotation: false,
    );
  }

  @override
  MoveApplication applyMove(
    BoardMatrix board,
    MoveCommand move, {
    required int remainingRotations,
    bool feverActive = false,
  }) {
    applyMoveCalls++;
    final snapshot = cloneBoard(board);
    final createsMatch =
        move.type != MoveType.rotate3x3 || applyMoveCalls <= validRotations;
    return MoveApplication(
      isValid: true,
      previewBoard: snapshot,
      finalBoard: snapshot,
      waves: createsMatch
          ? [
              ResolveWave(
                chainIndex: 1,
                boardBeforeClear: snapshot,
                boardAfterRefill: snapshot,
                clearedPositions: {const BoardPosition(0, 0)},
                clearedTileIds: {snapshot[0][0].id},
                scoreDelta: 30,
              ),
            ]
          : const [],
      totalScore: createsMatch ? 30 : 0,
      totalChains: createsMatch ? 1 : 0,
      consumesRotation: move.type == MoveType.rotate3x3,
    );
  }

  @override
  List<MoveCommand> findAvailableSwapMoves(
    BoardMatrix board, {
    bool feverActive = false,
  }) {
    return [MoveCommand.swapRows(0, 1)];
  }
}

class _FakeClearEngine extends PuzzleEngine {
  _FakeClearEngine({required this.clearedTiles, this.scoreDelta = 30})
    : super(random: Random(2));

  final int clearedTiles;
  final int scoreDelta;
  final BoardMatrix _board = _boardFromRows(const [
    'ABCDEAB',
    'BCDEABC',
    'CDEABCD',
    'DEABCDE',
    'EABCDEA',
    'ABCDEAB',
    'BCDEABC',
  ]);

  @override
  BoardMatrix createInitialBoard({
    int remainingRotations = kInitialRotationCharges,
  }) {
    return cloneBoard(_board);
  }

  @override
  MoveValidation validateMove(
    BoardMatrix board,
    MoveCommand move, {
    required int remainingRotations,
    bool feverActive = false,
  }) {
    return MoveValidation(
      isValid: true,
      previewBoard: cloneBoard(board),
      matchedPositions: {
        for (var index = 0; index < clearedTiles; index++)
          BoardPosition(0, index),
      },
      consumesRotation: false,
    );
  }

  @override
  MoveApplication applyMove(
    BoardMatrix board,
    MoveCommand move, {
    required int remainingRotations,
    bool feverActive = false,
  }) {
    final snapshot = cloneBoard(board);
    return MoveApplication(
      isValid: true,
      previewBoard: snapshot,
      finalBoard: snapshot,
      waves: [
        ResolveWave(
          chainIndex: 1,
          boardBeforeClear: snapshot,
          boardAfterRefill: snapshot,
          clearedPositions: {
            for (var index = 0; index < clearedTiles; index++)
              BoardPosition(0, index),
          },
          clearedTileIds: {
            for (var index = 0; index < clearedTiles; index++)
              snapshot[0][index].id,
          },
          scoreDelta: scoreDelta,
        ),
      ],
      totalScore: scoreDelta,
      totalChains: 1,
      consumesRotation: false,
    );
  }

  @override
  List<MoveCommand> findAvailableMoves(
    BoardMatrix board, {
    required int remainingRotations,
    bool feverActive = false,
  }) {
    return [MoveCommand.swapRows(0, 1)];
  }
}

class _NoMoreMovesAfterClearEngine extends _FakeClearEngine {
  _NoMoreMovesAfterClearEngine({required super.clearedTiles});

  @override
  List<MoveCommand> findAvailableMoves(
    BoardMatrix board, {
    required int remainingRotations,
    bool feverActive = false,
  }) {
    return const [];
  }
}

BoardMatrix _boardFromRows(List<String> rows) {
  final tileMap = {
    'A': TileColor.coral,
    'B': TileColor.teal,
    'C': TileColor.gold,
    'D': TileColor.violet,
    'E': TileColor.mint,
  };
  var id = 1;

  return [
    for (final row in rows)
      [
        for (final symbol in row.split(''))
          Tile(id: id++, color: tileMap[symbol]!),
      ],
  ];
}
