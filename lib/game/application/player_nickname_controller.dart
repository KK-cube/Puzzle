import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_nickname_repository.dart';

class PlayerNicknameController extends StateNotifier<AsyncValue<String?>> {
  PlayerNicknameController({required PlayerNicknameRepository repository})
    : _repository = repository,
      super(const AsyncValue.loading()) {
    _load();
  }

  final PlayerNicknameRepository _repository;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadNickname);
  }

  Future<void> saveNickname(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    await _repository.saveNickname(trimmed);
    state = AsyncValue.data(trimmed);
  }
}
