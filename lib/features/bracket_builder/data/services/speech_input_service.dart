import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import 'web_speech_recognition.dart' if (dart.library.io) 'speech_input_stub.dart';

/// Unified speech-to-text service that works on **both web and mobile**.
///
/// - **Web**: Uses the browser's native SpeechRecognition API directly via
///   `dart:js_interop`, which is far more reliable than the `speech_to_text`
///   plugin in iframe/release-mode contexts.
/// - **Mobile (Android / iOS)**: Delegates to the `speech_to_text` Flutter
///   plugin for full native support.
///
/// Platform config required for native:
///   **Android**: `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
///   **iOS**: `NSSpeechRecognitionUsageDescription` and
///            `NSMicrophoneUsageDescription` keys in Info.plist.
class SpeechInputService {
  SpeechInputService._();
  static final SpeechInputService instance = SpeechInputService._();

  // ── Native (mobile) engine ─────────────────────────────────
  SpeechToText _speech = SpeechToText();
  bool _nativeInitialized = false;
  bool _nativeAvailable = false;

  // ── Web engine ─────────────────────────────────────────────
  bool _webInitialized = false;
  bool _webAvailable = false;
  bool _webListening = false;

  // ── Common state ───────────────────────────────────────────
  String? _lastError;

  /// Whether speech recognition is supported on this platform.
  bool get isAvailable => kIsWeb ? _webAvailable : _nativeAvailable;

  /// Whether the engine is currently listening.
  bool get isListening =>
      kIsWeb ? _webListening : _speech.isListening;

  /// Last error message (for UI feedback).
  String? get lastError => _lastError;

  // ════════════════════════════════════════════════════════════
  //  INIT
  // ════════════════════════════════════════════════════════════

  /// Initialise the engine.  Safe to call multiple times.
  Future<bool> init() async {
    if (kIsWeb) return _initWeb();
    return _initNative();
  }

  bool _initWeb() {
    if (_webInitialized && _webAvailable) return true;

    try {
      final ws = WebSpeechRecognition.instance;
      ws.init();
      _webAvailable = ws.checkAvailability();
    } catch (e) {
      if (kDebugMode) debugPrint('[SpeechInput] Web init failed: $e');
      _webAvailable = false;
    }
    _webInitialized = true;
    if (kDebugMode) {
      debugPrint('[SpeechInput] Web init complete: available=$_webAvailable');
    }
    return _webAvailable;
  }

  Future<bool> _initNative() async {
    if (_nativeInitialized && _nativeAvailable) return true;

    if (_nativeInitialized && !_nativeAvailable) {
      _speech = SpeechToText();
      _nativeInitialized = false;
    }

    try {
      _nativeAvailable = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          _lastError = error.errorMsg;
          if (kDebugMode) {
            debugPrint('[SpeechInput] error: ${error.errorMsg} '
                '(permanent: ${error.permanent})');
          }
        },
        onStatus: (status) {
          if (kDebugMode) debugPrint('[SpeechInput] status: $status');
        },
        debugLogging: kDebugMode,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SpeechInput] native init failed: $e');
      _lastError = e.toString();
      _nativeAvailable = false;
    }
    _nativeInitialized = true;

    if (kDebugMode) {
      debugPrint('[SpeechInput] native init: available=$_nativeAvailable');
      if (_nativeAvailable) {
        try {
          final locales = await _speech.locales();
          debugPrint('[SpeechInput] locales: '
              '${locales.map((l) => l.localeId).take(5).join(", ")}');
        } catch (_) {}
      }
    }
    return _nativeAvailable;
  }

  // ════════════════════════════════════════════════════════════
  //  START LISTENING
  // ════════════════════════════════════════════════════════════

  /// Start listening and call [onResult] with recognised words.
  /// Returns `true` if listening started successfully.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 5),
  }) async {
    _lastError = null;

    if (kIsWeb) return _startListeningWeb(onResult, localeId);
    return _startListeningNative(onResult, localeId, listenFor, pauseFor);
  }

  bool _startListeningWeb(
    void Function(String text, bool isFinal) onResult,
    String localeId,
  ) {
    if (!_webAvailable) {
      final ok = _initWeb();
      if (!ok) return false;
    }

    final ws = WebSpeechRecognition.instance;

    // If already listening, stop first
    if (ws.isListening) {
      ws.stop();
    }

    final started = ws.startListening(
      onResult: (text, isFinal) {
        if (isFinal) _webListening = false;
        onResult(text, isFinal);
      },
      onError: (error) {
        _webListening = false;
        _lastError = error;
        if (kDebugMode) debugPrint('[SpeechInput] web error: $error');
      },
      onEnd: () {
        _webListening = false;
      },
      lang: localeId.replaceAll('_', '-'), // Web uses en-US not en_US
    );

    _webListening = started;
    if (!started) {
      _lastError = 'Failed to start browser speech recognition';
    }
    return started;
  }

  Future<bool> _startListeningNative(
    void Function(String text, bool isFinal) onResult,
    String localeId,
    Duration listenFor,
    Duration pauseFor,
  ) async {
    if (!_nativeAvailable) {
      final ok = await _initNative();
      if (!ok) return false;
    }

    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          autoPunctuation: true,
          enableHapticFeedback: true,
        ),
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) debugPrint('[SpeechInput] listen failed: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  STOP / CANCEL / RESET
  // ════════════════════════════════════════════════════════════

  /// Stop the current listening session gracefully.
  Future<void> stop() async {
    if (kIsWeb) {
      WebSpeechRecognition.instance.stop();
      _webListening = false;
      return;
    }
    try {
      await _speech.stop();
    } catch (_) {}
  }

  /// Cancel the current listening session (discards partial results).
  Future<void> cancel() async {
    if (kIsWeb) {
      WebSpeechRecognition.instance.abort();
      _webListening = false;
      return;
    }
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  /// Full reset — creates a fresh engine instance.
  void reset() {
    if (kIsWeb) {
      WebSpeechRecognition.instance.abort();
      _webInitialized = false;
      _webAvailable = false;
      _webListening = false;
    } else {
      try { _speech.cancel(); } catch (_) {}
      _speech = SpeechToText();
      _nativeInitialized = false;
      _nativeAvailable = false;
    }
    _lastError = null;
  }
}
