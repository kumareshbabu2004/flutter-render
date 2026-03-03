/// Stub for [WebSpeechRecognition] when running on native (non-web) platforms.
///
/// On mobile the `speech_to_text` plugin handles everything; this class is
/// never actually invoked — it only exists so that conditional imports resolve.
class WebSpeechRecognition {
  WebSpeechRecognition._();
  static final WebSpeechRecognition instance = WebSpeechRecognition._();

  bool get isAvailable => false;
  bool get isListening => false;

  void init() {}
  bool checkAvailability() => false;

  bool startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(String error)? onError,
    void Function()? onEnd,
    String lang = 'en-US',
  }) =>
      false;

  void stop() {}
  void abort() {}
}
