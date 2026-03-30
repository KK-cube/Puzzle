import 'package:shared_preferences/shared_preferences.dart';

abstract class HighScoreRepository {
  Future<int> loadHighScore();

  Future<int> saveIfHigher(int score);
}

class InMemoryHighScoreRepository implements HighScoreRepository {
  InMemoryHighScoreRepository([this._highScore = 0]);

  int _highScore;

  @override
  Future<int> loadHighScore() async => _highScore;

  @override
  Future<int> saveIfHigher(int score) async {
    if (score > _highScore) {
      _highScore = score;
    }
    return _highScore;
  }
}

class SharedPreferencesHighScoreRepository implements HighScoreRepository {
  SharedPreferencesHighScoreRepository(this._preferences);

  static const _highScoreKey = 'line_pulse.high_score';

  final SharedPreferences _preferences;

  @override
  Future<int> loadHighScore() async {
    return _preferences.getInt(_highScoreKey) ?? 0;
  }

  @override
  Future<int> saveIfHigher(int score) async {
    final current = await loadHighScore();
    final next = score > current ? score : current;
    if (next != current) {
      await _preferences.setInt(_highScoreKey, next);
    }
    return next;
  }
}
