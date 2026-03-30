import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../application/player_nickname_controller.dart';
import '../widgets/leaderboard_panel.dart';
import '../widgets/music_settings_button.dart';

class TitleScreen extends ConsumerWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameSessionControllerProvider);
    final nickname = ref.watch(playerNicknameControllerProvider);
    final playerCount = ref.watch(playerCountControllerProvider);
    final leaderboardEnabled = ref.watch(leaderboardEnabledProvider);
    final controller = ref.read(gameSessionControllerProvider.notifier);
    final nicknameController = ref.read(
      playerNicknameControllerProvider.notifier,
    );
    final backgroundMusic = ref.read(backgroundMusicControllerProvider);

    Future<void> handleStart() async {
      final resolvedNickname = nickname.valueOrNull;
      final readyNickname = resolvedNickname == null || resolvedNickname.isEmpty
          ? await _promptForNickname(
              context,
              nicknameController,
              initialValue: resolvedNickname,
            )
          : resolvedNickname;
      if (!context.mounted || readyNickname == null) {
        return;
      }

      controller.startNewGame();
      unawaited(backgroundMusic.ensurePlaying());
    }

    Future<void> handleEditNickname() async {
      await _promptForNickname(
        context,
        nicknameController,
        initialValue: nickname.valueOrNull,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7E7C6), Color(0xFFF0F4EF), Color(0xFFD7E6F5)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackedHeader = constraints.maxWidth < 430;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stackedHeader)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17324D),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Flutter + Flame パズル',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: MusicSettingsButton(),
                              ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17324D),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Flutter + Flame パズル',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const MusicSettingsButton(),
                            ],
                          ),
                        const SizedBox(height: 22),
                        const Text(
                          'ラインパルス',
                          style: TextStyle(
                            fontSize: 52,
                            height: 0.94,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '30秒で挑戦。牌を直接ドラッグして行や列を入れ替え、連鎖と大きな消去で時間を伸ばしましょう。',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.4,
                            color: Color(0xFF314155),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _StartRunPanel(
                          nickname: nickname,
                          playerCount: playerCount,
                          leaderboardEnabled: leaderboardEnabled,
                          onPressed: handleStart,
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _InfoCard(
                              label: 'ベスト',
                              value: '${state.bestScore}',
                            ),
                            const _InfoCard(label: '時間', value: '30秒'),
                            const _InfoCard(label: '盤面', value: '7 x 7'),
                            const _InfoCard(label: '回転', value: '10回/プレイ'),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _NicknamePanel(
                          nickname: nickname,
                          onEdit: handleEditNickname,
                        ),
                        const SizedBox(height: 18),
                        const LeaderboardPanel(),
                        const SizedBox(height: 18),
                        const Text(
                          '3つ消すと +0.5秒、1回の消去で 4つ以上消すと +1秒。回転は左右のボタンでランダムな 3x3 エリアに使えます。',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF556273),
                          ),
                        ),
                      ],
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

  Future<String?> _promptForNickname(
    BuildContext context,
    PlayerNicknameController controller, {
    String? initialValue,
  }) async {
    final textController = TextEditingController(text: initialValue ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('ニックネームを入力'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: textController,
              autofocus: true,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: 'ニックネーム',
                hintText: '表示名を入力',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return '開始するにはニックネームを入力してください。';
                }
                if (trimmed.length > 24) {
                  return '24文字以内で入力してください。';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(textController.text.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('あとで'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(textController.text.trim());
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    textController.dispose();
    if (result == null || result.isEmpty) {
      return null;
    }

    await controller.saveNickname(result);
    return result;
  }
}

class _StartRunPanel extends StatelessWidget {
  const _StartRunPanel({
    required this.nickname,
    required this.playerCount,
    required this.leaderboardEnabled,
    required this.onPressed,
  });

  final AsyncValue<String?> nickname;
  final AsyncValue<int> playerCount;
  final bool leaderboardEnabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final hasNickname = (nickname.valueOrNull ?? '').trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17324D),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17324D).withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: nickname.isLoading ? null : onPressed,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(hasNickname ? 'ゲーム開始' : '名前を決めて開始'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(62),
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF172033),
              textStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PlayerCountBadge(
            playerCount: playerCount,
            leaderboardEnabled: leaderboardEnabled,
          ),
        ],
      ),
    );
  }
}

class _PlayerCountBadge extends StatelessWidget {
  const _PlayerCountBadge({
    required this.playerCount,
    required this.leaderboardEnabled,
  });

  final AsyncValue<int> playerCount;
  final bool leaderboardEnabled;

  @override
  Widget build(BuildContext context) {
    final label = !leaderboardEnabled
        ? '累計プレイ数は未接続'
        : playerCount.when(
            data: (count) => '累計 $count プレイ',
            loading: () => '累計プレイ数を読み込み中...',
            error: (_, _) => '累計プレイ数を取得できません',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NicknamePanel extends StatelessWidget {
  const _NicknamePanel({required this.nickname, required this.onEdit});

  final AsyncValue<String?> nickname;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final resolvedNickname = nickname.valueOrNull;
    final hasNickname =
        resolvedNickname != null && resolvedNickname.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCAD5E2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 360;
          final infoColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ニックネーム',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5F6C7B),
                ),
              ),
              const SizedBox(height: 8),
              if (nickname.isLoading)
                const Text(
                  '読み込み中...',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                )
              else
                Text(
                  hasNickname ? resolvedNickname : '未設定',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: hasNickname
                        ? const Color(0xFF172033)
                        : const Color(0xFFB45309),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                hasNickname
                    ? 'この名前でランキングにスコアが送信されます。'
                    : 'プレイ前に名前を設定しておくと、あとでスコアを送信できます。',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF556273),
                ),
              ),
            ],
          );
          final actionButton = OutlinedButton.icon(
            onPressed: nickname.isLoading ? null : onEdit,
            icon: Icon(
              hasNickname ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
            ),
            label: Text(hasNickname ? '変更' : '設定'),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [infoColumn, const SizedBox(height: 14), actionButton],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: infoColumn),
              const SizedBox(width: 16),
              actionButton,
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCAD5E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5F6C7B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }
}
