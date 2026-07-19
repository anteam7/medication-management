import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Thin wrapper around `speech_to_text` for dictating a memo. Prefers a
/// Korean locale when the device offers one, otherwise falls back to
/// whatever locale the platform defaults to.
///
/// The underlying plugin's `initialize()` call is a one-time, cached
/// operation — calling it again does *not* replace the `onStatus` callback
/// passed the first time. Since a new [SpeechService] consumer (e.g. a
/// freshly opened bottom sheet) needs its own "listening changed" callback
/// each time, that callback is tracked separately here and refreshed on
/// every [startListening] call rather than relying on `initialize()`.
class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  String? _koreanLocaleId;
  void Function(bool isListening)? _statusCallback;

  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    // Only a *successful* init is cached — a failed one (e.g. mic permission
    // denied, then granted later in system settings) must stay retryable, or
    // voice input would be dead until the app restarts.
    if (_available) return true;
    _available = await _speech.initialize(
      onStatus: (_) => _statusCallback?.call(_speech.isListening),
    );
    if (_available) {
      final locales = await _speech.locales();
      final korean = locales.where((l) => l.localeId.startsWith('ko'));
      if (korean.isNotEmpty) _koreanLocaleId = korean.first.localeId;
    }
    return _available;
  }

  /// Starts listening, invoking [onResult] with the recognized text every
  /// time it updates (both partial and final results) so the caller can
  /// live-update a text field, and [onListeningChange] whenever listening
  /// starts/stops (including the automatic stop after a pause in speech).
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(bool isListening)? onListeningChange,
  }) async {
    if (!_available) return;
    _statusCallback = onListeningChange;
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: _koreanLocaleId,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }
}
