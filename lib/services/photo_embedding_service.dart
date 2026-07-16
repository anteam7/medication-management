import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Whether a captured (proof) photo appears to match a medication's
/// registered reference photo — a coarse visual aid, not a certified
/// verification. [score] is the cosine similarity (roughly 0..1) between
/// the two photos' MobileNet feature vectors.
class PhotoMatchResult {
  final bool matched;
  final double score;

  const PhotoMatchResult({required this.matched, required this.score});

  factory PhotoMatchResult.none() => const PhotoMatchResult(matched: false, score: 0);
}

/// Compares two photos using a pretrained MobileNet (ImageNet-classification)
/// model as a general-purpose visual feature extractor: rather than reading
/// its 1001-way class prediction, the raw output vector itself is used as a
/// "fingerprint" of the photo's visual content, and two photos are compared
/// via cosine similarity between their vectors. This generalizes across
/// lighting/angle/background changes far better than hand-tuned pixel
/// correlation, since the features come from a model trained on millions of
/// real photos rather than a few manually-chosen heuristics.
class PhotoEmbeddingService {
  static const _modelAsset = 'assets/models/mobilenet_quant.tflite';
  static const _inputSize = 224;

  /// Cosine similarity above which two photos count as a match. MobileNet's
  /// ImageNet classes don't include fine-grained pill/tablet categories, so
  /// this is a reasonable starting point rather than a precisely-derived
  /// value — likely needs retuning against real photos.
  static const double matchThreshold = 0.5;

  static Interpreter? _interpreter;

  static Future<Interpreter> _getInterpreter() async {
    final cached = _interpreter;
    if (cached != null) return cached;
    final interpreter = await Interpreter.fromAsset(_modelAsset);
    _interpreter = interpreter;
    return interpreter;
  }

  /// Runs on the main isolate rather than via `compute()` — `Interpreter
  /// .fromAsset` needs Flutter's asset bundle, which a bare background
  /// isolate can't reach without extra `RootIsolateToken` plumbing. A single
  /// quantized MobileNet pass is fast enough (tens of ms) that doing this
  /// inline during the screen's existing "분석 중" loading state is an
  /// acceptable trade-off for the simpler code path.
  Future<PhotoMatchResult> comparePhotos({
    required String referencePath,
    required String capturedPath,
  }) async {
    try {
      final interpreter = await _getInterpreter();
      final referenceVector = await _embed(interpreter, referencePath);
      final capturedVector = await _embed(interpreter, capturedPath);
      final similarity = _cosineSimilarity(referenceVector, capturedVector);
      return PhotoMatchResult(matched: similarity >= matchThreshold, score: similarity);
    } catch (_) {
      return PhotoMatchResult.none();
    }
  }

  Future<List<double>> _embed(Interpreter interpreter, String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return List<double>.filled(1001, 0);

    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);
    final inputMatrix = List.generate(
      _inputSize,
      (y) => List.generate(_inputSize, (x) {
        final pixel = resized.getPixel(x, y);
        return [pixel.r, pixel.g, pixel.b];
      }),
    );

    final input = [inputMatrix];
    final outputShape = interpreter.getOutputTensors().first.shape;
    final output = [List<int>.filled(outputShape[1], 0)];
    interpreter.run(input, output);
    return output.first.map((e) => e.toDouble()).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }
}
