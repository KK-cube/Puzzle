const int kBoardSize = 7;
const int kInitialRotationCharges = 3;

typedef BoardMatrix = List<List<Tile>>;

enum TileColor { coral, teal, gold, violet, mint }

class Tile {
  const Tile({required this.id, required this.color});

  final int id;
  final TileColor color;

  Tile copyWith({int? id, TileColor? color}) {
    return Tile(id: id ?? this.id, color: color ?? this.color);
  }
}

class BoardPosition {
  const BoardPosition(this.row, this.column);

  final int row;
  final int column;

  bool get isRotationCenter {
    return row > 0 &&
        row < kBoardSize - 1 &&
        column > 0 &&
        column < kBoardSize - 1;
  }

  @override
  bool operator ==(Object other) {
    return other is BoardPosition && other.row == row && other.column == column;
  }

  @override
  int get hashCode => Object.hash(row, column);
}

enum MoveType { swapRow, swapColumn, rotate3x3 }

enum RotationDirection { clockwise, counterClockwise }

class MoveCommand {
  const MoveCommand._({
    required this.type,
    this.primaryIndex,
    this.secondaryIndex,
    this.center,
    this.direction,
  });

  factory MoveCommand.swapRows(int topRow, int bottomRow) {
    return MoveCommand._(
      type: MoveType.swapRow,
      primaryIndex: topRow,
      secondaryIndex: bottomRow,
    );
  }

  factory MoveCommand.swapColumns(int leftColumn, int rightColumn) {
    return MoveCommand._(
      type: MoveType.swapColumn,
      primaryIndex: leftColumn,
      secondaryIndex: rightColumn,
    );
  }

  factory MoveCommand.rotate3x3({
    required BoardPosition center,
    required RotationDirection direction,
  }) {
    return MoveCommand._(
      type: MoveType.rotate3x3,
      center: center,
      direction: direction,
    );
  }

  final MoveType type;
  final int? primaryIndex;
  final int? secondaryIndex;
  final BoardPosition? center;
  final RotationDirection? direction;
}

class BoardHint {
  const BoardHint({required this.move});

  final MoveCommand move;
}

class MoveValidation {
  const MoveValidation({
    required this.isValid,
    required this.previewBoard,
    required this.matchedPositions,
    required this.consumesRotation,
  });

  final bool isValid;
  final BoardMatrix previewBoard;
  final Set<BoardPosition> matchedPositions;
  final bool consumesRotation;
}

class ResolveWave {
  const ResolveWave({
    required this.chainIndex,
    required this.boardBeforeClear,
    required this.boardAfterRefill,
    required this.clearedPositions,
    required this.clearedTileIds,
    required this.scoreDelta,
  });

  final int chainIndex;
  final BoardMatrix boardBeforeClear;
  final BoardMatrix boardAfterRefill;
  final Set<BoardPosition> clearedPositions;
  final Set<int> clearedTileIds;
  final int scoreDelta;
}

class BoardResolution {
  const BoardResolution({
    required this.finalBoard,
    required this.waves,
    required this.totalScore,
    required this.totalChains,
  });

  final BoardMatrix finalBoard;
  final List<ResolveWave> waves;
  final int totalScore;
  final int totalChains;
}

class MoveApplication {
  const MoveApplication({
    required this.isValid,
    required this.previewBoard,
    required this.finalBoard,
    required this.waves,
    required this.totalScore,
    required this.totalChains,
    required this.consumesRotation,
  });

  final bool isValid;
  final BoardMatrix previewBoard;
  final BoardMatrix finalBoard;
  final List<ResolveWave> waves;
  final int totalScore;
  final int totalChains;
  final bool consumesRotation;
}

BoardMatrix cloneBoard(BoardMatrix board) {
  return [
    for (final row in board) [...row],
  ];
}

bool boardsShareLayout(BoardMatrix left, BoardMatrix right) {
  if (left.length != right.length) {
    return false;
  }

  for (var row = 0; row < left.length; row++) {
    if (left[row].length != right[row].length) {
      return false;
    }

    for (var column = 0; column < left[row].length; column++) {
      if (left[row][column].id != right[row][column].id) {
        return false;
      }
    }
  }

  return true;
}
