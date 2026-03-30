import 'dart:math' as math;
import 'dart:ui';

import '../domain/models.dart';

class BoardGeometry {
  BoardGeometry(Size size)
    : boardSize = math.min(size.width, size.height),
      _size = size;

  final double boardSize;
  final Size _size;

  late final double outerPadding = boardSize * 0.04;
  late final double leftGutter = boardSize * 0.14;
  late final double topGutter = boardSize * 0.14;
  late final double boardSide =
      boardSize - (outerPadding * 2) - leftGutter - topGutter;
  late final double cellSize = boardSide / kBoardSize;
  late final Offset origin = Offset(
    (_size.width - boardSize) / 2,
    (_size.height - boardSize) / 2,
  );
  late final Rect boardRect = Rect.fromLTWH(
    origin.dx + outerPadding + leftGutter,
    origin.dy + outerPadding + topGutter,
    boardSide,
    boardSide,
  );
  late final Rect rowGutterRect = Rect.fromLTWH(
    origin.dx + outerPadding,
    boardRect.top,
    leftGutter,
    boardSide,
  );
  late final Rect columnGutterRect = Rect.fromLTWH(
    boardRect.left,
    origin.dy + outerPadding,
    boardSide,
    topGutter,
  );

  Rect cellRect(int row, int column) {
    return Rect.fromLTWH(
      boardRect.left + (column * cellSize),
      boardRect.top + (row * cellSize),
      cellSize,
      cellSize,
    );
  }

  Rect rowHandleRect(int row) {
    return Rect.fromLTWH(
      rowGutterRect.left,
      boardRect.top + (row * cellSize),
      rowGutterRect.width,
      cellSize,
    );
  }

  Rect columnHandleRect(int column) {
    return Rect.fromLTWH(
      boardRect.left + (column * cellSize),
      columnGutterRect.top,
      cellSize,
      columnGutterRect.height,
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

  int? rowHandleAt(Offset point) {
    if (!rowGutterRect.inflate(cellSize * 0.25).contains(point)) {
      return null;
    }

    final row = ((point.dy - boardRect.top) / cellSize).floor();
    return _isBoardIndex(row) ? row : null;
  }

  int? columnHandleAt(Offset point) {
    if (!columnGutterRect.inflate(cellSize * 0.25).contains(point)) {
      return null;
    }

    final column = ((point.dx - boardRect.left) / cellSize).floor();
    return _isBoardIndex(column) ? column : null;
  }

  bool _isBoardIndex(int value) => value >= 0 && value < kBoardSize;
}
