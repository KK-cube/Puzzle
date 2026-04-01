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
  late final double touchHitSlop = clampDouble(cellSize * 0.28, 10, 18);
  late final double rowSnapRadius = clampDouble(cellSize * 0.32, 12, 22);
  late final double columnSnapRadius = clampDouble(cellSize * 0.38, 14, 24);
  static const double _rowSnapBias = 1.18;
  static const double _columnSnapBias = 1.25;
  static const double _rowSnapStrength = 0.68;
  static const double _columnSnapStrength = 0.78;
  late final Offset origin = Offset(
    (_size.width - boardSize) / 2,
    (_size.height - boardSize) / 2,
  );
  late final Rect panelRect = Rect.fromLTWH(
    origin.dx,
    origin.dy,
    boardSize,
    boardSize,
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
    if (!panelRect.inflate(touchHitSlop).contains(point)) {
      return null;
    }

    final clampedPoint = Offset(
      point.dx.clamp(boardRect.left, boardRect.right - 0.001),
      point.dy.clamp(boardRect.top, boardRect.bottom - 0.001),
    );
    final row = ((clampedPoint.dy - boardRect.top) / cellSize).floor();
    final column = ((clampedPoint.dx - boardRect.left) / cellSize).floor();
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
    final normalizedOffset =
        (clampRowOffset(sourceRow, offset) / cellSize) * _rowSnapBias;
    return (sourceRow + normalizedOffset).round().clamp(0, kBoardSize - 1);
  }

  int nearestColumnForOffset(int sourceColumn, double offset) {
    final normalizedOffset =
        (clampColumnOffset(sourceColumn, offset) / cellSize) * _columnSnapBias;
    return (sourceColumn + normalizedOffset).round().clamp(0, kBoardSize - 1);
  }

  double snappedRowOffset(int sourceRow, double offset) {
    final clampedOffset = clampRowOffset(sourceRow, offset);
    final targetRow = nearestRowForOffset(sourceRow, clampedOffset);
    return _applySnap(
      clampedOffset,
      targetOffset: (targetRow - sourceRow) * cellSize,
      snapRadius: rowSnapRadius,
      snapStrength: _rowSnapStrength,
    );
  }

  double snappedColumnOffset(int sourceColumn, double offset) {
    final clampedOffset = clampColumnOffset(sourceColumn, offset);
    final targetColumn = nearestColumnForOffset(sourceColumn, clampedOffset);
    return _applySnap(
      clampedOffset,
      targetOffset: (targetColumn - sourceColumn) * cellSize,
      snapRadius: columnSnapRadius,
      snapStrength: _columnSnapStrength,
    );
  }

  bool _isBoardIndex(int value) => value >= 0 && value < kBoardSize;

  double rowCenter(int row) => boardRect.top + ((row + 0.5) * cellSize);

  double columnCenter(int column) =>
      boardRect.left + ((column + 0.5) * cellSize);

  double _applySnap(
    double offset, {
    required double targetOffset,
    required double snapRadius,
    required double snapStrength,
  }) {
    final distance = (offset - targetOffset).abs();
    if (distance <= 0 || distance >= snapRadius) {
      return offset;
    }

    final t = 1 - (distance / snapRadius);
    final eased = t * t * (3 - (2 * t));
    return offset + ((targetOffset - offset) * eased * snapStrength);
  }
}
