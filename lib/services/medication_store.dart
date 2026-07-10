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
    final ext = picked.path.split('.').last;
    final fileName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final destPath = '${photosDir.path}/$fileName';
    await File(picked.path).copy(destPath);
    return destPath;
  }
}
