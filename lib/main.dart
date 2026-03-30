import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/puzzle_lines_app.dart';
import 'game/application/game_providers.dart';
import 'game/domain/high_score_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        highScoreRepositoryProvider.overrideWithValue(
          SharedPreferencesHighScoreRepository(preferences),
        ),
      ],
      child: const PuzzleLinesApp(),
    ),
  );
}
