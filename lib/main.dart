import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/background_music_controller.dart';
import 'app/puzzle_lines_app.dart';
import 'app/supabase_config.dart';
import 'game/application/game_providers.dart';
import 'game/domain/high_score_repository.dart';
import 'game/domain/leaderboard_repository.dart';
import 'game/domain/music_settings_repository.dart';
import 'game/domain/player_nickname_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final musicSettingsRepository = SharedPreferencesMusicSettingsRepository(
    preferences,
  );
  final initialMusicEnabled = await musicSettingsRepository.loadMusicEnabled();
  final leaderboardRepository = await _createLeaderboardRepository();

  runApp(
    ProviderScope(
      overrides: [
        highScoreRepositoryProvider.overrideWithValue(
          SharedPreferencesHighScoreRepository(preferences),
        ),
        playerNicknameRepositoryProvider.overrideWithValue(
          SharedPreferencesPlayerNicknameRepository(preferences),
        ),
        musicSettingsRepositoryProvider.overrideWithValue(
          musicSettingsRepository,
        ),
        leaderboardRepositoryProvider.overrideWithValue(leaderboardRepository),
        backgroundMusicControllerProvider.overrideWithValue(
          AudioBackgroundMusicController(initialEnabled: initialMusicEnabled),
        ),
      ],
      child: const PuzzleLinesApp(),
    ),
  );
}

Future<LeaderboardRepository> _createLeaderboardRepository() async {
  if (!isSupabaseConfigured) {
    return const DisabledLeaderboardRepository();
  }

  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  return SupabaseLeaderboardRepository(Supabase.instance.client);
}
