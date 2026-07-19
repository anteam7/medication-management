import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/photo_embedding_service.dart';

/// Shows the medication's registered reference photo next to the just-taken
/// proof photo, and compares them via an on-device AI visual-similarity
/// model. Matching only auto-enables the confirm button — the user still
/// has to tap something to confirm, and can override via "그래도 복용 확인"
/// if the model misses a real match.
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LabeledPhoto(
                      label: '등록사진',
                      path: widget.referencePhotoPath,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<PhotoMatchResult>(
                      future: _result,
                      builder: (context, snapshot) => _LabeledPhoto(
                        label: '방금 찍은 사진',
                        path: widget.capturedPhoto.path,
                        highlighted: snapshot.data?.matched ?? false,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<PhotoMatchResult>(
                future: _result,
                builder: (context, snapshot) =>
                    _ResultBanner(result: snapshot.data),
              ),
              const Spacer(),
              FutureBuilder<PhotoMatchResult>(
                future: _result,
                builder: (context, snapshot) {
                  final matched = snapshot.data?.matched ?? false;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            matched ? () => Navigator.pop(context, true) : null,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('복용 확인'),
                      ),
                      if (snapshot.hasData && !matched)
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('그래도 복용 확인'),
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

/// One side of the comparison: a caption and a square-cropped photo.
/// [highlighted] draws the "these match" accent ring around it.
class _LabeledPhoto extends StatelessWidget {
  final String label;
  final String path;
  final bool highlighted;

  const _LabeledPhoto({
    required this.label,
    required this.path,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted ? Colors.green : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                // A stale/unreadable file shows a quiet placeholder instead
                // of a render error.
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The comparison verdict, shown as a tinted banner: analyzing → matched /
/// not-matched with the similarity score.
class _ResultBanner extends StatelessWidget {
  final PhotoMatchResult? result;
  const _ResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;

    final Color color;
    final Widget leading;
    final String text;
    if (result == null) {
      color = theme.colorScheme.onSurfaceVariant;
      leading = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      text = '사진을 비교하고 있어요…';
    } else if (result.matched) {
      color = Colors.green;
      leading = const Icon(Icons.check_circle, size: 18, color: Colors.green);
      final percent = (result.score * 100).clamp(0, 100).toStringAsFixed(0);
      text = '일치해요 (유사도 $percent%)';
    } else {
      color = theme.colorScheme.onSurfaceVariant;
      leading = Icon(Icons.help_outline, size: 18, color: color);
      final percent = (result.score * 100).clamp(0, 100).toStringAsFixed(0);
      text = '일치하지 않는 것 같아요 (유사도 $percent%)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: result?.matched == true
                    ? Colors.green.shade800
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
