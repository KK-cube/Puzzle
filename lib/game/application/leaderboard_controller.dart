import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_repository.dart';

class LeaderboardController
    extends StateNotifier<AsyncValue<List<LeaderboardEntry>>> {
  LeaderboardController({required LeaderboardRepository repository})
    : _repository = repository,
      super(const AsyncValue.loading()) {
    unawaited(refresh(showLoading: true));
  }

  final LeaderboardRepository _repository;

  bool get isEnabled => _repository.isEnabled;

  Future<void> refresh({bool showLoading = false}) async {
    if (!_repository.isEnabled) {
      state = const AsyncValue.data([]);
      return;
    }

    if (showLoading || !state.hasValue) {
      state = const AsyncValue.loading();
    }

    final nextState = await AsyncValue.guard(_repository.fetchTop3);
    if (!mounted) {
      return;
    }
    state = nextState;
  }

  Future<void> submitScore({
    required String playerName,
    required int score,
  }) async {
    if (!_repository.isEnabled) {
      return;
    }

    final trimmedName = playerName.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    await _repository.submitScore(playerName: trimmedName, score: score);
    await refresh();
  }
}
