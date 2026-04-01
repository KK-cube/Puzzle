import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../application/game_session_state.dart';
import '../widgets/leaderboard_panel.dart';
import '../widgets/music_settings_button.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameSessionControllerProvider);
    final controller = ref.read(gameSessionControllerProvider.notifier);
    final backgroundMusic = ref.read(backgroundMusicControllerProvider);
    final title = switch (state.runEndReason) {
      RunEndReason.timeUp => 'タイムアップ',
      _ => '手詰まり',
    };
    final subtitle = switch (state.runEndReason) {
      RunEndReason.timeUp => '残り時間が 0 になりました。すばやく連鎖して、消去ボーナスで時間を伸ばしましょう。',
      _ => '盤面が安定し、入れ替えで消せる手がなくなりました。',
    };

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF17324D), Color(0xFF0F766E), Color(0xFFF5D08A)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: MusicSettingsButton(compact: true),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF172033),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Color(0xFF556273),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _ScoreTile(
                            label: '今回のスコア',
                            value: '${state.lastRunScore}',
                          ),
                          const SizedBox(height: 14),
                          _ScoreTile(
                            label: 'ベストスコア',
                            value: '${state.bestScore}',
                          ),
                          const SizedBox(height: 14),
                          const LeaderboardPanel(compact: true),
                          const SizedBox(height: 28),
                          FilledButton.icon(
                            onPressed: () async {
                              controller.startNewGame();
                              unawaited(backgroundMusic.ensurePlaying());
                            },
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('もう一度'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: controller.returnToTitle,
                            icon: const Icon(Icons.home_rounded),
                            label: const Text('タイトルへ'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD4DEE8)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF556273),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }
}
