import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/puzzle_lines_app.dart';
import 'app/supabase_config.dart';
import 'game/application/game_providers.dart';
import 'game/domain/high_score_repository.dart';
import 'game/domain/leaderboard_repository.dart';
import 'game/domain/player_nickname_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
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
        leaderboardRepositoryProvider.overrideWithValue(leaderboardRepository),
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
