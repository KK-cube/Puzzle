import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/background_music_controller.dart';
import '../domain/high_score_repository.dart';
import '../domain/how_to_play_repository.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_repository.dart';
import '../domain/music_settings_repository.dart';
import '../domain/player_nickname_repository.dart';
import '../domain/puzzle_engine.dart';
import 'board_animation_bus.dart';
import 'game_session_controller.dart';
import 'game_session_state.dart';
import 'how_to_play_controller.dart';
import 'leaderboard_controller.dart';
import 'music_settings_controller.dart';
import 'player_nickname_controller.dart';
import 'player_count_controller.dart';

final highScoreRepositoryProvider = Provider<HighScoreRepository>((ref) {
  return InMemoryHighScoreRepository();
});

final playerNicknameRepositoryProvider = Provider<PlayerNicknameRepository>((
  ref,
) {
  return InMemoryPlayerNicknameRepository();
});

final musicSettingsRepositoryProvider = Provider<MusicSettingsRepository>((
  ref,
) {
  return InMemoryMusicSettingsRepository();
});

final howToPlayRepositoryProvider = Provider<HowToPlayRepository>((ref) {
  return InMemoryHowToPlayRepository();
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return const DisabledLeaderboardRepository();
});

final puzzleEngineProvider = Provider<PuzzleEngine>((ref) {
  return PuzzleEngine();
});

final boardAnimationBusProvider = Provider<BoardAnimationBus>((ref) {
  final bus = BoardAnimationBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final backgroundMusicControllerProvider = Provider<BackgroundMusicController>((
  ref,
) {
  final controller = AudioBackgroundMusicController();
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

final playerNicknameControllerProvider =
    StateNotifierProvider<PlayerNicknameController, AsyncValue<String?>>((ref) {
      return PlayerNicknameController(
        repository: ref.watch(playerNicknameRepositoryProvider),
      );
    });

final musicSettingsControllerProvider =
    StateNotifierProvider<MusicSettingsController, AsyncValue<bool>>((ref) {
      return MusicSettingsController(
        repository: ref.watch(musicSettingsRepositoryProvider),
      );
    });

final howToPlayControllerProvider =
    StateNotifierProvider<HowToPlayController, AsyncValue<bool>>((ref) {
      return HowToPlayController(
        repository: ref.watch(howToPlayRepositoryProvider),
      );
    });

final leaderboardEnabledProvider = Provider<bool>((ref) {
  return ref.watch(leaderboardRepositoryProvider).isEnabled;
});

final leaderboardControllerProvider =
    StateNotifierProvider<
      LeaderboardController,
      AsyncValue<List<LeaderboardEntry>>
    >((ref) {
      return LeaderboardController(
        repository: ref.watch(leaderboardRepositoryProvider),
      );
    });

final playerCountControllerProvider =
    StateNotifierProvider<PlayerCountController, AsyncValue<int>>((ref) {
      return PlayerCountController(
        repository: ref.watch(leaderboardRepositoryProvider),
      );
    });

final gameSessionControllerProvider =
    StateNotifierProvider<GameSessionController, GameSessionState>((ref) {
      return GameSessionController(
        engine: ref.watch(puzzleEngineProvider),
        highScoreRepository: ref.watch(highScoreRepositoryProvider),
        animationBus: ref.watch(boardAnimationBusProvider),
      );
    });
