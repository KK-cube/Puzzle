import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_providers.dart';
import '../application/game_session_state.dart';
import '../domain/models.dart';
import 'board_geometry.dart';

class BoardInteractionOverlay extends ConsumerStatefulWidget {
  const BoardInteractionOverlay({super.key, required this.state});

  final GameSessionState state;

  @override
  ConsumerState<BoardInteractionOverlay> createState() =>
      _BoardInteractionOverlayState();
}

class _BoardInteractionOverlayState
    extends ConsumerState<BoardInteractionOverlay> {
  _DragAxis? _dragAxis;
  int? _dragFrom;
  int? _dragTo;

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
              dragAxis: _dragAxis,
              dragFrom: _dragFrom,
              dragTo: _dragTo,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset position, BoardGeometry geometry) {
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
    final rowHandle = geometry.rowHandleAt(position);
    if (rowHandle != null) {
      setState(() {
        _dragAxis = _DragAxis.row;
        _dragFrom = rowHandle;
        _dragTo = rowHandle;
      });
      return;
    }

    final columnHandle = geometry.columnHandleAt(position);
    if (columnHandle != null) {
      setState(() {
        _dragAxis = _DragAxis.column;
        _dragFrom = columnHandle;
        _dragTo = columnHandle;
      });
    }
  }

  void _handlePanUpdate(Offset position, BoardGeometry geometry) {
    if (_dragAxis == null) {
      return;
    }

    if (_dragAxis == _DragAxis.row) {
      final row =
          geometry.rowHandleAt(position) ?? geometry.cellAt(position)?.row;
      if (row != null) {
        setState(() => _dragTo = row);
      }
    } else {
      final column =
          geometry.columnHandleAt(position) ??
          geometry.cellAt(position)?.column;
      if (column != null) {
        setState(() => _dragTo = column);
      }
    }
  }

  void _handlePanEnd() {
    final axis = _dragAxis;
    final from = _dragFrom;
    final to = _dragTo;
    _clearDragState();

    if (axis == null || from == null || to == null || from == to) {
      return;
    }

    final controller = ref.read(gameSessionControllerProvider.notifier);
    if (axis == _DragAxis.row) {
      controller.swapRows(from, to);
    } else {
      controller.swapColumns(from, to);
    }
  }

  void _clearDragState() {
    if (_dragAxis == null && _dragFrom == null && _dragTo == null) {
      return;
    }

    setState(() {
      _dragAxis = null;
      _dragFrom = null;
      _dragTo = null;
    });
  }
}

enum _DragAxis { row, column }

class _InteractionPainter extends CustomPainter {
  const _InteractionPainter({
    required this.geometry,
    required this.state,
    required this.dragAxis,
    required this.dragFrom,
    required this.dragTo,
  });

  final BoardGeometry geometry;
  final GameSessionState state;
  final _DragAxis? dragAxis;
  final int? dragFrom;
  final int? dragTo;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final activePaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.72);
    final focusPaint = Paint()
      ..color = const Color(0xFFF8FAFC).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final handleInset = geometry.handleInset;

    for (var row = 0; row < kBoardSize; row++) {
      final rect = geometry.rowHandleRect(row).deflate(handleInset);
      final paint =
          dragAxis == _DragAxis.row && (row == dragFrom || row == dragTo)
          ? activePaint
          : guidePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        paint,
      );
    }

    for (var column = 0; column < kBoardSize; column++) {
      final rect = geometry.columnHandleRect(column).deflate(handleInset);
      final paint =
          dragAxis == _DragAxis.column &&
              (column == dragFrom || column == dragTo)
          ? activePaint
          : guidePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        paint,
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
    return oldDelegate.dragAxis != dragAxis ||
        oldDelegate.dragFrom != dragFrom ||
        oldDelegate.dragTo != dragTo ||
        oldDelegate.state.selectedRotationCenter !=
            state.selectedRotationCenter ||
        oldDelegate.state.inputLocked != state.inputLocked;
  }
}
