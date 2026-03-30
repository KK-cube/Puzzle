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
  _PendingDrag? _pendingDrag;
  _ActiveDrag? _activeDrag;

  @override
  void didUpdateWidget(covariant BoardInteractionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.inputLocked &&
        (_pendingDrag != null || _activeDrag != null)) {
      _clearDragState();
    }
  }

  @override
  void dispose() {
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
          onTapUp: widget.state.inputLocked
              ? null
              : (details) => _handleTap(details.localPosition, geometry),
          onPanStart: widget.state.inputLocked
              ? null
              : (details) => _handlePanStart(details.localPosition, geometry),
          onPanUpdate: widget.state.inputLocked
              ? null
              : (details) => _handlePanUpdate(details.localPosition, geometry),
          onPanEnd: widget.state.inputLocked ? null : (_) => _handlePanEnd(),
          onPanCancel: _clearDragState,
          child: CustomPaint(
            painter: _InteractionPainter(
              geometry: geometry,
              state: widget.state,
              dragPreview: widget.dragPreview.value,
            ),
          ),
        );
      },
    );
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
    if (cell.isRotationCenter) {
      controller.selectRotationCenter(cell);
    } else {
      controller.clearRotationSelection();
    }
  }

  void _handlePanStart(Offset position, BoardGeometry geometry) {
    final cell = geometry.cellAt(position);
    if (cell == null) {
      return;
    }

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

      final axis = delta.dx.abs() >= delta.dy.abs()
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
    final clampedOffset = activeDrag.axis == BoardDragAxis.row
        ? geometry.clampRowOffset(activeDrag.sourceIndex, rawOffset)
        : geometry.clampColumnOffset(activeDrag.sourceIndex, rawOffset);
    final targetIndex = activeDrag.axis == BoardDragAxis.row
        ? geometry.nearestRowForOffset(activeDrag.sourceIndex, clampedOffset)
        : geometry.nearestColumnForOffset(
            activeDrag.sourceIndex,
            clampedOffset,
          );
    final preview = BoardDragPreview(
      axis: activeDrag.axis,
      sourceIndex: activeDrag.sourceIndex,
      targetIndex: targetIndex,
      offset: clampedOffset,
    );

    widget.dragPreview.value = preview;
    setState(() {
      _activeDrag = activeDrag.copyWith(
        targetIndex: targetIndex,
        offset: clampedOffset,
      );
    });
  }

  void _handlePanEnd() {
    final activeDrag = _activeDrag;
    _clearDragState();

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

  void _clearDragState() {
    if (_pendingDrag == null &&
        _activeDrag == null &&
        widget.dragPreview.value == null) {
      return;
    }

    widget.dragPreview.value = null;
    setState(() {
      _pendingDrag = null;
      _activeDrag = null;
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
  });

  final BoardGeometry geometry;
  final GameSessionState state;
  final BoardDragPreview? dragPreview;

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

    if (state.inputLocked) {
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
        oldDelegate.state.selectedRotationCenter !=
            state.selectedRotationCenter ||
        oldDelegate.state.inputLocked != state.inputLocked;
  }
}
