// DocuCraft — File Reader (SELECTOR LINTAS PLATFORM)
// Conditional export: memilih implementasi baca file sesuai platform.
//   - Mobile/Desktop → file_reader_mobile.dart (dart:io, baca path asli)
//   - Web            → file_reader_web.dart    (terbatas, tanpa path bebas)

// Conditional file reader — dart:io di mobile, no-op di web
export 'file_reader_mobile.dart'
    if (dart.library.html) 'file_reader_web.dart';
