import 'dart:math' as math;
import 'dart:ui';

import '../domain/models.dart';

class BoardGeometry {
  BoardGeometry(Size size)
    : boardSize = math.min(size.width, size.height),
      _size = size;

  final double boardSize;
  final Size _size;

  late final double outerPadding = clampDouble(boardSize * 0.024, 8, 16);
  late final double boardSide = boardSize - (outerPadding * 2);
  late final double cellSize = boardSide / kBoardSize;
  late final double dragActivationDistance = clampDouble(
    cellSize * 0.2,
    10,
    18,
  );
  late final Offset origin = Offset(
    (_size.width - boardSize) / 2,
    (_size.height - boardSize) / 2,
  );
  late final Rect boardRect = Rect.fromLTWH(
    origin.dx + outerPadding,
    origin.dy + outerPadding,
    boardSide,
    boardSide,
  );

  Rect cellRect(int row, int column) {
    return Rect.fromLTWH(
      boardRect.left + (column * cellSize),
      boardRect.top + (row * cellSize),
      cellSize,
      cellSize,
    );
  }

  Rect rowRect(int row) {
    return Rect.fromLTWH(
      boardRect.left,
      boardRect.top + (row * cellSize),
      boardRect.width,
      cellSize,
    );
  }

  Rect columnRect(int column) {
    return Rect.fromLTWH(
      boardRect.left + (column * cellSize),
      boardRect.top,
      cellSize,
      boardRect.height,
    );
  }

  BoardPosition? cellAt(Offset point) {
    if (!boardRect.contains(point)) {
      return null;
    }

    final row = ((point.dy - boardRect.top) / cellSize).floor();
    final column = ((point.dx - boardRect.left) / cellSize).floor();
    if (!_isBoardIndex(row) || !_isBoardIndex(column)) {
      return null;
    }

    return BoardPosition(row, column);
  }

  double clampRowOffset(int row, double offset) {
    return clampDouble(
      offset,
      -(row * cellSize),
      (kBoardSize - 1 - row) * cellSize,
    );
  }

  double clampColumnOffset(int column, double offset) {
    return clampDouble(
      offset,
      -(column * cellSize),
      (kBoardSize - 1 - column) * cellSize,
    );
  }

  int nearestRowForOffset(int sourceRow, double offset) {
    final y = rowCenter(sourceRow) + clampRowOffset(sourceRow, offset);
    return ((y - boardRect.top) / cellSize).round().clamp(0, kBoardSize - 1);
  }

  int nearestColumnForOffset(int sourceColumn, double offset) {
    final x =
        columnCenter(sourceColumn) + clampColumnOffset(sourceColumn, offset);
    return ((x - boardRect.left) / cellSize).round().clamp(0, kBoardSize - 1);
  }

  bool _isBoardIndex(int value) => value >= 0 && value < kBoardSize;

  double rowCenter(int row) => boardRect.top + ((row + 0.5) * cellSize);

  double columnCenter(int column) =>
      boardRect.left + ((column + 0.5) * cellSize);
}
