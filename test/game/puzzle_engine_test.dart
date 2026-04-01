import 'dart:collection';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game/domain/models.dart';
import 'package:flutter_application_1/game/domain/puzzle_engine.dart';

void main() {
  group('PuzzleEngine', () {
    test(
      'createInitialBoard avoids immediate matches and has standard moves',
      () {
        final engine = PuzzleEngine(random: Random(7));

        final board = engine.createInitialBoard();

        expect(engine.findMatches(board), isEmpty);
        expect(engine.findAvailableSwapMoves(board), isNotEmpty);
      },
    );

    test(
      'validateMove finds valid row swap, column swap, and rotation moves',
      () {
        final engine = PuzzleEngine(random: Random(9));

        final rowSwapBoard = _boardFromRows(const [
          'ABCDEAB',
          'BCDEABC',
          'ADEABCD',
          'AEBCDAE',
          'CDEABCD',
          'DEABCDE',
          'EABCDEA',
        ]);
        final rowValidation = engine.validateMove(
          rowSwapBoard,
          MoveCommand.swapRows(1, 3),
          remainingRotations: kInitialRotationCharges,
        );
        expect(rowValidation.isValid, isTrue);

        final columnSwapBoard = _boardFromRows(const [
          'DAACAEB',
          'ABCDEAC',
          'BCDEBCD',
          'CDEACDE',
          'EABCDEA',
          'BDCAEBC',
          'CEBDACE',
        ]);
        final columnValidation = engine.validateMove(
          columnSwapBoard,
          MoveCommand.swapColumns(0, 4),
          remainingRotations: kInitialRotationCharges,
        );
        expect(columnValidation.isValid, isTrue);

        final rotationBoard = _boardFromRows(const [
          'ABCAADE',
          'DEBCADB',
          'CDEABCE',
          'EABCDEA',
          'BCDEABC',
          'CEABDCE',
          'DEABCED',
        ]);
        final rotationValidation = engine.validateMove(
          rotationBoard,
          MoveCommand.rotate3x3(
            center: const BoardPosition(1, 1),
            direction: RotationDirection.clockwise,
          ),
          remainingRotations: kInitialRotationCharges,
        );
        expect(rotationValidation.isValid, isTrue);
        expect(rotationValidation.consumesRotation, isTrue);

        final noChargeValidation = engine.validateMove(
          rotationBoard,
          MoveCommand.rotate3x3(
            center: const BoardPosition(1, 1),
            direction: RotationDirection.clockwise,
          ),
          remainingRotations: 0,
        );
        expect(noChargeValidation.isValid, isFalse);
      },
    );

    test('applyMove reports invalid operations without waves or score', () {
      final engine = PuzzleEngine(random: Random(21));
      final board = _boardFromRows(const [
        'ABCDEAB',
        'BCDEABC',
        'CDEABCD',
        'DEABCDE',
        'EABCDEA',
        'ABCDEAB',
        'BCDEABC',
      ]);

      final result = engine.applyMove(
        board,
        MoveCommand.swapRows(0, 1),
        remainingRotations: kInitialRotationCharges,
      );

      expect(result.isValid, isFalse);
      expect(result.waves, isEmpty);
      expect(result.totalScore, 0);
      expect(boardsShareLayout(result.finalBoard, board), isTrue);
    });

    test('rotation without a match is rejected', () {
      final engine = PuzzleEngine(random: Random(21));
      final board = _boardFromRows(const [
        'ABCDEAB',
        'BCDEABC',
        'CDEABCD',
        'DEABCDE',
        'EABCDEA',
        'ABCDEAB',
        'BCDEABC',
      ]);

      final result = engine.applyMove(
        board,
        MoveCommand.rotate3x3(
          center: const BoardPosition(1, 1),
          direction: RotationDirection.clockwise,
        ),
        remainingRotations: kInitialRotationCharges,
      );

      expect(result.isValid, isFalse);
      expect(result.consumesRotation, isFalse);
      expect(result.waves, isEmpty);
      expect(result.totalScore, 0);
      expect(boardsShareLayout(result.finalBoard, board), isTrue);
    });

    test('fever move guarantees a match for an otherwise invalid swap', () {
      final engine = PuzzleEngine(random: Random(21));
      final board = _boardFromRows(const [
        'ABCDEAB',
        'BCDEABC',
        'CDEABCD',
        'DEABCDE',
        'EABCDEA',
        'ABCDEAB',
        'BCDEABC',
      ]);

      final validation = engine.validateMove(
        board,
        MoveCommand.swapRows(0, 1),
        remainingRotations: kInitialRotationCharges,
        feverActive: true,
      );

      expect(validation.isValid, isTrue);
      expect(validation.matchedPositions, isNotEmpty);
    });

    test('resolveBoard handles chains and applies score multipliers', () {
      final engine = _ScriptedPuzzleEngine(const [
        TileColor.violet,
        TileColor.mint,
        TileColor.teal,
        TileColor.gold,
        TileColor.violet,
        TileColor.mint,
      ]);
      final board = _boardFromRows(const [
        'ACDEBCD',
        'ADEBCDE',
        'BBBCDEA',
        'ACDEABC',
        'CDEABCD',
        'DEABCDE',
        'EACDEAB',
      ]);

      final resolution = engine.resolveBoard(board);

      expect(resolution.totalChains, 2);
      expect(resolution.waves, hasLength(2));
      expect(resolution.waves.first.scoreDelta, 30);
      expect(resolution.waves.last.scoreDelta, 75);
      expect(resolution.totalScore, 105);
      expect(engine.findMatches(resolution.finalBoard), isEmpty);
    });

    test(
      'findAvailableRotationMoves surfaces valid rotations when present',
      () {
        final engine = PuzzleEngine(random: Random(8));
        final board = _boardFromRows(const [
          'ABCAADE',
          'DEBCADB',
          'CDEABCE',
          'EABCDEA',
          'BCDEABC',
          'CEABDCE',
          'DEABCED',
        ]);

        final moves = engine.findAvailableRotationMoves(
          board,
          remainingRotations: kInitialRotationCharges,
        );

        expect(moves.any((move) => move.type == MoveType.rotate3x3), isTrue);
      },
    );
  });
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

class _ScriptedPuzzleEngine extends PuzzleEngine {
  _ScriptedPuzzleEngine(List<TileColor> scriptedColors)
    : _script = Queue<TileColor>.from(scriptedColors),
      super(random: Random(1));

  final Queue<TileColor> _script;

  @override
  Tile createTile([TileColor? color]) {
    final nextColor =
        color ?? (_script.isNotEmpty ? _script.removeFirst() : TileColor.coral);
    return super.createTile(nextColor);
  }
}
