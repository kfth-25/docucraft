# docucraft_app — Copy Frontend-Only

Copy ini (2026-11-26) berisi **hanya kode frontend Flutter** DocuCraft, sudah
dibersihkan dari semua API key hard-coded.

## Keterangan penting

- **[docs/BACKEND_DAN_GAMMA.md](docs/BACKEND_DAN_GAMMA.md)** — arsitektur
  backend GenOffice (port 3001) & alur Gamma AI (mode Pro), termasuk cara
  mengisi key lewat environment karena kode tidak menyimpan key.
- URL backend & endpoint Gamma terpusat di **`lib/config/endpoints.dart`**.

## Menjalankan

```bash
# 1. Nyalakan backend GenOffice dulu (repo GenOffice, port 3001)
# 2. Jalankan frontend:
flutter run -d chrome            # web
flutter run                      # device/emulator

# Opsional — hanya untuk fallback AI langsung (127.0.0.1:20128):
flutter run --dart-define=AI_API_KEY=sk-...
```

Tanpa key di frontend, semua fitur AI tetap jalan selama GenOffice server
aktif — auth (termasuk `gammaApiKey`) sepenuhnya di sisi server.
