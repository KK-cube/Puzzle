import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game/application/board_animation_bus.dart';
import 'package:flutter_application_1/game/application/game_session_controller.dart';
import 'package:flutter_application_1/game/application/game_session_state.dart';
import 'package:flutter_application_1/game/domain/high_score_repository.dart';
import 'package:flutter_application_1/game/domain/models.dart';
import 'package:flutter_application_1/game/domain/puzzle_engine.dart';

void main() {
  test(
    'rotation charges decrement to zero and block further selection',
    () async {
      final engine = _FakeRotationEngine();
      final controller = GameSessionController(
        engine: engine,
        highScoreRepository: InMemoryHighScoreRepository(),
        animationBus: BoardAnimationBus(),
        durations: const GameSessionDurations.instant(),
      );

      controller.startNewGame();

      for (
        var expectedRemaining = 2;
        expectedRemaining >= 0;
        expectedRemaining--
      ) {
        controller.selectRotationCenter(const BoardPosition(1, 1));
        await controller.rotateSelection(RotationDirection.clockwise);
        expect(controller.state.remainingRotations, expectedRemaining);
      }

      controller.selectRotationCenter(const BoardPosition(1, 1));
      expect(controller.state.selectedRotationCenter, isNull);

      await controller.rotateSelection(RotationDirection.clockwise);
      expect(controller.state.remainingRotations, 0);
      expect(engine.applyMoveCalls, 3);
      expect(engine.rotationValidationInputs, [3, 2, 1]);
    },
  );

  test('invalid rotation does not consume a charge', () async {
    final engine = _FakeRotationEngine(validRotations: 0);
    final controller = GameSessionController(
      engine: engine,
      highScoreRepository: InMemoryHighScoreRepository(),
      animationBus: BoardAnimationBus(),
      durations: const GameSessionDurations.instant(),
    );

    controller.startNewGame();
    controller.selectRotationCenter(const BoardPosition(1, 1));
    await controller.rotateSelection(RotationDirection.clockwise);

    expect(controller.state.remainingRotations, kInitialRotationCharges);
    expect(controller.state.phase, GamePhase.playing);
    expect(engine.applyMoveCalls, 0);
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
          move.center != null;

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
