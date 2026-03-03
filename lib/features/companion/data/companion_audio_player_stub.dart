/// Stub implementation of CompanionAudioPlayer for non-web platforms.
/// On Android/iOS, we use audioplayers package instead.
class CompanionAudioPlayer {
  bool _isPlaying = false;
  void Function()? onComplete;

  bool get isPlaying => _isPlaying;

  Future<void> play(String url) async {
    // No-op on non-web platforms; use audioplayers instead
    _isPlaying = false;
    onComplete?.call();
  }

  void stop() {
    _isPlaying = false;
  }

  void dispose() {
    stop();
  }
}
