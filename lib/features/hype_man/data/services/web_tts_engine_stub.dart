/// Stub implementation of WebTtsEngine for non-web platforms.
/// On Android/iOS, TTS is handled by native platform APIs.
class WebTtsEngine {
  void init() {
    // No-op on non-web platforms
  }

  void playClip(
    String url, {
    double volume = 0.85,
    void Function()? onEnd,
  }) {
    // No-op on non-web platforms
    onEnd?.call();
  }

  void stop() {
    // No-op
  }

  bool get isPlaying => false;

  List<Map<String, String>> getVoices() {
    return [];
  }
}
