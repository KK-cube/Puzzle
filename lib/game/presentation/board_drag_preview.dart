import 'package:flutter/foundation.dart';

@immutable
class BoardDragPreview {
  const BoardDragPreview({
    required this.axis,
    required this.sourceIndex,
    required this.targetIndex,
    required this.offset,
  });

  final BoardDragAxis axis;
  final int sourceIndex;
  final int targetIndex;
  final double offset;
}

enum BoardDragAxis { row, column }
