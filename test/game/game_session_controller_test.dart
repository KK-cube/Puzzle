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
  test(
    'rotation charges decrement to zero and block further random rotations',
    () async {
      final engine = _FakeRotationEngine();
      final controller = GameSessionController(
        engine: engine,
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        random: Random(1),
        durations: const GameSessionDurations.instant(),
      );
      addTearDown(controller.dispose);

      controller.startNewGame();

      for (
        var expectedRemaining = kInitialRotationCharges - 1;
        expectedRemaining >= 0;
        expectedRemaining--
      ) {
        await controller.rotateSelection(RotationDirection.clockwise);
        expect(controller.state.remainingRotations, expectedRemaining);
      }

      expect(controller.state.selectedRotationCenter, isNull);

      await controller.rotateSelection(RotationDirection.clockwise);
      expect(controller.state.remainingRotations, 0);
      expect(engine.applyMoveCalls, kInitialRotationCharges);
      expect(engine.rotationValidationInputs, [
        for (var value = kInitialRotationCharges; value >= 1; value--) value,
      ]);
    },
  );

  test('invalid rotation does not consume a charge', () async {
    final engine = _FakeRotationEngine(validRotations: 0);
    final controller = GameSessionController(
      engine: engine,
      highScoreRepository: InMemoryHighScoreRepository(),
      animationBus: BoardAnimationBus(),
      random: Random(1),
      durations: const GameSessionDurations.instant(),
    );
    addTearDown(controller.dispose);

    controller.startNewGame();
    await controller.rotateSelection(RotationDirection.clockwise);

    expect(controller.state.remainingRotations, kInitialRotationCharges);
    expect(controller.state.phase, GamePhase.playing);
    expect(engine.applyMoveCalls, 0);
  });

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
    expect(threeTileController.state.remainingTimeMs, 31000);

    final fourTileController = GameSessionController(
      engine: _FakeClearEngine(clearedTiles: 4),
      highScoreRepository: InMemoryHighScoreRepository(),
      animationBus: BoardAnimationBus(),
      durations: const GameSessionDurations.instant(),
    );
    addTearDown(fourTileController.dispose);
    fourTileController.startNewGame();

    await fourTileController.swapRows(0, 1);
    expect(fourTileController.state.remainingTimeMs, 32000);
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
  final List<int> rotationValidationInputs = [];

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
  }) {
    if (move.type == MoveType.rotate3x3) {
      rotationValidationInputs.add(remainingRotations);
      final isValid =
          remainingRotations > 0 &&
          applyMoveCalls < validRotations &&
          move.center != null &&
          move.center!.isRotationCenter;

      return MoveValidation(
        isValid: isValid,
        previewBoard: cloneBoard(board),
        matchedPositions: isValid
            ? {const BoardPosition(0, 0)}
            : const <BoardPosition>{},
        consumesRotation: isValid,
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
  }) {
    applyMoveCalls++;
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
          clearedPositions: {const BoardPosition(0, 0)},
          clearedTileIds: {snapshot[0][0].id},
          scoreDelta: 30,
        ),
      ],
      totalScore: 30,
      totalChains: 1,
      consumesRotation: move.type == MoveType.rotate3x3,
    );
  }

  @override
  List<MoveCommand> findAvailableMoves(
    BoardMatrix board, {
    required int remainingRotations,
  }) {
    return [MoveCommand.swapRows(0, 1)];
  }
}

class _FakeClearEngine extends PuzzleEngine {
  _FakeClearEngine({required this.clearedTiles}) : super(random: Random(2));

  final int clearedTiles;
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
          scoreDelta: 30,
        ),
      ],
      totalScore: 30,
      totalChains: 1,
      consumesRotation: false,
    );
  }

  @override
  List<MoveCommand> findAvailableMoves(
    BoardMatrix board, {
    required int remainingRotations,
  }) {
    return [MoveCommand.swapRows(0, 1)];
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
