import 'package:audioplayers/audioplayers.dart';

/// Named sound effects.
enum Sfx { jump, coin, egg, hatch, hit, gameOver, button, reward }

/// Which looping music track is playing.
enum MusicTrack { none, menu, game }

/// Central audio controller. Plays a single looping music track plus a small
/// pool of one-shot SFX players. Honours the player's sound / music settings
/// and fails silently if a platform can't play audio.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  static const String _menuMusic = 'audio/menumusic.mp3';
  static const String _gameMusic = 'audio/gamemusic.mp3';

  static const Map<Sfx, String> _sfxAsset = {
    Sfx.jump: 'audio/sfx_jump.wav',
    Sfx.coin: 'audio/sfx_coin.wav',
    Sfx.egg: 'audio/sfx_egg.wav',
    Sfx.hatch: 'audio/sfx_hatch.wav',
    Sfx.hit: 'audio/sfx_hit.wav',
    Sfx.gameOver: 'audio/sfx_gameover.wav',
    Sfx.button: 'audio/sfx_button.wav',
    Sfx.reward: 'audio/sfx_reward.wav',
  };

  final AudioPlayer _music = AudioPlayer();
  final List<AudioPlayer> _sfxPool =
      List.generate(4, (_) => AudioPlayer());
  int _sfxIndex = 0;
  bool _initialized = false;

  bool musicEnabled = true;
  bool soundEnabled = true;
  double musicVolume = 0.5; // 0..1
  double soundVolume = 0.8; // 0..1
  MusicTrack _current = MusicTrack.none;
  MusicTrack _desired = MusicTrack.none;

  Future<void> init({
    required bool music,
    required bool sound,
    double musicVol = 0.5,
    double soundVol = 0.8,
  }) async {
    musicEnabled = music;
    soundEnabled = sound;
    musicVolume = musicVol.clamp(0.0, 1.0);
    soundVolume = soundVol.clamp(0.0, 1.0);
    if (_initialized) return;
    _initialized = true;
    try {
      // Do NOT let any player grab exclusive audio focus. Otherwise every SFX
      // (jump/coin/…) would steal focus and stop the looping music — which is
      // why in-game music went silent while the quiet menu was fine. With
      // focus disabled, music and SFX play in parallel.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(musicVolume);
      for (final p in _sfxPool) {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(soundVolume);
      }
    } catch (_) {
      // Ignore init failures (e.g. unsupported platform).
    }
  }

  // ---- App lifecycle -------------------------------------------------------
  /// Pause music and silence SFX when the app is backgrounded / minimized.
  Future<void> pauseForBackground() async {
    try {
      await _music.pause();
    } catch (_) {}
    for (final p in _sfxPool) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  /// Resume the current track when the app returns to the foreground.
  Future<void> resumeFromBackground() async {
    if (!musicEnabled || _current == MusicTrack.none) return;
    try {
      await _music.resume();
    } catch (_) {
      // Fall back to a full restart if resume isn't supported from this state.
      final track = _current;
      _current = MusicTrack.none;
      await playMusic(track);
    }
  }

  Future<void> setMusicVolume(double value) async {
    musicVolume = value.clamp(0.0, 1.0);
    try {
      await _music.setVolume(musicVolume);
    } catch (_) {}
  }

  void setSoundVolume(double value) {
    soundVolume = value.clamp(0.0, 1.0);
    for (final p in _sfxPool) {
      // Fire-and-forget; next SFX will play at the new volume regardless.
      p.setVolume(soundVolume).catchError((_) {});
    }
  }

  // ---- Music ---------------------------------------------------------------
  Future<void> playMusic(MusicTrack track) async {
    _desired = track;
    if (!musicEnabled || track == MusicTrack.none) {
      await _stopMusicPlayback();
      return;
    }
    if (_current == track) return;
    _current = track;
    final asset = track == MusicTrack.menu ? _menuMusic : _gameMusic;
    try {
      await _music.stop();
      await _music.play(AssetSource(asset), volume: musicVolume);
    } catch (_) {}
  }

  Future<void> _stopMusicPlayback() async {
    _current = MusicTrack.none;
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    if (value) {
      final want = _desired;
      _current = MusicTrack.none; // force restart
      await playMusic(want == MusicTrack.none ? MusicTrack.menu : want);
    } else {
      await _stopMusicPlayback();
    }
  }

  void setSoundEnabled(bool value) => soundEnabled = value;

  // ---- SFX -----------------------------------------------------------------
  Future<void> play(Sfx sfx) async {
    if (!soundEnabled) return;
    final asset = _sfxAsset[sfx];
    if (asset == null) return;
    final player = _sfxPool[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: soundVolume);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _music.dispose();
      for (final p in _sfxPool) {
        await p.dispose();
      }
    } catch (_) {}
  }
}
