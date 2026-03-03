import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Simple audio player service using the browser's native HTMLAudioElement.
/// Much more reliable than audioplayers on Flutter web for remote URLs.
class CompanionAudioPlayer {
  web.HTMLAudioElement? _audio;
  bool _isPlaying = false;
  void Function()? onComplete;

  bool get isPlaying => _isPlaying;

  Future<void> play(String url) async {
    // Stop any currently playing audio
    stop();

    // Create audio element and add to DOM (needed for some browsers)
    _audio = web.HTMLAudioElement();
    _audio!.src = url;
    _audio!.style.display = 'none';
    web.document.body?.append(_audio!);

    _audio!.onEnded.listen((_) {
      _isPlaying = false;
      _cleanup();
      onComplete?.call();
    });

    _audio!.onError.listen((_) {
      _isPlaying = false;
      _cleanup();
      onComplete?.call();
    });

    try {
      _isPlaying = true;
      // play() returns a Future/Promise in modern browsers
      final promise = _audio!.play();
      promise.toDart.catchError((e) {
        _isPlaying = false;
        _cleanup();
        onComplete?.call();
        return null;
      });
    } catch (e) {
      _isPlaying = false;
      _cleanup();
      onComplete?.call();
    }
  }

  void _cleanup() {
    if (_audio != null) {
      _audio!.remove();
    }
  }

  void stop() {
    if (_audio != null) {
      try {
        _audio!.pause();
        _audio!.currentTime = 0;
      } catch (_) {}
      _cleanup();
      _audio = null;
    }
    _isPlaying = false;
  }

  void dispose() {
    stop();
  }
}
