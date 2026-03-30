import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';

class MusicSettingsButton extends ConsumerWidget {
  const MusicSettingsButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicEnabled = ref.watch(musicSettingsControllerProvider);
    final enabled = musicEnabled.valueOrNull ?? true;

    return FilledButton.tonalIcon(
      onPressed: musicEnabled.isLoading
          ? null
          : () => _showSettingsDialog(context, ref, enabled: enabled),
      icon: Icon(
        enabled ? Icons.music_note_rounded : Icons.music_off_rounded,
        size: compact ? 18 : 20,
      ),
      label: Text(enabled ? '音楽 ON' : '音楽 OFF'),
      style: FilledButton.styleFrom(
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 12,
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final musicSettings = ref.read(musicSettingsControllerProvider.notifier);
    final backgroundMusic = ref.read(backgroundMusicControllerProvider);
    var nextEnabled = enabled;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('設定'),
              content: SwitchListTile(
                value: nextEnabled,
                onChanged: (value) async {
                  setState(() => nextEnabled = value);
                  await musicSettings.setEnabled(value);
                  await backgroundMusic.setEnabled(value);
                },
                title: const Text('BGM'),
                subtitle: Text(nextEnabled ? 'ゲーム音楽を再生します' : 'ゲーム音楽を停止します'),
                contentPadding: EdgeInsets.zero,
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
