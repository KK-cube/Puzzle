import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const kBackgroundMusicAsset = 'WEARETHEGOOD - Live in the Moment.mp3';

abstract class BackgroundMusicController {
  bool get isEnabled;

  Future<void> ensurePlaying();

  Future<void> setEnabled(bool enabled);

  Future<void> dispose();
}

class AudioBackgroundMusicController
    with WidgetsBindingObserver
    implements BackgroundMusicController {
  AudioBackgroundMusicController({
    AudioPlayer? player,
    bool initialEnabled = true,
  }) : _player = player ?? AudioPlayer(),
       _enabled = initialEnabled {
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  final AudioPlayer _player;
  bool _enabled;
  bool _started = false;
  bool _resumeOnForeground = false;
  bool _disposed = false;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> ensurePlaying() async {
    if (_disposed || !_enabled) {
      return;
    }

    try {
      _resumeOnForeground = true;
      if (_started) {
        if (_player.state != PlayerState.playing) {
          await _player.resume();
        }
        return;
      }

      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.38);
      await _player.setSourceAsset(kBackgroundMusicAsset);
      await _player.resume();
      _started = true;
    } catch (_) {
      // Ignore playback failures so the game stays playable if audio is blocked.
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) {
      return;
    }

    _enabled = enabled;
    if (!_enabled) {
      _resumeOnForeground = false;
      try {
        if (_player.state == PlayerState.playing) {
          await _player.pause();
        }
      } catch (_) {
        // Ignore audio teardown failures so toggling stays responsive.
      }
      return;
    }

    await ensurePlaying();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !_started || !_enabled || kIsWeb) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_resumeOnForeground) {
        unawaited(ensurePlaying());
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _resumeOnForeground = _player.state == PlayerState.playing;
      unawaited(_player.pause());
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    await _player.dispose();
  }
}

class SilentBackgroundMusicController implements BackgroundMusicController {
  SilentBackgroundMusicController({this.enabled = true});

  bool enabled;

  @override
  bool get isEnabled => enabled;

  @override
  Future<void> ensurePlaying() async {}

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
  }

  @override
  Future<void> dispose() async {}
}
