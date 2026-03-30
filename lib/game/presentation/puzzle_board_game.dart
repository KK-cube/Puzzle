import 'dart:async';
import 'dart:math' as math;
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
  final List<_ChainCalloutVisual> _callouts = [];
  BoardHint? _hint;
  double _hintElapsed = 0;
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
    if (_hint != null) {
      _hintElapsed += dt;
    }
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
    _callouts.removeWhere((callout) => callout.isFinished);
    for (final callout in _callouts) {
      callout.update(dt);
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
    final hintedTileIds = _hintTileIds(_hint);
    final visuals = _visuals.values.toList()
      ..sort((left, right) => left.opacity.compareTo(right.opacity));
    for (final visual in visuals) {
      if (activeTileIds.contains(visual.tile.id) ||
          hintedTileIds.contains(visual.tile.id)) {
        continue;
      }
      _renderTile(canvas, geometry, visual);
    }
    for (final visual in visuals) {
      if (hintedTileIds.contains(visual.tile.id) &&
          !activeTileIds.contains(visual.tile.id)) {
        _renderTile(canvas, geometry, visual, hint: _hint);
      }
    }
    for (final visual in visuals) {
      if (!activeTileIds.contains(visual.tile.id)) {
        continue;
      }
      _renderTile(canvas, geometry, visual, preview: preview, hint: _hint);
    }
    _renderCallouts(canvas, geometry);
  }

  void setHint(BoardHint? hint) {
    if (identical(_hint, hint)) {
      return;
    }

    _hint = hint;
    _hintElapsed = 0;
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
        _clearTiles(
          event.clearedTileIds,
          clearedPositions: event.clearedPositions,
          chainIndex: event.chainIndex,
          duration: event.duration,
        );
        return;
    }
  }

  void _syncBoard(BoardMatrix board) {
    _currentBoard = cloneBoard(board);
    _visuals.clear();
    _callouts.clear();

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

  void _clearTiles(
    Set<int> tileIds, {
    required Set<BoardPosition> clearedPositions,
    required int chainIndex,
    required Duration duration,
  }) {
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

    if (chainIndex > 1 && clearedPositions.isNotEmpty) {
      _callouts.add(
        _ChainCalloutVisual.fromChain(
          chainIndex: chainIndex,
          clearedPositions: clearedPositions,
        ),
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
    BoardHint? hint,
  }) {
    if (visual.opacity <= 0) {
      return;
    }

    final hintTransform = _hintTransformForTile(visual, hint);
    final horizontalOffset = preview?.axis == BoardDragAxis.column
        ? preview!.offset
        : 0.0 + hintTransform.dx;
    final verticalOffset = preview?.axis == BoardDragAxis.row
        ? preview!.offset
        : 0.0 + hintTransform.dy;
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
    canvas.scale(
      visual.scale * hintTransform.scale,
      visual.scale * hintTransform.scale,
    );
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

  void _renderCallouts(Canvas canvas, BoardGeometry geometry) {
    for (final callout in _callouts) {
      callout.render(canvas, geometry);
    }
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

  Set<int> _hintTileIds(BoardHint? hint) {
    if (hint == null) {
      return const <int>{};
    }

    final move = hint.move;
    switch (move.type) {
      case MoveType.swapRow:
        return {
          for (final row in [move.primaryIndex!, move.secondaryIndex!])
            for (var column = 0; column < kBoardSize; column++)
              _currentBoard[row][column].id,
        };
      case MoveType.swapColumn:
        return {
          for (final column in [move.primaryIndex!, move.secondaryIndex!])
            for (var row = 0; row < kBoardSize; row++)
              _currentBoard[row][column].id,
        };
      case MoveType.rotate3x3:
        final center = move.center!;
        return {
          for (var row = center.row - 1; row <= center.row + 1; row++)
            for (
              var column = center.column - 1;
              column <= center.column + 1;
              column++
            )
              _currentBoard[row][column].id,
        };
    }
  }

  _HintTransform _hintTransformForTile(_TileVisual visual, BoardHint? hint) {
    if (hint == null) {
      return const _HintTransform.none();
    }

    final wobble = math.sin(_hintElapsed * 10) * 3.6;
    final move = hint.move;
    final row = visual.row.round();
    final column = visual.column.round();

    switch (move.type) {
      case MoveType.swapRow:
        if (row == move.primaryIndex) {
          return _HintTransform(dy: wobble, scale: 1.03);
        }
        if (row == move.secondaryIndex) {
          return _HintTransform(dy: -wobble, scale: 1.03);
        }
        return const _HintTransform.none();
      case MoveType.swapColumn:
        if (column == move.primaryIndex) {
          return _HintTransform(dx: wobble, scale: 1.03);
        }
        if (column == move.secondaryIndex) {
          return _HintTransform(dx: -wobble, scale: 1.03);
        }
        return const _HintTransform.none();
      case MoveType.rotate3x3:
        final center = move.center!;
        if ((row - center.row).abs() > 1 ||
            (column - center.column).abs() > 1) {
          return const _HintTransform.none();
        }
        final horizontalDirection = column == center.column
            ? 0.6
            : (column - center.column).sign.toDouble();
        final verticalDirection = row == center.row
            ? 0.4
            : (row - center.row).sign.toDouble();
        return _HintTransform(
          dx: wobble * horizontalDirection,
          dy: wobble * 0.6 * verticalDirection,
          scale: 1.025,
        );
    }
  }
}

class _HintTransform {
  const _HintTransform({this.dx = 0, this.dy = 0, this.scale = 1});

  const _HintTransform.none() : dx = 0, dy = 0, scale = 1;

  final double dx;
  final double dy;
  final double scale;
}

class _ChainCalloutVisual {
  _ChainCalloutVisual({
    required this.anchorRow,
    required this.anchorColumn,
    required this.style,
  });

  factory _ChainCalloutVisual.fromChain({
    required int chainIndex,
    required Set<BoardPosition> clearedPositions,
  }) {
    final rows = clearedPositions.map((position) => position.row).toList();
    final columns = clearedPositions
        .map((position) => position.column)
        .toList();
    final minRow = rows.reduce(math.min).toDouble();
    final averageColumn =
        columns.reduce((left, right) => left + right) / columns.length;
    final horizontalNudge = switch (chainIndex % 3) {
      0 => -0.18,
      1 => 0.18,
      _ => 0.0,
    };

    return _ChainCalloutVisual(
      anchorRow: (minRow - 0.52).clamp(0.1, kBoardSize - 1.2),
      anchorColumn: (averageColumn + horizontalNudge).clamp(
        0.2,
        kBoardSize - 1.2,
      ),
      style: _ChainCalloutStyle.forChain(chainIndex),
    );
  }

  static const _duration = 0.92;

  final double anchorRow;
  final double anchorColumn;
  final _ChainCalloutStyle style;
  double _elapsed = 0;

  bool get isFinished => _elapsed >= _duration;

  void update(double dt) {
    _elapsed += dt;
  }

  void render(Canvas canvas, BoardGeometry geometry) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform((progress / 0.36).clamp(0.0, 1.0));
    final lift =
        Curves.easeOutCubic.transform(progress) * geometry.cellSize * 0.42;
    final fade = progress < 0.72 ? 1.0 : 1 - ((progress - 0.72) / 0.28);
    final scale = ui.lerpDouble(0.72, 1.0, pop) ?? 1.0;
    final center = Offset(
      geometry.boardRect.left + ((anchorColumn + 0.5) * geometry.cellSize),
      geometry.boardRect.top + ((anchorRow + 0.5) * geometry.cellSize) - lift,
    );

    final textStyle = TextStyle(
      fontSize: geometry.cellSize * 0.24,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
      foreground: Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(geometry.cellSize * 2.4, geometry.cellSize),
          [
            for (final color in style.gradientColors)
              color.withValues(alpha: fade.clamp(0.0, 1.0)),
          ],
        ),
      shadows: [
        Shadow(
          color: style.shadowColor.withValues(alpha: fade * 0.5),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
    final painter = TextPainter(
      text: TextSpan(text: style.label, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-painter.width / 2, -painter.height / 2);

    final chipRect = Rect.fromLTWH(
      -10,
      -4,
      painter.width + 20,
      painter.height + 8,
    );
    final chipPaint = Paint()
      ..color = style.backdropColor.withValues(alpha: fade * 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(999)),
      chipPaint,
    );

    final sparklePaint = Paint()
      ..color = style.sparkleColor.withValues(alpha: fade * 0.85);
    canvas.drawCircle(Offset(0, painter.height * 0.16), 2.2, sparklePaint);
    canvas.drawCircle(
      Offset(chipRect.right - 4, painter.height * 0.62),
      1.8,
      sparklePaint,
    );
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

class _ChainCalloutStyle {
  const _ChainCalloutStyle({
    required this.label,
    required this.gradientColors,
    required this.shadowColor,
    required this.backdropColor,
    required this.sparkleColor,
  });

  factory _ChainCalloutStyle.forChain(int chainIndex) {
    if (chainIndex >= 5) {
      return const _ChainCalloutStyle(
        label: 'PERFECT!',
        gradientColors: [
          Color(0xFFFFF08A),
          Color(0xFFFF9A62),
          Color(0xFFFF4D8D),
        ],
        shadowColor: Color(0xFFB45309),
        backdropColor: Color(0xFFFFEDD5),
        sparkleColor: Color(0xFFFFF4A3),
      );
    }
    if (chainIndex == 4) {
      return const _ChainCalloutStyle(
        label: 'PERFECT!',
        gradientColors: [
          Color(0xFFFFD166),
          Color(0xFFFF7A59),
          Color(0xFFA855F7),
        ],
        shadowColor: Color(0xFF9A3412),
        backdropColor: Color(0xFFFFF7D6),
        sparkleColor: Color(0xFFFFD166),
      );
    }
    if (chainIndex == 3) {
      return const _ChainCalloutStyle(
        label: 'EXCELLENT!',
        gradientColors: [
          Color(0xFF7DD3FC),
          Color(0xFF60A5FA),
          Color(0xFFA855F7),
        ],
        shadowColor: Color(0xFF3730A3),
        backdropColor: Color(0xFFE0F2FE),
        sparkleColor: Color(0xFFBAE6FD),
      );
    }
    return const _ChainCalloutStyle(
      label: 'GREAT!',
      gradientColors: [Color(0xFF4ADE80), Color(0xFF2DD4BF), Color(0xFF22D3EE)],
      shadowColor: Color(0xFF0F766E),
      backdropColor: Color(0xFFDCFCE7),
      sparkleColor: Color(0xFF86EFAC),
    );
  }

  final String label;
  final List<Color> gradientColors;
  final Color shadowColor;
  final Color backdropColor;
  final Color sparkleColor;
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
