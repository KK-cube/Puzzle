import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_providers.dart';
import '../application/game_session_state.dart';
import 'board_drag_preview.dart';
import 'board_interaction_overlay.dart';
import 'puzzle_board_game.dart';

class PuzzleBoardStage extends ConsumerStatefulWidget {
  const PuzzleBoardStage({super.key, required this.state});

  final GameSessionState state;

  @override
  ConsumerState<PuzzleBoardStage> createState() => _PuzzleBoardStageState();
}

class _PuzzleBoardStageState extends ConsumerState<PuzzleBoardStage> {
  late final PuzzleBoardGame _game;
  late final ValueNotifier<BoardDragPreview?> _dragPreview;

  @override
  void initState() {
    super.initState();
    _dragPreview = ValueNotifier<BoardDragPreview?>(null);
    _game = PuzzleBoardGame(
      animationBus: ref.read(boardAnimationBusProvider),
      initialBoard: widget.state.board,
      dragPreview: _dragPreview,
    );
  }

  @override
  void dispose() {
    _dragPreview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 26,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GameWidget(game: _game),
                    BoardInteractionOverlay(
                      state: widget.state,
                      dragPreview: _dragPreview,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
