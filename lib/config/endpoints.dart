// DocuCraft — Endpoint Terpusat (FRONTEND-ONLY)
//
// Copy ini HANYA berisi kode frontend Flutter. Semua request AI diteruskan
// ke **backend GenOffice**; tidak ada key API yang disimpan di kode ini.
//
// ── Backend GenOffice ──
//   REST   : GET  {backend}/api/v1/health
//            POST {backend}/api/v1/generate-outline | generate-slide |
//                  generate-slide-multi | generate-style
//            POST {backend}/api/v1/gamma/generate          ← mode Pro (Gamma)
//   WS     : ws://{host}:3001/ws  (progress broadcast)
//   Config : key AI + gammaApiKey disimpan di sisi server
//            (`userData/ai-settings.json` GenOffice), BUKAN di frontend.
//
// ── Gamma AI (mode Pro) ──
//   Frontend TIDAK memanggil Gamma langsung. Alurnya:
//     Flutter → POST {backend}/api/v1/gamma/generate {inputText, exportAs}
//             → backend GenOffice memanggil Gamma TA API
//               (https://public-api.gamma.app/v1.0, header X-API-KEY)
//               memakai `gammaApiKey` dari ai-settings.json server
//             → balasan { ok, result: { gammaUrl, exportUrl } } ke Flutter.
//   `gammaPublicApiBaseUrl` di bawah hanya dokumentasi/kebutuhan backend —
//   jangan dipanggil dari widget Flutter.
//
// Lihat docs/BACKEND_DAN_GAMMA.md untuk keterangan lengkap.

import 'package:flutter/foundation.dart' show kIsWeb;

class Endpoints {
  Endpoints._();

  /// Host backend GenOffice. Web pakai `localhost` (origin berbeda),
  /// native/emulator pakai `127.0.0.1`.
  static String get backendHost => kIsWeb ? 'localhost' : '127.0.0.1';

  /// Base URL backend GenOffice (tanpa path API).
  static String get backend => 'http://$backendHost:3001';

  /// Base URL untuk endpoint API v1 backend.
  static String get apiV1 => '$backend/api/v1';

  /// Base URL API v1 + `/api` (dipakai ApiClient lama).
  static String get api => '$backend/api';

  /// WebSocket progress (relay dari backend GenOffice).
  static String get ws => 'ws://$backendHost:3001/ws';

  // ── Gamma AI (mode Pro) — selalu lewat backend ──

  /// Path endpoint Gamma di backend GenOffice.
  static const String gammaGeneratePath = '/api/v1/gamma/generate';

  /// Gamma TA API — hanya dipanggil OLEH backend GenOffice,
  /// tidak pernah dari Flutter (lihat header file ini).
  static const String gammaPublicApiBaseUrl = 'https://public-api.gamma.app/v1.0';
}
