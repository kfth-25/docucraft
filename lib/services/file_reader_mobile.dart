// DocuCraft — File Reader (MOBILE/DESKTOP via dart:io)
// Implementasi baca file untuk platform native (Android/iOS/Desktop).
// Dipakai lewat conditional import dari file_reader.dart — hanya di-compile
// untuk platform yang punya filesystem (bukan web).
// Fungsi utama: readBytesFromPath(path) → baca file jadi Uint8List.

import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readBytesFromPath(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) return await file.readAsBytes();
  } catch (_) {}
  return null;
}
