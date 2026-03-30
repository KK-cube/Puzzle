import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../domain/leaderboard_entry.dart';

class LeaderboardPanel extends ConsumerWidget {
  const LeaderboardPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardControllerProvider);
    final enabled = ref.watch(leaderboardEnabledProvider);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: const Color(0xFFCAD5E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B)),
              Text(
                'ランキング TOP10',
                style: TextStyle(
                  fontSize: compact ? 17 : 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF172033),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? '1プレイごとのスコアがオンラインランキングに記録されます。'
                : 'オンラインランキングを使うには接続設定が必要です。',
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF556273),
            ),
          ),
          const SizedBox(height: 14),
          if (!enabled)
            const _LeaderboardNotice(label: 'オンラインランキングはまだ設定されていません。')
          else
            leaderboard.when(
              data: (entries) => entries.isEmpty
                  ? const _LeaderboardNotice(label: 'まだスコアが登録されていません。')
                  : Column(
                      children: [
                        for (final entry in entries)
                          _LeaderboardRow(entry: entry, compact: compact),
                      ],
                    ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
              error: (_, _) =>
                  const _LeaderboardNotice(label: 'ランキングを一時的に取得できません。'),
            ),
        ],
      ),
    );
  }
}

class _LeaderboardNotice extends StatelessWidget {
  const _LeaderboardNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E1EC)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: Color(0xFF556273),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.compact});

  final LeaderboardEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (entry.rank) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFB45309),
      _ => const Color(0xFF17324D),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E1EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < (compact ? 280 : 250);
          final medal = Container(
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: medalColor,
                fontSize: compact ? 13 : 14,
              ),
            ),
          );
          final name = Text(
            entry.playerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF172033),
            ),
          );
          final score = Text(
            '${entry.score}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF172033),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    medal,
                    const SizedBox(width: 10),
                    Expanded(child: name),
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: score),
              ],
            );
          }

          return Row(
            children: [
              medal,
              SizedBox(width: compact ? 10 : 12),
              Expanded(child: name),
              SizedBox(width: compact ? 10 : 12),
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: compact ? 64 : 72),
                child: score,
              ),
            ],
          );
        },
      ),
    );
  }
}
