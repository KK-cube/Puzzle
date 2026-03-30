import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/high_score_repository.dart';
import '../domain/puzzle_engine.dart';
import 'board_animation_bus.dart';
import 'game_session_controller.dart';
import 'game_session_state.dart';

final highScoreRepositoryProvider = Provider<HighScoreRepository>((ref) {
  return InMemoryHighScoreRepository();
});

final puzzleEngineProvider = Provider<PuzzleEngine>((ref) {
  return PuzzleEngine();
});

final boardAnimationBusProvider = Provider<BoardAnimationBus>((ref) {
  final bus = BoardAnimationBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final gameSessionControllerProvider =
    StateNotifierProvider<GameSessionController, GameSessionState>((ref) {
      return GameSessionController(
        engine: ref.watch(puzzleEngineProvider),
        highScoreRepository: ref.watch(highScoreRepositoryProvider),
        animationBus: ref.watch(boardAnimationBusProvider),
      );
    });
