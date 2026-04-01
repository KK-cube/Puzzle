import 'dart:math';

import 'models.dart';

typedef _NullableBoard = List<List<Tile?>>;

class PuzzleEngine {
  PuzzleEngine({Random? random}) : _random = random ?? Random();

  final Random _random;
  int _nextTileId = 1;

  BoardMatrix createInitialBoard({
    int remainingRotations = kInitialRotationCharges,
  }) {
    for (var attempt = 0; attempt < 300; attempt++) {
      final board = _generateMatchFreeBoard();
      if (findAvailableSwapMoves(board).isNotEmpty) {
        return board;
      }
    }

    return _generateMatchFreeBoard();
  }

  MoveValidation validateMove(
    BoardMatrix board,
    MoveCommand move, {
    required int remainingRotations,
  }) {
    if (move.type == MoveType.rotate3x3 && remainingRotations <= 0) {
      return MoveValidation(
        isValid: false,
        previewBoard: cloneBoard(board),
        matchedPositions: const <BoardPosition>{},
        consumesRotation: false,
      );
    }

    final previewBoard = _applyOperation(board, move);
    if (previewBoard == null) {
      return MoveValidation(
        isValid: false,
        previewBoard: cloneBoard(board),
        matchedPositions: const <BoardPosition>{},
        consumesRotation: false,
      );
    }

    final matchedPositions = findMatches(previewBoard);
    final isValid = matchedPositions.isNotEmpty;
    return MoveValidation(
      isValid: isValid,
      previewBoard: previewBoard,
      matchedPositions: matchedPositions,
      consumesRotation: isValid && move.type == MoveType.rotate3x3,
    );
  }

  MoveApplication applyMove(
    BoardMatrix board,
    MoveCommand move, {
    required int remainingRotations,
  }) {
    final validation = validateMove(
      board,
      move,
      remainingRotations: remainingRotations,
    );
    if (!validation.isValid) {
      return MoveApplication(
        isValid: false,
        previewBoard: validation.previewBoard,
        finalBoard: cloneBoard(board),
        waves: const [],
        totalScore: 0,
        totalChains: 0,
        consumesRotation: false,
      );
    }

    final resolution = resolveBoard(validation.previewBoard);
    return MoveApplication(
      isValid: true,
      previewBoard: validation.previewBoard,
      finalBoard: resolution.finalBoard,
      waves: resolution.waves,
      totalScore: resolution.totalScore,
      totalChains: resolution.totalChains,
      consumesRotation: validation.consumesRotation,
    );
  }

  BoardResolution resolveBoard(BoardMatrix board) {
    var workingBoard = cloneBoard(board);
    final waves = <ResolveWave>[];
    var totalScore = 0;
    var chainIndex = 1;

    while (true) {
      final matches = findMatches(workingBoard);
      if (matches.isEmpty) {
        break;
      }

      final boardBeforeClear = cloneBoard(workingBoard);
      final clearedTileIds = <int>{
        for (final position in matches)
          boardBeforeClear[position.row][position.column].id,
      };
      final nullableBoard = _clearMatches(workingBoard, matches);
      workingBoard = _collapseAndRefill(nullableBoard);
      final scoreDelta = calculateScore(
        clearedTiles: matches.length,
        chainIndex: chainIndex,
      );
      totalScore += scoreDelta;
      waves.add(
        ResolveWave(
          chainIndex: chainIndex,
          boardBeforeClear: boardBeforeClear,
          boardAfterRefill: cloneBoard(workingBoard),
          clearedPositions: matches,
          clearedTileIds: clearedTileIds,
          scoreDelta: scoreDelta,
        ),
      );
      chainIndex++;
    }

    return BoardResolution(
      finalBoard: cloneBoard(workingBoard),
      waves: waves,
      totalScore: totalScore,
      totalChains: waves.length,
    );
  }

  List<MoveCommand> findAvailableMoves(
    BoardMatrix board, {
    required int remainingRotations,
  }) {
    final swapMoves = findAvailableSwapMoves(board);
    if (swapMoves.isNotEmpty) {
      return swapMoves;
    }

    return findAvailableRotationMoves(
      board,
      remainingRotations: remainingRotations,
    );
  }

  List<MoveCommand> findAvailableSwapMoves(BoardMatrix board) {
    final moves = <MoveCommand>[];

    for (var first = 0; first < kBoardSize; first++) {
      for (var second = first + 1; second < kBoardSize; second++) {
        final rowMove = MoveCommand.swapRows(first, second);
        if (validateMove(
          board,
          rowMove,
          remainingRotations: kInitialRotationCharges,
        ).isValid) {
          moves.add(rowMove);
        }

        final columnMove = MoveCommand.swapColumns(first, second);
        if (validateMove(
          board,
          columnMove,
          remainingRotations: kInitialRotationCharges,
        ).isValid) {
          moves.add(columnMove);
        }
      }
    }

    return moves;
  }

  List<MoveCommand> findAvailableRotationMoves(
    BoardMatrix board, {
    required int remainingRotations,
    RotationDirection? direction,
  }) {
    if (remainingRotations <= 0) {
      return const [];
    }

    final moves = <MoveCommand>[];
    for (var row = 1; row < kBoardSize - 1; row++) {
      for (var column = 1; column < kBoardSize - 1; column++) {
        final directions = direction == null
            ? RotationDirection.values
            : [direction];
        for (final candidateDirection in directions) {
          final move = MoveCommand.rotate3x3(
            center: BoardPosition(row, column),
            direction: candidateDirection,
          );
          if (validateMove(
            board,
            move,
            remainingRotations: remainingRotations,
          ).isValid) {
            moves.add(move);
          }
        }
      }
    }

    return moves;
  }

  Set<BoardPosition> findMatches(BoardMatrix board) {
    final matches = <BoardPosition>{};

    for (var row = 0; row < kBoardSize; row++) {
      var start = 0;
      while (start < kBoardSize) {
        final color = board[row][start].color;
        var end = start + 1;
        while (end < kBoardSize && board[row][end].color == color) {
          end++;
        }

        if (end - start >= 3) {
          for (var column = start; column < end; column++) {
            matches.add(BoardPosition(row, column));
          }
        }
        start = end;
      }
    }

    for (var column = 0; column < kBoardSize; column++) {
      var start = 0;
      while (start < kBoardSize) {
        final color = board[start][column].color;
        var end = start + 1;
        while (end < kBoardSize && board[end][column].color == color) {
          end++;
        }

        if (end - start >= 3) {
          for (var row = start; row < end; row++) {
            matches.add(BoardPosition(row, column));
          }
        }
        start = end;
      }
    }

    return matches;
  }

  int calculateScore({required int clearedTiles, required int chainIndex}) {
    final multiplier = switch (chainIndex) {
      1 => 1.0,
      2 => 1.5,
      3 => 2.0,
      _ => 3.0,
    };

    return (clearedTiles * 10 * multiplier).round();
  }

  Tile createTile([TileColor? color]) {
    return Tile(id: _nextTileId++, color: color ?? _randomColor());
  }

  BoardMatrix _generateMatchFreeBoard() {
    final board = List.generate(
      kBoardSize,
      (_) => List<Tile>.filled(kBoardSize, createTile(TileColor.coral)),
      growable: false,
    );

    for (var row = 0; row < kBoardSize; row++) {
      for (var column = 0; column < kBoardSize; column++) {
        final disallowed = <TileColor>{};

        if (column >= 2 &&
            board[row][column - 1].color == board[row][column - 2].color) {
          disallowed.add(board[row][column - 1].color);
        }

        if (row >= 2 &&
            board[row - 1][column].color == board[row - 2][column].color) {
          disallowed.add(board[row - 1][column].color);
        }

        final candidates = TileColor.values
            .where((color) => !disallowed.contains(color))
            .toList(growable: false);
        final nextColor = candidates[_random.nextInt(candidates.length)];
        board[row][column] = createTile(nextColor);
      }
    }

    return board;
  }

  _NullableBoard _clearMatches(BoardMatrix board, Set<BoardPosition> matches) {
    final nullableBoard = [
      for (final row in board) [...row.cast<Tile?>()],
    ];

    for (final position in matches) {
      nullableBoard[position.row][position.column] = null;
    }

    return nullableBoard;
  }

  BoardMatrix _collapseAndRefill(_NullableBoard board) {
    final collapsed = List.generate(
      kBoardSize,
      (_) => List<Tile>.filled(kBoardSize, createTile(TileColor.coral)),
      growable: false,
    );

    for (var column = 0; column < kBoardSize; column++) {
      final survivors = <Tile>[];
      for (var row = kBoardSize - 1; row >= 0; row--) {
        final tile = board[row][column];
        if (tile != null) {
          survivors.add(tile);
        }
      }

      var survivorIndex = 0;
      for (var row = kBoardSize - 1; row >= 0; row--) {
        if (survivorIndex < survivors.length) {
          collapsed[row][column] = survivors[survivorIndex++];
        } else {
          collapsed[row][column] = createTile();
        }
      }
    }

    return collapsed;
  }

  BoardMatrix? _applyOperation(BoardMatrix board, MoveCommand move) {
    final nextBoard = cloneBoard(board);
    switch (move.type) {
      case MoveType.swapRow:
        final first = move.primaryIndex;
        final second = move.secondaryIndex;
        if (first == null ||
            second == null ||
            first == second ||
            !_isBoardIndex(first) ||
            !_isBoardIndex(second)) {
          return null;
        }

        final temp = nextBoard[first];
        nextBoard[first] = nextBoard[second];
        nextBoard[second] = temp;
        return nextBoard;
      case MoveType.swapColumn:
        final first = move.primaryIndex;
        final second = move.secondaryIndex;
        if (first == null ||
            second == null ||
            first == second ||
            !_isBoardIndex(first) ||
            !_isBoardIndex(second)) {
          return null;
        }

        for (var row = 0; row < kBoardSize; row++) {
          final temp = nextBoard[row][first];
          nextBoard[row][first] = nextBoard[row][second];
          nextBoard[row][second] = temp;
        }
        return nextBoard;
      case MoveType.rotate3x3:
        final center = move.center;
        final direction = move.direction;
        if (center == null || direction == null || !center.isRotationCenter) {
          return null;
        }

        final top = center.row - 1;
        final left = center.column - 1;
        final slice = List.generate(
          3,
          (row) => List<Tile>.generate(
            3,
            (column) => board[top + row][left + column],
          ),
          growable: false,
        );

        for (var row = 0; row < 3; row++) {
          for (var column = 0; column < 3; column++) {
            final tile = switch (direction) {
              RotationDirection.clockwise => slice[2 - column][row],
              RotationDirection.counterClockwise => slice[column][2 - row],
            };
            nextBoard[top + row][left + column] = tile;
          }
        }
        return nextBoard;
    }
  }

  bool _isBoardIndex(int value) {
    return value >= 0 && value < kBoardSize;
  }

  TileColor _randomColor() {
    return TileColor.values[_random.nextInt(TileColor.values.length)];
  }
}
