import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Direct Web Speech API implementation using dart:js_interop.
///
/// This bypasses the speech_to_text plugin which can fail to initialise
/// properly in release-mode web builds or iframe contexts.
///
/// The browser's SpeechRecognition API is available in Chrome, Edge, and
/// Safari 14.1+.  Firefox has partial support behind a flag.
class WebSpeechRecognition {
  WebSpeechRecognition._();
  static final WebSpeechRecognition instance = WebSpeechRecognition._();

  bool _injected = false;
  bool _available = false;
  bool _listening = false;

  bool get isAvailable => _available;
  bool get isListening => _listening;

  /// Inject the JS helper and probe for SpeechRecognition support.
  void init() {
    if (_injected) return;
    _injected = true;

    try {
      final script =
          web.document.createElement('script') as web.HTMLScriptElement;
      script.text = r'''
(function() {
  var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) {
    console.warn('[BMB STT] SpeechRecognition API not available');
    window.__bmbSTT = { available: false };
    return;
  }

  var recognition = null;

  window.__bmbSTT = {
    available: true,
    listening: false,

    start: function(lang) {
      try {
        if (recognition) {
          try { recognition.abort(); } catch(e) {}
        }
        recognition = new SpeechRecognition();
        recognition.lang = lang || 'en-US';
        recognition.interimResults = true;
        recognition.continuous = false;
        recognition.maxAlternatives = 1;

        recognition.onresult = function(event) {
          var interim = '';
          var final_transcript = '';
          var is_final = false;
          for (var i = event.resultIndex; i < event.results.length; i++) {
            var transcript = event.results[i][0].transcript;
            if (event.results[i].isFinal) {
              final_transcript += transcript;
              is_final = true;
            } else {
              interim += transcript;
            }
          }
          var text = final_transcript || interim;
          if (window.__bmbSTT._onResult) {
            window.__bmbSTT._onResult(text, is_final);
          }
        };

        recognition.onerror = function(event) {
          console.warn('[BMB STT] Error:', event.error);
          window.__bmbSTT.listening = false;
          if (window.__bmbSTT._onError) {
            window.__bmbSTT._onError(event.error);
          }
        };

        recognition.onend = function() {
          console.log('[BMB STT] Session ended');
          window.__bmbSTT.listening = false;
          if (window.__bmbSTT._onEnd) {
            window.__bmbSTT._onEnd();
          }
        };

        recognition.onstart = function() {
          console.log('[BMB STT] Listening started');
          window.__bmbSTT.listening = true;
        };

        recognition.start();
        return true;
      } catch(e) {
        console.error('[BMB STT] Start failed:', e);
        window.__bmbSTT.listening = false;
        return false;
      }
    },

    stop: function() {
      try {
        if (recognition) {
          recognition.stop();
        }
      } catch(e) {}
      window.__bmbSTT.listening = false;
    },

    abort: function() {
      try {
        if (recognition) {
          recognition.abort();
        }
      } catch(e) {}
      window.__bmbSTT.listening = false;
    },

    _onResult: null,
    _onError: null,
    _onEnd: null
  };

  console.log('[BMB STT] Helper injected — SpeechRecognition available');
})();
''';
      web.document.head?.appendChild(script);

      // Wait a tick then check availability
      _available = true; // Will be verified on first use
      if (kDebugMode) {
        debugPrint('[WebSpeechRecognition] JS helper injected');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebSpeechRecognition] Failed to inject JS: $e');
      }
      _available = false;
    }
  }

  /// Check if the browser actually supports the Web Speech API.
  bool checkAvailability() {
    try {
      final stt = _bmbSTT;
      if (stt == null) return false;
      _available = stt.available;
      return _available;
    } catch (e) {
      _available = false;
      return false;
    }
  }

  /// Start speech recognition.
  ///
  /// [onResult] receives (transcribedText, isFinal).
  /// [onError] receives the error string.
  /// [onEnd] fires when the recognition session ends.
  bool startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(String error)? onError,
    void Function()? onEnd,
    String lang = 'en-US',
  }) {
    final stt = _bmbSTT;
    if (stt == null) {
      if (kDebugMode) debugPrint('[WebSpeechRecognition] __bmbSTT not found');
      return false;
    }

    if (!stt.available) {
      if (kDebugMode) {
        debugPrint('[WebSpeechRecognition] Not available in this browser');
      }
      return false;
    }

    // Wire up callbacks
    stt.onResult = ((JSString text, JSBoolean isFinal) {
      final t = text.toDart;
      final f = isFinal.toDart;
      if (f) _listening = false;
      onResult(t, f);
    }).toJS;

    stt.onError = ((JSString error) {
      _listening = false;
      final e = error.toDart;
      if (kDebugMode) debugPrint('[WebSpeechRecognition] error: $e');
      onError?.call(e);
    }).toJS;

    stt.onEnd = (() {
      _listening = false;
      onEnd?.call();
    }).toJS;

    final started = stt.start(lang);
    _listening = started;
    return started;
  }

  /// Stop listening gracefully (processes remaining audio).
  void stop() {
    _listening = false;
    try {
      _bmbSTT?.stop();
    } catch (_) {}
  }

  /// Abort listening immediately (discards pending results).
  void abort() {
    _listening = false;
    try {
      _bmbSTT?.abort();
    } catch (_) {}
  }
}

// ── JS interop bindings ──────────────────────────────────────────────────

@JS('window.__bmbSTT')
extension type _BmbSttJs._(JSObject _) implements JSObject {
  external bool get available;
  external bool get listening;
  external bool start(String lang);
  external void stop();
  external void abort();

  @JS('_onResult')
  external set onResult(JSFunction? fn);
  @JS('_onError')
  external set onError(JSFunction? fn);
  @JS('_onEnd')
  external set onEnd(JSFunction? fn);
}

@JS('window.__bmbSTT')
external _BmbSttJs? get _bmbSTT;
