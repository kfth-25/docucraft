// DocuCraft — Web Download (SELECTOR LINTAS PLATFORM)
// Conditional export: memilih implementasi download sesuai platform.
//   - Web            → web_download.dart   (dart:html)
//   - Mobile/Desktop → web_download_stub.dart (no-op, Share plugin yang kerja)

// Conditional export: memilih implementasi yang tepat sesuai platform
// web_download.dart (dart:html) di web, web_download_stub.dart di native
export 'web_download_stub.dart'
    if (dart.library.html) 'web_download.dart';
