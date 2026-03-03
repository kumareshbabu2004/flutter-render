import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Audio clip playback engine using raw JavaScript for maximum compatibility.
///
/// Injects a `window.__bmbAudio` JS helper and calls it via dart:js_interop.
/// This approach avoids HTMLAudioElement dart2js marshalling issues that
/// caused silent playback in iframe/sandbox contexts.
class WebTtsEngine {
  bool _initialized = false;
  bool _playing = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _injectHelper();
  }

  /// Inject a global JS object `window.__bmbAudio` that handles play/stop.
  void _injectHelper() {
    try {
      final script = web.document.createElement('script') as web.HTMLScriptElement;
      script.text = r'''
        (function() {
          var current = null;
          window.__bmbAudio = {
            play: function(url, vol) {
              try {
                console.log('[BMB Audio] Playing: ' + url + ' vol=' + vol);
                if (current) {
                  current.pause();
                  current.src = '';
                  try { current.remove(); } catch(e) {}
                  current = null;
                }
                var a = new Audio(url);
                a.volume = vol || 0.85;
                a.preload = 'auto';
                current = a;
                a.onended = function() {
                  console.log('[BMB Audio] Ended: ' + url);
                  current = null;
                  if (window.__bmbAudio._onEnd) window.__bmbAudio._onEnd();
                };
                a.onerror = function(e) {
                  console.warn('[BMB Audio] Error loading: ' + url, e);
                  current = null;
                  if (window.__bmbAudio._onEnd) window.__bmbAudio._onEnd();
                };
                a.oncanplay = function() {
                  console.log('[BMB Audio] Can play: ' + url);
                };
                var p = a.play();
                if (p && typeof p.then === 'function') {
                  p.then(function() {
                    console.log('[BMB Audio] Playing successfully: ' + url);
                  }).catch(function(err) {
                    console.warn('[BMB Audio] Play promise rejected:', err.message || err);
                    current = null;
                    if (window.__bmbAudio._onEnd) window.__bmbAudio._onEnd();
                  });
                }
                return true;
              } catch(e) {
                console.error('[BMB Audio] Exception:', e);
                return false;
              }
            },
            stop: function() {
              if (current) {
                current.pause();
                current.src = '';
                try { current.remove(); } catch(e) {}
                current = null;
              }
            },
            isPlaying: function() {
              return current != null && !current.paused;
            },
            _onEnd: null
          };
          console.log('[BMB Audio] Helper injected successfully');
        })();
      ''';
      web.document.head?.appendChild(script);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebTtsEngine] Failed to inject JS helper: $e');
      }
    }
  }

  /// Play an audio clip from a URL (relative or absolute).
  void playClip(
    String url, {
    double volume = 0.85,
    void Function()? onEnd,
  }) {
    _playing = true;

    // Set the onEnd callback on the JS side
    try {
      final audio = _bmbAudio;
      if (audio != null) {
        audio.onEnd = (() {
          _playing = false;
          onEnd?.call();
        }).toJS;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebTtsEngine] Failed to set onEnd: $e');
      }
    }

    // Call the JS play function
    try {
      final audio = _bmbAudio;
      if (audio != null) {
        audio.play(url, volume);
      } else {
        if (kDebugMode) {
          debugPrint('[WebTtsEngine] __bmbAudio not found on window');
        }
        _playing = false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebTtsEngine] JS play failed: $e');
      }
      _playing = false;
    }
  }

  /// Stop all audio playback.
  void stop() {
    _playing = false;
    try {
      _bmbAudio?.stop();
    } catch (_) {}
  }

  /// Check if audio is currently playing.
  bool get isPlaying {
    if (_playing) return true;
    try {
      return _bmbAudio?.isPlaying() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available English voices (for TTS fallback settings).
  List<Map<String, String>> getVoices() {
    try {
      final synth = web.window.speechSynthesis;
      final voices = synth.getVoices().toDart;
      final result = <Map<String, String>>[];
      for (final v in voices) {
        final locale = v.lang;
        if (locale.startsWith('en')) {
          result.add({'name': v.name, 'locale': locale});
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }
}

/// JS interop binding to window.__bmbAudio
@JS('window.__bmbAudio')
extension type _BmbAudioJs._(JSObject _) implements JSObject {
  external void play(String url, double volume);
  external void stop();
  external bool isPlaying();
  @JS('_onEnd')
  external set onEnd(JSFunction? fn);
}

/// Top-level getter for the JS audio helper.
@JS('window.__bmbAudio')
external _BmbAudioJs? get _bmbAudio;
