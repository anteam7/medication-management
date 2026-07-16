import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/photo_embedding_service.dart';

/// Shows the medication's registered reference photo next to the just-taken
/// proof photo, and compares them via an on-device AI visual-similarity
/// model. Matching only auto-enables the "일치" button — the user still
/// has to tap something to confirm, and can override via "그래도 확인" if
/// the model misses a real match.
///
/// Pops with `true` if the user confirmed the dose, `false`/null otherwise.
class PhotoMatchScreen extends StatefulWidget {
  final String referencePhotoPath;
  final XFile capturedPhoto;

  const PhotoMatchScreen({
    super.key,
    required this.referencePhotoPath,
    required this.capturedPhoto,
  });

  @override
  State<PhotoMatchScreen> createState() => _PhotoMatchScreenState();
}

class _PhotoMatchScreenState extends State<PhotoMatchScreen> {
  late final Future<PhotoMatchResult> _result = PhotoEmbeddingService().comparePhotos(
    referencePath: widget.referencePhotoPath,
    capturedPath: widget.capturedPhoto.path,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진 비교')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('등록사진', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(widget.referencePhotoPath),
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              const Text('방금 찍은 사진', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Expanded(
                child: FutureBuilder<PhotoMatchResult>(
                  future: _result,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _CapturedPhoto(
                      photoPath: widget.capturedPhoto.path,
                      matched: snapshot.data!.matched,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<PhotoMatchResult>(
                future: _result,
                builder: (context, snapshot) {
                  final result = snapshot.data;
                  if (result == null) {
                    return const Text('분석 중...', textAlign: TextAlign.center);
                  }
                  final percent = (result.score * 100).clamp(0, 100).toStringAsFixed(0);
                  return Text(
                    result.matched ? '일치해요 (유사도 $percent%)' : '일치하지 않는 것 같아요 (유사도 $percent%)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: result.matched ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<PhotoMatchResult>(
                future: _result,
                builder: (context, snapshot) {
                  final matched = snapshot.data?.matched ?? false;
                  return Column(
                    children: [
                      FilledButton(
                        onPressed: matched ? () => Navigator.pop(context, true) : null,
                        child: const Text('일치'),
                      ),
                      if (snapshot.hasData && !matched)
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('그래도 확인'),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapturedPhoto extends StatelessWidget {
  final String photoPath;
  final bool matched;

  const _CapturedPhoto({required this.photoPath, required this.matched});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: matched ? Border.all(color: Colors.greenAccent, width: 4) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(photoPath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
