import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication_item.dart';

/// Persists the medication list to shared_preferences as JSON, and copies
/// picked photos into app-private permanent storage — an [XFile] from
/// image_picker only points at a temp/cache location that isn't guaranteed
/// to survive an app restart, so every reference/proof photo is copied into
/// this app's documents directory before its path is stored.
class MedicationStore {
  static const _key = 'medication_items';

  Future<List<MedicationItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => MedicationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<MedicationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Copies [picked] into `<app documents>/medication_photos/` under a
  /// unique name and returns the permanent path.
  Future<String> savePhoto(XFile picked, {required String prefix}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/medication_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    // Extension from the file name only — a naive split('.').last on the
    // full path would return the whole path when the file has no extension
    // (or pick up a dot from a directory name).
    final baseName = picked.path.split(RegExp(r'[/\\]')).last;
    final dot = baseName.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : baseName.substring(dot + 1);
    final fileName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final destPath = '${photosDir.path}/$fileName';
    await File(picked.path).copy(destPath);
    return destPath;
  }

  /// Best-effort delete of a photo previously saved via [savePhoto], used
  /// when a photo is replaced or its owning record is removed so orphaned
  /// files don't pile up in permanent storage. Never throws — a missing or
  /// undeletable file must not break the state change that triggered this.
  Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
