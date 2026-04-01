import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_providers.dart';
import '../application/game_session_state.dart';
import '../domain/models.dart';
import 'board_drag_preview.dart';
import 'board_geometry.dart';

class BoardInteractionOverlay extends ConsumerStatefulWidget {
  const BoardInteractionOverlay({
    super.key,
    required this.state,
    required this.dragPreview,
  });

  final GameSessionState state;
  final ValueNotifier<BoardDragPreview?> dragPreview;

  @override
  ConsumerState<BoardInteractionOverlay> createState() =>
      _BoardInteractionOverlayState();
}

class _BoardInteractionOverlayState
    extends ConsumerState<BoardInteractionOverlay> {
  static const _touchFeedbackHold = Duration(milliseconds: 280);
  static const _horizontalAxisBias = 1.12;

  _PendingDrag? _pendingDrag;
  _ActiveDrag? _activeDrag;
  BoardPosition? _touchFocusCell;
  Timer? _touchFocusTimer;

  @override
  void didUpdateWidget(covariant BoardInteractionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isInteractionLocked &&
        (_pendingDrag != null ||
            _activeDrag != null ||
            _touchFocusCell != null ||
            widget.dragPreview.value != null)) {
      _clearDragState(clearTouchFocus: true);
    }
  }

  @override
  void dispose() {
    _touchFocusTimer?.cancel();
    widget.dragPreview.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = BoardGeometry(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.state.isInteractionLocked
              ? null
              : (details) => _handleTouchDown(details.localPosition, geometry),
          onTapCancel: _handleTapCancel,
          onTapUp: widget.state.isInteractionLocked
              ? null
              : (details) => _handleTap(details.localPosition, geometry),
          onPanDown: widget.state.isInteractionLocked
              ? null
              : (details) => _handleTouchDown(details.localPosition, geometry),
          onPanStart: widget.state.isInteractionLocked
              ? null
              : (details) => _handlePanStart(details.localPosition, geometry),
          onPanUpdate: widget.state.isInteractionLocked
              ? null
              : (details) => _handlePanUpdate(details.localPosition, geometry),
          onPanEnd: widget.state.isInteractionLocked
              ? null
              : (_) => _handlePanEnd(),
          onPanCancel: _handlePanCancel,
          child: CustomPaint(
            painter: _InteractionPainter(
              geometry: geometry,
              state: widget.state,
              dragPreview: widget.dragPreview.value,
              touchFocusCell: _touchFocusCell,
            ),
          ),
        );
      },
    );
  }

  void _handleTouchDown(Offset position, BoardGeometry geometry) {
    final cell = geometry.cellAt(position);
    if (cell == null) {
      _clearTouchFocus();
      return;
    }

    _setTouchFocus(cell);
  }

  void _handleTapCancel() {
    if (_pendingDrag != null || _activeDrag != null) {
      return;
    }

    _scheduleTouchFocusClear();
  }

  void _handleTap(Offset position, BoardGeometry geometry) {
    if (_pendingDrag != null || _activeDrag != null) {
      return;
    }

    final cell = geometry.cellAt(position);
    if (cell == null) {
      return;
    }

    final controller = ref.read(gameSessionControllerProvider.notifier);
    controller.noteInteraction();
    controller.clearRotationSelection();
    _setTouchFocus(cell);
    _scheduleTouchFocusClear();
  }

  void _handlePanStart(Offset position, BoardGeometry geometry) {
    final cell = geometry.cellAt(position);
    if (cell == null) {
      return;
    }

    ref.read(gameSessionControllerProvider.notifier).noteInteraction();
    _setTouchFocus(cell);

    setState(() {
      _pendingDrag = _PendingDrag(originCell: cell, startPosition: position);
      _activeDrag = null;
    });
  }

  void _handlePanUpdate(Offset position, BoardGeometry geometry) {
    final pendingDrag = _pendingDrag;
    if (pendingDrag != null) {
      final delta = position - pendingDrag.startPosition;
      if (delta.distance < geometry.dragActivationDistance) {
        return;
      }

      final horizontalDistance = delta.dx.abs();
      final verticalDistance = delta.dy.abs();
      final axis =
          horizontalDistance >= (verticalDistance * _horizontalAxisBias)
          ? BoardDragAxis.column
          : BoardDragAxis.row;
      final sourceIndex = axis == BoardDragAxis.column
          ? pendingDrag.originCell.column
          : pendingDrag.originCell.row;
      ref.read(gameSessionControllerProvider.notifier).clearRotationSelection();
      setState(() {
        _pendingDrag = null;
        _activeDrag = _ActiveDrag(
          axis: axis,
          sourceIndex: sourceIndex,
          startPosition: pendingDrag.startPosition,
          targetIndex: sourceIndex,
          offset: 0,
        );
      });
    }

    final activeDrag = _activeDrag;
    if (activeDrag == null) {
      return;
    }

    final rawOffset = activeDrag.axis == BoardDragAxis.row
        ? position.dy - activeDrag.startPosition.dy
        : position.dx - activeDrag.startPosition.dx;
    final snappedOffset = activeDrag.axis == BoardDragAxis.row
        ? geometry.snappedRowOffset(activeDrag.sourceIndex, rawOffset)
        : geometry.snappedColumnOffset(activeDrag.sourceIndex, rawOffset);
    final targetIndex = activeDrag.axis == BoardDragAxis.row
        ? geometry.nearestRowForOffset(activeDrag.sourceIndex, snappedOffset)
        : geometry.nearestColumnForOffset(
            activeDrag.sourceIndex,
            snappedOffset,
          );
    final preview = BoardDragPreview(
      axis: activeDrag.axis,
      sourceIndex: activeDrag.sourceIndex,
      targetIndex: targetIndex,
      offset: snappedOffset,
    );

    widget.dragPreview.value = preview;
    setState(() {
      _activeDrag = activeDrag.copyWith(
        targetIndex: targetIndex,
        offset: snappedOffset,
      );
    });
  }

  void _handlePanEnd() {
    final activeDrag = _activeDrag;
    _clearDragState();
    _scheduleTouchFocusClear();

    if (activeDrag == null ||
        activeDrag.sourceIndex == activeDrag.targetIndex) {
      return;
    }

    final controller = ref.read(gameSessionControllerProvider.notifier);
    if (activeDrag.axis == BoardDragAxis.row) {
      controller.swapRows(activeDrag.sourceIndex, activeDrag.targetIndex);
    } else {
      controller.swapColumns(activeDrag.sourceIndex, activeDrag.targetIndex);
    }
  }

  void _handlePanCancel() {
    _clearDragState(clearTouchFocus: true);
  }

  void _setTouchFocus(BoardPosition cell) {
    _touchFocusTimer?.cancel();
    _touchFocusTimer = null;
    if (_touchFocusCell == cell) {
      return;
    }

    setState(() {
      _touchFocusCell = cell;
    });
  }

  void _scheduleTouchFocusClear() {
    if (_touchFocusCell == null) {
      return;
    }

    _touchFocusTimer?.cancel();
    _touchFocusTimer = Timer(_touchFeedbackHold, _clearTouchFocus);
  }

  void _clearTouchFocus() {
    _touchFocusTimer?.cancel();
    _touchFocusTimer = null;
    if (_touchFocusCell == null) {
      return;
    }

    setState(() {
      _touchFocusCell = null;
    });
  }

  void _clearDragState({bool clearTouchFocus = false}) {
    if (_pendingDrag == null &&
        _activeDrag == null &&
        widget.dragPreview.value == null &&
        (!clearTouchFocus || _touchFocusCell == null)) {
      return;
    }

    if (clearTouchFocus) {
      _touchFocusTimer?.cancel();
      _touchFocusTimer = null;
    }
    widget.dragPreview.value = null;
    setState(() {
      _pendingDrag = null;
      _activeDrag = null;
      if (clearTouchFocus) {
        _touchFocusCell = null;
      }
    });
  }
}

class _PendingDrag {
  const _PendingDrag({required this.originCell, required this.startPosition});

  final BoardPosition originCell;
  final Offset startPosition;
}

class _ActiveDrag {
  const _ActiveDrag({
    required this.axis,
    required this.sourceIndex,
    required this.startPosition,
    required this.targetIndex,
    required this.offset,
  });

  final BoardDragAxis axis;
  final int sourceIndex;
  final Offset startPosition;
  final int targetIndex;
  final double offset;

  _ActiveDrag copyWith({int? targetIndex, double? offset}) {
    return _ActiveDrag(
      axis: axis,
      sourceIndex: sourceIndex,
      startPosition: startPosition,
      targetIndex: targetIndex ?? this.targetIndex,
      offset: offset ?? this.offset,
    );
  }
}

class _InteractionPainter extends CustomPainter {
  const _InteractionPainter({
    required this.geometry,
    required this.state,
    required this.dragPreview,
    required this.touchFocusCell,
  });

  final BoardGeometry geometry;
  final GameSessionState state;
  final BoardDragPreview? dragPreview;
  final BoardPosition? touchFocusCell;

  @override
  void paint(Canvas canvas, Size size) {
    final focusPaint = Paint()
      ..color = const Color(0xFFF8FAFC).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final targetFillPaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.16);
    final targetStrokePaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final activeStrokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final touchConnectorPaint = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.cellSize * 0.14
      ..strokeCap = StrokeCap.round;
    final touchNeighborPaint = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.18);
    final touchCenterGlowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final touchCenterPaint = Paint()
      ..color = const Color(0xFFFFF7D6).withValues(alpha: 0.24);
    final touchCenterStrokePaint = Paint()
      ..color = const Color(0xFFFFFBEB).withValues(alpha: 0.84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final preview = dragPreview;
    if (preview != null) {
      final targetRect = preview.axis == BoardDragAxis.row
          ? geometry.rowRect(preview.targetIndex)
          : geometry.columnRect(preview.targetIndex);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect.deflate(4),
          const Radius.circular(18),
        ),
        targetFillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect.deflate(4),
          const Radius.circular(18),
        ),
        targetStrokePaint,
      );

      final draggedRect = preview.axis == BoardDragAxis.row
          ? geometry
                .rowRect(preview.sourceIndex)
                .shift(Offset(0, preview.offset))
          : geometry
                .columnRect(preview.sourceIndex)
                .shift(Offset(preview.offset, 0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          draggedRect.deflate(5),
          const Radius.circular(18),
        ),
        activeStrokePaint,
      );
    }

    final touchFocus = touchFocusCell;
    if (touchFocus != null) {
      final centerRect = geometry
          .cellRect(touchFocus.row, touchFocus.column)
          .deflate(8);
      final centerPoint = geometry
          .cellRect(touchFocus.row, touchFocus.column)
          .center;

      for (final neighbor in _touchNeighbors(touchFocus)) {
        final neighborPoint = geometry
            .cellRect(neighbor.row, neighbor.column)
            .center;
        canvas.drawLine(centerPoint, neighborPoint, touchConnectorPaint);
      }

      for (final neighbor in _touchNeighbors(touchFocus)) {
        final neighborRect = geometry
            .cellRect(neighbor.row, neighbor.column)
            .deflate(10);
        canvas.drawRRect(
          RRect.fromRectAndRadius(neighborRect, const Radius.circular(16)),
          touchNeighborPaint,
        );
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          centerRect.inflate(4),
          const Radius.circular(18),
        ),
        touchCenterGlowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(centerRect, const Radius.circular(16)),
        touchCenterPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(centerRect, const Radius.circular(16)),
        touchCenterStrokePaint,
      );
    }

    final center = state.selectedRotationCenter;
    if (center != null) {
      final topLeft = geometry
          .cellRect(center.row - 1, center.column - 1)
          .topLeft;
      final bottomRight = geometry
          .cellRect(center.row + 1, center.column + 1)
          .bottomRight;
      final selectionRect = Rect.fromPoints(topLeft, bottomRight).inflate(4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(selectionRect, const Radius.circular(18)),
        focusPaint,
      );
    }

    if (state.isInteractionLocked) {
      final lockPaint = Paint()..color = Colors.black.withValues(alpha: 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(28),
        ),
        lockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InteractionPainter oldDelegate) {
    return oldDelegate.dragPreview != dragPreview ||
        oldDelegate.touchFocusCell != touchFocusCell ||
        oldDelegate.state.selectedRotationCenter !=
            state.selectedRotationCenter ||
        oldDelegate.state.isInteractionLocked != state.isInteractionLocked;
  }

  Iterable<BoardPosition> _touchNeighbors(BoardPosition center) sync* {
    const offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    for (final (rowOffset, columnOffset) in offsets) {
      final row = center.row + rowOffset;
      final column = center.column + columnOffset;
      if (row < 0 || row >= kBoardSize || column < 0 || column >= kBoardSize) {
        continue;
      }

      yield BoardPosition(row, column);
    }
  }
}
