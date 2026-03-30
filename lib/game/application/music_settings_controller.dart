import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/music_settings_repository.dart';

class MusicSettingsController extends StateNotifier<AsyncValue<bool>> {
  MusicSettingsController({required MusicSettingsRepository repository})
    : _repository = repository,
      super(const AsyncValue.loading()) {
    _load();
  }

  final MusicSettingsRepository _repository;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadMusicEnabled);
  }

  Future<void> setEnabled(bool enabled) async {
    await _repository.saveMusicEnabled(enabled);
    state = AsyncValue.data(enabled);
  }
}
