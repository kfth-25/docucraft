// DocuCraft — Web Download (IMPLEMENTASI WEB via dart:html)
// Conditional helper untuk download file HANYA di web.
// Di mobile/desktop, versi stub (web_download_stub.dart) yang dipakai.
//
// TODO(migrasi): Pindah ke `package:web` + `dart:js_interop` begitu build web
// masuk CI matrix reguler. `dart:html` sudah deprecated tapi masih jalan
// di Flutter 3.x; migrasinya menyentuh Blob, Url, dan js_interop.

// Conditional helper: web download — file ini dipakai di web (dart:html tersedia)
// Di mobile/desktop, versi stub yang menggantikan.
//
// TODO(migrasi): Migrasi ke `package:web` + `dart:js_interop` begitu build web
// berada di CI matrix reguler. `dart:html` sudah deprecated tapi masih berfungsi
// di Flutter 3.x; migrasinya menyentuh API `Blob`, `Url`, dan `AnchorElement`
// serta butuh web runtime untuk verifikasi.
// ignore: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:html' as html;

void downloadBytes(String filename, List<int> bytes) {
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.presentationml.presentation');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
