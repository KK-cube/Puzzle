import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/application/game_providers.dart';
import '../game/application/game_session_state.dart';
import '../game/presentation/screens/game_screen.dart';
import '../game/presentation/screens/result_screen.dart';
import '../game/presentation/screens/title_screen.dart';

class PuzzleLinesApp extends ConsumerWidget {
  const PuzzleLinesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<GameSessionState>(gameSessionControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.phase == GamePhase.result ||
          next.phase != GamePhase.result) {
        return;
      }

      final nickname = ref.read(playerNicknameControllerProvider).valueOrNull;
      if (nickname == null || nickname.trim().isEmpty) {
        return;
      }

      unawaited(
        ref
            .read(leaderboardControllerProvider.notifier)
            .submitScore(playerName: nickname, score: next.lastRunScore),
      );
    });

    final state = ref.watch(gameSessionControllerProvider);
    final screen = switch (state.phase) {
      GamePhase.title => const TitleScreen(),
      GamePhase.playing || GamePhase.resolving => const GameScreen(),
      GamePhase.result => const ResultScreen(),
    };
    final screenKey = switch (state.phase) {
      GamePhase.title => 'title',
      GamePhase.playing || GamePhase.resolving => 'game',
      GamePhase.result => 'result',
    };

    return MaterialApp(
      title: 'ラインパルス',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.light,
            ).copyWith(
              surface: const Color(0xFFF6F3EC),
              onSurface: const Color(0xFF1B2533),
              primary: const Color(0xFF0F766E),
              secondary: const Color(0xFFF97316),
            ),
        scaffoldBackgroundColor: const Color(0xFFF2EFE8),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: const Color(0xFF1B2533),
          displayColor: const Color(0xFF1B2533),
        ),
      ),
      home: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(screenKey), child: screen),
        ),
      ),
    );
  }
}
