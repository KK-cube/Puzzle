import 'dart:async';

import '../domain/models.dart';

enum BoardAnimationKind { sync, transition, clear }

class BoardAnimationEvent {
  const BoardAnimationEvent._({
    required this.kind,
    required this.board,
    required this.duration,
    this.clearedTileIds = const <int>{},
    this.spawnFromTop = false,
  });

  factory BoardAnimationEvent.sync(BoardMatrix board) {
    return BoardAnimationEvent._(
      kind: BoardAnimationKind.sync,
      board: cloneBoard(board),
      duration: Duration.zero,
    );
  }

  factory BoardAnimationEvent.transition(
    BoardMatrix board, {
    required Duration duration,
    bool spawnFromTop = false,
  }) {
    return BoardAnimationEvent._(
      kind: BoardAnimationKind.transition,
      board: cloneBoard(board),
      duration: duration,
      spawnFromTop: spawnFromTop,
    );
  }

  factory BoardAnimationEvent.clear(
    BoardMatrix board, {
    required Set<int> clearedTileIds,
    required Duration duration,
  }) {
    return BoardAnimationEvent._(
      kind: BoardAnimationKind.clear,
      board: cloneBoard(board),
      duration: duration,
      clearedTileIds: clearedTileIds,
    );
  }

  final BoardAnimationKind kind;
  final BoardMatrix board;
  final Duration duration;
  final Set<int> clearedTileIds;
  final bool spawnFromTop;
}

class BoardAnimationBus {
  final _controller = StreamController<BoardAnimationEvent>.broadcast();

  Stream<BoardAnimationEvent> get stream => _controller.stream;

  void emit(BoardAnimationEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}
