# Backend GenOffice & Gamma AI — Keterangan untuk Copy Frontend-Only

> Copy ini (`docucraft_app - Copy`) **hanya berisi kode frontend Flutter**.
> Tidak ada API key yang disimpan di kode. Semua request AI diteruskan ke
> **backend GenOffice**, dan **Gamma AI hanya dipanggil oleh backend**.

## 1. Backend GenOffice (otak AI)

| | |
|---|---|
| Base URL (native) | `http://127.0.0.1:3001` |
| Base URL (web) | `http://localhost:3001` |
| WebSocket progress | `ws://127.0.0.1:3001/ws` |
| Konfigurasi key | `userData/ai-settings.json` **di sisi server** (GenOffice) |

Endpoint yang dipakai frontend:

- `GET  /api/v1/health` — cek koneksi (splash screen)
- `POST /api/v1/generate-outline` — outline presentasi
- `POST /api/v1/generate-slide` — 1 slide SVG
- `POST /api/v1/generate-slide-multi` — N opsi desain (sequential)
- `POST /api/v1/generate-style` — skill style
- `POST /api/v1/gamma/generate` — **mode Pro (Gamma)**, lihat §2
- `WS   /ws` — broadcast progress generate

Semua URL frontend terpusat di **`lib/config/endpoints.dart`** (`Endpoints.backend`,
`Endpoints.apiV1`, `Endpoints.ws`, `Endpoints.gammaGeneratePath`). Ubah URL backend
cukup di satu file itu.

## 2. Gamma AI (mode Pro)

Frontend **tidak memanggil Gamma langsung**. Alur lengkap:

```
Flutter (sketch_ai_panel / ai_chat_panel)
  └─ POST {backend}/api/v1/gamma/generate  { inputText, exportAs: "pptx" }
       └─ backend GenOffice (http-server.ts)
            ├─ baca gammaApiKey dari ai-settings.json (server)
            ├─ POST https://public-api.gamma.app/v1.0/generations
            │      header: X-API-KEY: <gammaApiKey>
            ├─ poll GET  .../generations/{id} sampai selesai
            └─ balas { ok, result: { gammaUrl, exportUrl } }
  └─ Flutter tampilkan link gammaUrl / unduh exportUrl (PPTX)
```

- `Endpoints.gammaGeneratePath` = `/api/v1/gamma/generate` (dipanggil Flutter)
- `Endpoints.gammaPublicApiBaseUrl` = `https://public-api.gamma.app/v1.0`
  — **dokumentasi saja di frontend**; hanya backend yang boleh memakainya.
- Prompt Gamma untuk coretan/sketch dibangun lokal oleh
  `AiGenerationService.buildGammaPromptFromSketch` (Gamma text-only).

## 3. Key & cara mengisi (karena kode tanpa key)

| Key | Disimpan di | Cara isi |
|---|---|---|
| Key AI utama (9Router dsb.) | server: `ai-settings.json` → `providers.*.apiKey` | lewat Settings UI GenOffice, atau edit file server |
| `gammaApiKey` (Gamma TA) | server: `ai-settings.json` → `gammaApiKey` | sama — **hanya server** |
| `AI_API_KEY` (fallback AI langsung dari Flutter) | environment saat build | `flutter run --dart-define=AI_API_KEY=sk-...` (opsional; hanya untuk fallback `127.0.0.1:20128`) |
| `ANTHROPIC_AUTH_TOKEN` (bridge-server) | environment proses Node | `set ANTHROPIC_AUTH_TOKEN=sk-...` sebelum `node bridge-server/server.js` |

Tanpa key di frontend, fitur tetap jalan **selama GenOffice server aktif di
port 3001** — auth sepenuhnya di sisi server.

## 4. Catatan copy ini

- Salinan proyek `docucraft_app` per 2026-11-26, dibersihkan dari key hard-coded.
- File `bridge-server/`, `hocuspocus-server/`, `examples/` ikut terbawa; key di
  dalamnya juga sudah dikosongkan.
- Untuk pengembangan backend-nya, lihat repo GenOffice
  (`apps/shell/src/main/http-server.ts`).
