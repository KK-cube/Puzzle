import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/board_animation_bus.dart';
import '../domain/models.dart';
import 'board_drag_preview.dart';
import 'board_geometry.dart';
import 'tile_palette.dart';

class PuzzleBoardGame extends FlameGame {
  PuzzleBoardGame({
    required this.animationBus,
    required BoardMatrix initialBoard,
    required this.dragPreview,
  }) : _currentBoard = cloneBoard(initialBoard);

  final BoardAnimationBus animationBus;
  final ValueListenable<BoardDragPreview?> dragPreview;
  final Map<int, _TileVisual> _visuals = {};
  BoardMatrix _currentBoard;
  StreamSubscription<BoardAnimationEvent>? _subscription;

  @override
  Future<void> onLoad() async {
    _syncBoard(_currentBoard);
    _subscription = animationBus.stream.listen(_handleEvent);
  }

  @override
  void onRemove() {
    _subscription?.cancel();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final toRemove = <int>[];
    for (final entry in _visuals.entries) {
      entry.value.update(dt);
      if (entry.value.removeWhenFinished && entry.value.isSettledInvisible) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _visuals.remove(id);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final geometry = BoardGeometry(ui.Size(size.x, size.y));
    _renderBackdrop(canvas, geometry);
    _renderCells(canvas, geometry);

    final preview = dragPreview.value;
    final activeTileIds = _activeTileIds(preview);
    final visuals = _visuals.values.toList()
      ..sort((left, right) => left.opacity.compareTo(right.opacity));
    for (final visual in visuals) {
      if (activeTileIds.contains(visual.tile.id)) {
        continue;
      }
      _renderTile(canvas, geometry, visual);
    }
    for (final visual in visuals) {
      if (!activeTileIds.contains(visual.tile.id)) {
        continue;
      }
      _renderTile(canvas, geometry, visual, preview: preview);
    }
  }

  void _handleEvent(BoardAnimationEvent event) {
    switch (event.kind) {
      case BoardAnimationKind.sync:
        _syncBoard(event.board);
        return;
      case BoardAnimationKind.transition:
        _transitionToBoard(
          event.board,
          duration: event.duration,
          spawnFromTop: event.spawnFromTop,
        );
        return;
      case BoardAnimationKind.clear:
        _clearTiles(event.clearedTileIds, duration: event.duration);
        return;
    }
  }

  void _syncBoard(BoardMatrix board) {
    _currentBoard = cloneBoard(board);
    _visuals.clear();

    for (var row = 0; row < kBoardSize; row++) {
      for (var column = 0; column < kBoardSize; column++) {
        final tile = board[row][column];
        _visuals[tile.id] = _TileVisual(
          tile: tile,
          row: row.toDouble(),
          column: column.toDouble(),
        );
      }
    }
  }

  void _transitionToBoard(
    BoardMatrix board, {
    required Duration duration,
    required bool spawnFromTop,
  }) {
    final nextBoard = cloneBoard(board);
    final nextPositions = <int, BoardPosition>{};
    for (var row = 0; row < kBoardSize; row++) {
      for (var column = 0; column < kBoardSize; column++) {
        nextPositions[nextBoard[row][column].id] = BoardPosition(row, column);
      }
    }

    for (final entry in nextPositions.entries) {
      final existing = _visuals[entry.key];
      if (existing != null) {
        existing.animateTo(
          row: entry.value.row.toDouble(),
          column: entry.value.column.toDouble(),
          duration: duration,
          scale: 1,
          opacity: 1,
        );
      } else {
        final tile = nextBoard[entry.value.row][entry.value.column];
        final startRow = spawnFromTop
            ? entry.value.row.toDouble() - 1.4
            : entry.value.row.toDouble();
        _visuals[tile.id] =
            _TileVisual(
              tile: tile,
              row: startRow,
              column: entry.value.column.toDouble(),
              scale: spawnFromTop ? 0.86 : 1,
              opacity: spawnFromTop ? 0.4 : 1,
            )..animateTo(
              row: entry.value.row.toDouble(),
              column: entry.value.column.toDouble(),
              duration: duration,
              scale: 1,
              opacity: 1,
            );
      }
    }

    final nextIds = nextPositions.keys.toSet();
    final staleIds = _visuals.keys
        .where((id) => !nextIds.contains(id))
        .toList();
    for (final id in staleIds) {
      final visual = _visuals[id];
      if (visual != null && visual.isSettledInvisible) {
        _visuals.remove(id);
      }
    }

    _currentBoard = nextBoard;
  }

  void _clearTiles(Set<int> tileIds, {required Duration duration}) {
    for (final tileId in tileIds) {
      final visual = _visuals[tileId];
      if (visual == null) {
        continue;
      }

      visual.animateTo(
        row: visual.row,
        column: visual.column,
        duration: duration,
        scale: 0.16,
        opacity: 0,
        removeWhenFinished: true,
      );
    }
  }

  void _renderBackdrop(Canvas canvas, BoardGeometry geometry) {
    final panelRect = Rect.fromLTWH(
      geometry.origin.dx,
      geometry.origin.dy,
      geometry.boardSize,
      geometry.boardSize,
    );
    final panelPaint = Paint()
      ..shader = ui.Gradient.linear(
        panelRect.topLeft,
        panelRect.bottomRight,
        const [Color(0xFF17324D), Color(0xFF0F4C5C), Color(0xFFF59E0B)],
        const [0.0, 0.52, 1.0],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(28)),
      panelPaint,
    );

    final innerPaint = Paint()
      ..color = const Color(0xFFF8F4EB).withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect.deflate(12), const Radius.circular(24)),
      innerPaint,
    );
  }

  void _renderCells(Canvas canvas, BoardGeometry geometry) {
    final boardPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(geometry.boardRect, const Radius.circular(24)),
      boardPaint,
    );

    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (var row = 0; row < kBoardSize; row++) {
      for (var column = 0; column < kBoardSize; column++) {
        final cellRect = geometry.cellRect(row, column).deflate(3.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect, const Radius.circular(16)),
          gridPaint,
        );
      }
    }
  }

  void _renderTile(
    Canvas canvas,
    BoardGeometry geometry,
    _TileVisual visual, {
    BoardDragPreview? preview,
  }) {
    if (visual.opacity <= 0) {
      return;
    }

    final horizontalOffset = preview?.axis == BoardDragAxis.column
        ? preview!.offset
        : 0.0;
    final verticalOffset = preview?.axis == BoardDragAxis.row
        ? preview!.offset
        : 0.0;
    final rect = Rect.fromLTWH(
      geometry.boardRect.left +
          (visual.column * geometry.cellSize) +
          horizontalOffset +
          6,
      geometry.boardRect.top +
          (visual.row * geometry.cellSize) +
          verticalOffset +
          6,
      geometry.cellSize - 12,
      geometry.cellSize - 12,
    );
    final center = rect.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(visual.scale, visual.scale);
    canvas.translate(-center.dx, -center.dy);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: visual.opacity * 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 4)),
        const Radius.circular(18),
      ),
      shadowPaint,
    );

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
        visual.tile.color.fillColor.withValues(alpha: visual.opacity),
        visual.tile.color.edgeColor.withValues(alpha: visual.opacity),
      ]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      fillPaint,
    );

    final gleamPaint = Paint()
      ..color = Colors.white.withValues(alpha: visual.opacity * 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(14)),
      gleamPaint,
    );
    canvas.restore();
  }

  Set<int> _activeTileIds(BoardDragPreview? preview) {
    if (preview == null) {
      return const <int>{};
    }

    if (preview.axis == BoardDragAxis.row) {
      return {
        for (var column = 0; column < kBoardSize; column++)
          _currentBoard[preview.sourceIndex][column].id,
      };
    }

    return {
      for (var row = 0; row < kBoardSize; row++)
        _currentBoard[row][preview.sourceIndex].id,
    };
  }
}

class _TileVisual {
  _TileVisual({
    required this.tile,
    required this.row,
    required this.column,
    this.scale = 1,
    this.opacity = 1,
  }) : _fromRow = row,
       _toRow = row,
       _fromColumn = column,
       _toColumn = column,
       _fromScale = scale,
       _toScale = scale,
       _fromOpacity = opacity,
       _toOpacity = opacity;

  final Tile tile;
  double row;
  double column;
  double scale;
  double opacity;

  double _fromRow;
  double _toRow;
  double _fromColumn;
  double _toColumn;
  double _fromScale;
  double _toScale;
  double _fromOpacity;
  double _toOpacity;
  double _elapsed = 0;
  double _duration = 0;
  bool removeWhenFinished = false;

  bool get isSettledInvisible => _duration <= 0 && opacity <= 0.01;

  void animateTo({
    required double row,
    required double column,
    required Duration duration,
    required double scale,
    required double opacity,
    bool removeWhenFinished = false,
  }) {
    _fromRow = this.row;
    _fromColumn = this.column;
    _toRow = row;
    _toColumn = column;
    _fromScale = this.scale;
    _toScale = scale;
    _fromOpacity = this.opacity;
    _toOpacity = opacity;
    _elapsed = 0;
    _duration = duration.inMilliseconds / Duration.millisecondsPerSecond;
    this.removeWhenFinished = removeWhenFinished;
    if (_duration == 0) {
      this.row = row;
      this.column = column;
      this.scale = scale;
      this.opacity = opacity;
    }
  }

  void update(double dt) {
    if (_duration <= 0) {
      return;
    }

    _elapsed += dt;
    final progress = (_elapsed / _duration).clamp(0.0, 1.0).toDouble();
    final eased = Curves.easeInOutCubic.transform(progress);
    row = ui.lerpDouble(_fromRow, _toRow, eased) ?? _toRow;
    column = ui.lerpDouble(_fromColumn, _toColumn, eased) ?? _toColumn;
    scale = ui.lerpDouble(_fromScale, _toScale, eased) ?? _toScale;
    opacity = ui.lerpDouble(_fromOpacity, _toOpacity, eased) ?? _toOpacity;
    if (progress >= 1) {
      _duration = 0;
    }
  }
}
