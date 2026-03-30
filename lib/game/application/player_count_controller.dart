import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/leaderboard_repository.dart';

class PlayerCountController extends StateNotifier<AsyncValue<int>> {
  PlayerCountController({required LeaderboardRepository repository})
    : _repository = repository,
      super(const AsyncValue.loading()) {
    unawaited(refresh(showLoading: true));
  }

  final LeaderboardRepository _repository;

  Future<void> refresh({bool showLoading = false}) async {
    if (!_repository.isEnabled) {
      state = const AsyncValue.data(0);
      return;
    }

    if (showLoading || !state.hasValue) {
      state = const AsyncValue.loading();
    }

    final nextState = await AsyncValue.guard(_repository.fetchPlayerCount);
    if (!mounted) {
      return;
    }
    state = nextState;
  }
}
