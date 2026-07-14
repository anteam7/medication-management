// Generates a short, gentle three-note chime as a WAV file, used as the
// custom Android notification sound for the "잔잔한 소리" alarm style.
// Run with: dart run tool/generate_alarm_sound.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const sampleRate = 44100;
  const notes = [523.25, 659.25, 783.99]; // C5, E5, G5 — soft ascending chime
  const noteDuration = 0.28; // seconds
  const gapDuration = 0.05; // seconds of silence between notes
  const amplitude = 0.35; // keep it soft, not a harsh full-volume beep

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

  final pcm = Int16List(samples.length);
  for (int i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
  }

  final wavBytes = _buildWav(pcm, sampleRate);
  final outFile = File('android/app/src/main/res/raw/gentle_alarm.wav');
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
