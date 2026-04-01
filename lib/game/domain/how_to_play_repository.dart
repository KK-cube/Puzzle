import 'package:shared_preferences/shared_preferences.dart';

abstract class HowToPlayRepository {
  Future<bool> loadSeenHowToPlay();

  Future<void> saveSeenHowToPlay(bool seen);
}

class InMemoryHowToPlayRepository implements HowToPlayRepository {
  InMemoryHowToPlayRepository([this._seen = false]);

  bool _seen;

  @override
  Future<bool> loadSeenHowToPlay() async => _seen;

  @override
  Future<void> saveSeenHowToPlay(bool seen) async {
    _seen = seen;
  }
}

class SharedPreferencesHowToPlayRepository implements HowToPlayRepository {
  SharedPreferencesHowToPlayRepository(this._preferences);

  static const _seenHowToPlayKey = 'line_pulse.seen_how_to_play';

  final SharedPreferences _preferences;

  @override
  Future<bool> loadSeenHowToPlay() async {
    return _preferences.getBool(_seenHowToPlayKey) ?? false;
  }

  @override
  Future<void> saveSeenHowToPlay(bool seen) async {
    await _preferences.setBool(_seenHowToPlayKey, seen);
  }
}
