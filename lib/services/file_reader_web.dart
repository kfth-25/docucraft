// DocuCraft — File Reader (WEB via dart:html / package:web)
// Implementasi baca file untuk platform web (browser tidak punya path bebas,
// jadi fungsi sengaja dibuat null/limited — file dibaca via file picker saja).
// Dipakai lewat conditional import dari file_reader.dart.
// Fungsi utama: readBytesFromPath(path) → selalu null di web (tidak didukung).

import 'dart:typed_data';

Future<Uint8List?> readBytesFromPath(String path) async {
  // Web doesn't use file paths — bytes come from FilePicker directly
  return null;
}
