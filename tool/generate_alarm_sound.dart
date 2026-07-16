// Generates the custom Android notification sounds used by each
// AlarmStyle (see lib/models/alarm_style.dart), as short WAV files.
// Run with: dart run tool/generate_alarm_sound.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;

void main() {
  // "잔잔한 소리" — soft ascending three-note chime, raised-sine envelope.
  _writeWav('gentle_alarm', _chime(
    notes: const [523.25, 659.25, 783.99], // C5, E5, G5
    noteDuration: 0.28,
    gapDuration: 0.05,
    amplitude: 0.35,
  ));

  // "벨 소리" — a single warm bell hit: fundamental plus a couple of quiet
  // overtones under an exponential decay, the way a real bell rings down.
  _writeWav('bell_alarm', _bell(freq: 659.25, duration: 1.3, amplitude: 0.4));

  // "경쾌한 소리" — a brighter, faster four-note ascending arpeggio.
  _writeWav('upbeat_alarm', _chime(
    notes: const [523.25, 659.25, 783.99, 1046.5], // C5, E5, G5, C6
    noteDuration: 0.14,
    gapDuration: 0.02,
    amplitude: 0.4,
  ));

  // "또렷한 알림음" — two sharp, higher-pitched beeps with a fast attack,
  // for a more attention-grabbing alert than the gentle/bell/upbeat tones.
  _writeWav('alert_alarm', _beeps(
    freq: 880,
    beepDuration: 0.15,
    gapDuration: 0.1,
    count: 2,
    amplitude: 0.45,
  ));
}

List<double> _chime({
  required List<double> notes,
  required double noteDuration,
  required double gapDuration,
  required double amplitude,
}) {
  final samples = <double>[];
  for (final freq in notes) {
    final noteSamples = (sampleRate * noteDuration).round();
    for (int i = 0; i < noteSamples; i++) {
      final t = i / sampleRate;
      final progress = i / noteSamples;
      // Raised-sine envelope: fades in and out smoothly, avoiding clicks.
      final envelope = math.sin(math.pi * progress);
      samples.add(math.sin(2 * math.pi * freq * t) * envelope * amplitude);
    }
    final gapSamples = (sampleRate * gapDuration).round();
    samples.addAll(List.filled(gapSamples, 0.0));
  }
  return samples;
}

List<double> _bell({required double freq, required double duration, required double amplitude}) {
  final total = (sampleRate * duration).round();
  final samples = List.filled(total, 0.0);
  // A fundamental plus two quiet, slightly detuned overtones decaying at
  // different rates is what makes a synthesized tone read as "bell-like"
  // rather than a plain sine beep.
  const partials = [(1.0, 1.0), (2.0, 0.35), (2.76, 0.18)];
  for (int i = 0; i < total; i++) {
    final t = i / sampleRate;
    double sample = 0;
    for (final (ratio, weight) in partials) {
      final decay = math.exp(-t * (2.2 / duration) * ratio);
      sample += math.sin(2 * math.pi * freq * ratio * t) * decay * weight;
    }
    samples[i] = sample * amplitude;
  }
  return samples;
}

List<double> _beeps({
  required double freq,
  required double beepDuration,
  required double gapDuration,
  required int count,
  required double amplitude,
}) {
  final samples = <double>[];
  final beepSamples = (sampleRate * beepDuration).round();
  for (int b = 0; b < count; b++) {
    for (int i = 0; i < beepSamples; i++) {
      final t = i / sampleRate;
      final progress = i / beepSamples;
      // A quick linear attack/release (rather than the softer raised-sine
      // used for the chimes) gives this one a sharper, more urgent edge.
      final envelope = 1 - (progress - 0.5).abs() * 2;
      samples.add(math.sin(2 * math.pi * freq * t) * envelope * amplitude);
    }
    if (b < count - 1) {
      samples.addAll(List.filled((sampleRate * gapDuration).round(), 0.0));
    }
  }
  return samples;
}

void _writeWav(String name, List<double> samples) {
  final pcm = Int16List(samples.length);
  for (int i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
  }

  final wavBytes = _buildWav(pcm, sampleRate);
  final outFile = File('android/app/src/main/res/raw/$name.wav');
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(wavBytes);
  // ignore: avoid_print
  print('Wrote ${outFile.path} (${wavBytes.length} bytes)');
}

Uint8List _buildWav(Int16List pcm, int sampleRate) {
  const bitsPerSample = 16;
  const channels = 1;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataLength = pcm.length * 2;

  final buffer = BytesBuilder();

  void writeAscii(String s) => buffer.add(s.codeUnits);
  void writeUint32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  void writeUint16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  writeAscii('RIFF');
  writeUint32(36 + dataLength);
  writeAscii('WAVE');
  writeAscii('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(channels);
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);
  writeAscii('data');
  writeUint32(dataLength);

  final dataBytes = ByteData(dataLength);
  for (int i = 0; i < pcm.length; i++) {
    dataBytes.setInt16(i * 2, pcm[i], Endian.little);
  }
  buffer.add(dataBytes.buffer.asUint8List());

  return buffer.toBytes();
}
