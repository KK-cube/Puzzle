import 'package:shared_preferences/shared_preferences.dart';

abstract class MusicSettingsRepository {
  Future<bool> loadMusicEnabled();

  Future<void> saveMusicEnabled(bool enabled);
}

class InMemoryMusicSettingsRepository implements MusicSettingsRepository {
  InMemoryMusicSettingsRepository([this._enabled = true]);

  bool _enabled;

  @override
  Future<bool> loadMusicEnabled() async => _enabled;

  @override
  Future<void> saveMusicEnabled(bool enabled) async {
    _enabled = enabled;
  }
}

class SharedPreferencesMusicSettingsRepository
    implements MusicSettingsRepository {
  SharedPreferencesMusicSettingsRepository(this._preferences);

  static const _musicEnabledKey = 'line_pulse.music_enabled';

  final SharedPreferences _preferences;

  @override
  Future<bool> loadMusicEnabled() async {
    return _preferences.getBool(_musicEnabledKey) ?? true;
  }

  @override
  Future<void> saveMusicEnabled(bool enabled) async {
    await _preferences.setBool(_musicEnabledKey, enabled);
  }
}
