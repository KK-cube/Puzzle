import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/how_to_play_repository.dart';

class HowToPlayController extends StateNotifier<AsyncValue<bool>> {
  HowToPlayController({required HowToPlayRepository repository})
    : _repository = repository,
      super(const AsyncValue.loading()) {
    _load();
  }

  final HowToPlayRepository _repository;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadSeenHowToPlay);
  }

  Future<void> markSeen() async {
    await _repository.saveSeenHowToPlay(true);
    state = const AsyncValue.data(true);
  }
}
