import 'package:shared_preferences/shared_preferences.dart';

abstract class PlayerNicknameRepository {
  Future<String?> loadNickname();

  Future<void> saveNickname(String nickname);
}

class InMemoryPlayerNicknameRepository implements PlayerNicknameRepository {
  InMemoryPlayerNicknameRepository([this._nickname]);

  String? _nickname;

  @override
  Future<String?> loadNickname() async => _nickname;

  @override
  Future<void> saveNickname(String nickname) async {
    _nickname = nickname;
  }
}

class SharedPreferencesPlayerNicknameRepository
    implements PlayerNicknameRepository {
  SharedPreferencesPlayerNicknameRepository(this._preferences);

  static const _nicknameKey = 'line_pulse.player_nickname';

  final SharedPreferences _preferences;

  @override
  Future<String?> loadNickname() async {
    final nickname = _preferences.getString(_nicknameKey)?.trim();
    if (nickname == null || nickname.isEmpty) {
      return null;
    }
    return nickname;
  }

  @override
  Future<void> saveNickname(String nickname) async {
    await _preferences.setString(_nicknameKey, nickname.trim());
  }
}
