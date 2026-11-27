---
name: aionk-bridge-send
title: AionK Bridge — s/send (Session Send-Message)
description: Dokumentasi implementasi bridge server untuk menghubungkan Flutter DocuCraft app dengan Aion UI agents via session send-message (s/send).
created: 2026-08-29
status: implemented
---

# AionK Bridge — s/send (Session Send-Message)

Dokumentasi implementasi **AionK Bridge Server** untuk menghubungkan Flutter DocuCraft app dengan Aion UI agents menggunakan `session send-message` (s/send).

## Daftar Isi

- [Overview](#overview)
- [Arsitektur](#arsitektur)
- [Endpoints](#endpoints)
- [Flutter Service](#flutter-service)
- [Flow Lengkap](#flow-lengkap)
- [Hasil Test](#hasil-test)
- [Troubleshooting](#troubleshooting)
- [Struktur File](#struktur-file)

---

## Overview

AionK Bridge Server (`bridge-server/aion-bridge.js`) adalah Node.js HTTP server yang bertindak sebagai penghubung antara Flutter DocuCraft app dan Aion UI. Server menerima prompt dari Flutter app dan memasukkannya ke database Aion UI sehingga muncul sebagai conversation baru di Aion UI.

### Fitur Baru (s/send)

| Fitur | Deskripsi |
|-------|-----------|
| `create-agent` | Buat agent/session baru di project docucraft_app |
| `send-message` | Kirim pesan ke agent via `aioncore.exe session send-message` (s/send) |
| Round-trip | Kirim prompt → agent memproses → ambil output |

---

## Arsitektur

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DocuCraft App (Flutter)                       │
│                                                                      │
│   lib/services/aion_bridge_service.dart                              │
│     ├── createAgent()  ──────────────────────────────────────┐      │
│     ├── sendMessage() ──────────────────────────────────────┤      │
│     ├── getOutput()   ──────────────────────────────────────┤      │
│     └── sendPrompt()  ──────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP (localhost:3002)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     AionK Bridge Server (Node.js)                    │
│                                                                      │
│   bridge-server/aion-bridge.js                                       │
│     ├── POST /create-agent     → Buat session + snapshot + acp      │
│     ├── POST /send-message     → aioncore.exe session send-message  │
│     ├── POST /send             → Insert ke keqo (legacy)            │
│     ├── GET  /output?id=       → Ambil output terbaru               │
│     ├── GET  /status?id=       → Cek status conversation            │
│     └── GET  /conversations    → List recent conversations          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ SQLite + aioncore.exe CLI
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Aion UI Runtime                             │
│                                                                      │
│   aionui-backend.db (SQLite)                                         │
│     ├── conversations          → Session data                       │
│     ├── acp_session            → ACP session config                 │
│     ├── conversation_assistant_snapshots → Agent config             │
│     └── messages               → User/assistant messages            │
│                                                                      │
│   aioncore.exe session send-message                                  │
│     └── Cross-session messaging via Aion UI runtime bridge          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Endpoints

### POST /create-agent

Buat agent/session baru di project docucraft_app.

**Request:**

```json
{
  "agentName": "Project Mapper",
  "projectName": "docucraft_app",
  "sessionName": "Project Mapper - Custom Name",
  "prompt": "Initial prompt untuk agent",
  "presetContext": "# Custom agent rules",
  "agentId": "pm_mapper"
}
```

| Field | Type | Required | Default | Deskripsi |
|-------|------|----------|---------|-----------|
| `agentName` | string | No | `Project Mapper` | Nama agent (lookup di `agent_metadata`) |
| `projectName` | string | No | `docucraft_app` | Nama project target |
| `sessionName` | string | No | `agentName - HH.MM` | Nama session di UI |
| `prompt` | string | No | `Agent ready.` | Pesan awal |
| `presetContext` | string | No | `""` | Custom agent rules |
| `agentId` | string | No | `pm_mapper` | Agent ID fallback |

**Response (200):**

```json
{
  "success": true,
  "conversationId": "3e499eca-3f6c-4b4b-ac00-85dd8ebea011",
  "sessionId": "92e479d5-6e83-4263-b7d6-761c1f7f3587",
  "agentId": "pm_mapper",
  "agentName": "Project Mapper",
  "project": "docucraft_app",
  "message": "Agent \"Project Mapper\" created in docucraft_app. Send messages via /send-message."
}
```

**Response (500):**

```json
{
  "success": false,
  "error": "Error message"
}
```

---

### POST /send-message

Kirim pesan ke agent via `aioncore.exe session send-message` (s/send).

**Request:**

```json
{
  "to": "3e499eca-3f6c-4b4b-ac00-85dd8ebea011",
  "message": "Jelaskan struktur folder project docucraft_app"
}
```

| Field | Type | Required | Deskripsi |
|-------|------|----------|-----------|
| `to` | string | **Yes** | Conversation ID tujuan |
| `message` | string | **Yes** | Isi pesan |

**Response (200):**

```json
{
  "success": true,
  "data": {
    "status": "delivered",
    "to": "3e499eca-3f6c-4b4b-ac00-85dd8ebea011"
  },
  "error": null,
  "message": "Message delivered via s/send"
}
```

**Response (400):**

```json
{
  "success": false,
  "error": {
    "code": "target_is_self",
    "message": "target conversation is the sender: c7c5d0cd"
  },
  "message": "target conversation is the sender: c7c5d0cd"
}
```

---

### GET /output?id={conversationId}

Ambil output terbaru dari agent.

**Response (200):**

```json
{
  "conversationId": "3e499eca-3f6c-4b4b-ac00-85dd8ebea011",
  "conversationStatus": "finished",
  "outputs": [
    {
      "id": "82ddbedc",
      "type": "text",
      "text": "Output dari agent...",
      "status": "finish",
      "created_at": 1788010847270
    }
  ],
  "hasOutput": true
}
```

---

### GET /status?id={conversationId}

Cek status conversation dan semua messages.

---

### GET /conversations?limit={n}

List recent conversations.

---

### GET /health

Health check.

**Response:**

```json
{
  "status": "ok",
  "service": "Flutter ↔ AION UI Bridge",
  "version": "1.0.0",
  "dbPath": "C:\\Users\\Pongo\\AppData\\Roaming\\AionUi\\aionui\\aionui-backend.db",
  "users": 2,
  "conversations": 19
}
```

---

## Flutter Service

File: `lib/services/aion_bridge_service.dart`

### createAgent()

```dart
static Future<AionBridgeResult> createAgent({
  String agentName = 'Project Mapper',
  String projectName = 'docucraft_app',
  String? sessionName,
  String? prompt,
  String? presetContext,
  String? agentId,
}) async {
  // POST /create-agent
}
```

### sendMessage()

```dart
static Future<AionBridgeResult> sendMessage({
  required String to,
  required String message,
}) async {
  // POST /send-message
}
```

### getOutput()

```dart
static Future<AionOutputResult> getOutput(String conversationId) async {
  // GET /output?id={conversationId}
}
```

### Contoh Penggunaan

```dart
// 1. Buat agent baru
final agent = await AionBridgeService.createAgent(
  agentName: 'Project Mapper',
  projectName: 'docucraft_app',
  prompt: 'Start mapping',
);

if (agent.success) {
  final convId = agent.conversationId!;

  // 2. Kirim pesan via s/send
  final sent = await AionBridgeService.sendMessage(
    to: convId,
    message: 'Jelaskan struktur folder lib/',
  );

  // 3. Poll output sampai selesai
  AionOutputResult output;
  do {
    await Future.delayed(Duration(seconds: 3));
    output = await AionBridgeService.getOutput(convId);
  } while (output.conversationStatus == 'pending');

  print(output.outputs.first.text);
}
```

---

## Flow Lengkap

### Sequence Diagram

```
Flutter App                Bridge Server              Aion UI Runtime
    │                          │                          │
    │  POST /create-agent      │                          │
    │─────────────────────────>│                          │
    │                          │  INSERT conversations    │
    │                          │  INSERT snapshots        │
    │                          │  INSERT acp_session      │
    │  <────────────────────────│                          │
    │  { conversationId }      │                          │
    │                          │                          │
    │  POST /send-message      │                          │
    │─────────────────────────>│                          │
    │                          │  aioncore.exe            │
    │                          │  session send-message    │
    │                          │─────────────────────────>│
    │                          │                          │  Process prompt
    │                          │                          │  Agent generates
    │                          │  <────────────────────────│
    │  <────────────────────────│  { status: delivered }  │
    │  { success }             │                          │
    │                          │                          │
    │  GET /output?id=         │                          │
    │─────────────────────────>│                          │
    │                          │  SELECT messages         │
    │  <────────────────────────│                          │
    │  { status: pending }     │                          │
    │                          │                          │
    │  (poll every 3s)         │                          │
    │  GET /output?id=         │                          │
    │─────────────────────────>│                          │
    │                          │  SELECT messages         │
    │  <────────────────────────│                          │
    │  { status: finished,     │                          │
    │    outputs: [...] }      │                          │
    │                          │                          │
```

### State Machine

```
Create Agent ──> idle ──> s/send ──> pending ──> finished
                                  │
                                  └──> error
```

---

## Hasil Test

### Test 1: Create Agent

```bash
curl -X POST http://localhost:3002/create-agent \
  -H "Content-Type: application/json" \
  -d '{"agentName":"Project Mapper","projectName":"docucraft_app","prompt":"Start mapping"}'
```

**Result:**

```json
{
  "success": true,
  "conversationId": "3e499eca-3f6c-4b4b-ac00-85dd8ebea011",
  "agentId": "pm_mapper",
  "agentName": "Project Mapper",
  "project": "docucraft_app"
}
```

### Test 2: s/send

```bash
curl -X POST http://localhost:3002/send-message \
  -H "Content-Type: application/json" \
  -d '{"to":"3e499eca-3f6c-4b4b-ac00-85dd8ebea011","message":"List semua file .dart di folder lib/services/"}'
```

**Result:**

```json
{
  "success": true,
  "data": {
    "status": "delivered",
    "to": "3e499eca-3f6c-4b4b-ac00-85dd8ebea011"
  },
  "message": "Message delivered via s/send"
}
```

### Test 3: Round-trip Output

```bash
curl http://localhost:3002/output?id=3e499eca-3f6c-4b4b-ac00-85dd8ebea011
```

**Result:**

```json
{
  "conversationStatus": "finished",
  "outputs": [
    {
      "type": "text",
      "text": "Berikut adalah semua file `.dart` di folder `lib/services/`:\n\n## `lib/services/` (27 file)\n\n| # | File |\n|---|------|\n| 1 | `lib/services/web_download_stub.dart` |\n| 2 | `lib/services/web_download.dart` |\n..."
    }
  ],
  "hasOutput": true
}
```

### Test 4: Session List

```bash
echo '{"limit":5}' | aioncore.exe session list
```

**Result:**

```json
{
  "data": {
    "items": [
      {"id": "3e499eca...", "name": "Project Mapper - 20.41", "project": "docucraft_app"},
      {"id": "b817b889...", "name": "Project Mapper - 19.22", "project": "docucraft_app"},
      {"id": "86a63ba4...", "name": "Project Mapper - 19.21", "project": "docucraft_app"}
    ]
  }
}
```

---

## Troubleshooting

### Error: `SESSION_CLI_ENV_MISSING: AIONUI_BASE_URL`

**Penyebab:** Bridge server jalan tanpa environment variables Aion UI.

**Fix:** Set env vars di `aion-bridge.js`:

```javascript
process.env.AIONUI_BASE_URL = 'http://127.0.0.1:55018';
process.env.AIONUI_WORK_DIR = path.join(process.env.APPDATA, 'AionUi', 'aionui');
```

### Error: `target_is_self`

**Penyebas:** Mengirim pesan ke conversation yang sama dengan sender.

**Fix:** Pastikan `to` adalah conversation ID yang berbeda dari sender.

### Conversation tidak muncul di Aion UI

**Penyebab:** `user_id` di conversation tidak match dengan user yang login.

**Fix:** Pastikan `getOrCreateUser()` return user yang benar:

```javascript
// Gunakan user aionpro (active user)
const user = db.prepare("SELECT id FROM users WHERE user_type = 'aionpro' ORDER BY updated_at DESC LIMIT 1").get();
```

### Error: `convId is not defined`

**Penyebab:** Bug di kode — variabel `convId` tidak terdefinisi.

**Fix:** Ganti dengan `conversationId`:

```javascript
insertMessage(conversationId, prompt, 'user');
```

### Port 3002 sudah dipakai

```bash
# Kill process lama
netstat -ano | grep 3002 | grep LISTEN
powershell -Command "Stop-Process -Id <PID> -Force"
```

---

## Struktur File

```
docucraft_app/
├── bridge-server/
│   ├── aion-bridge.js          # Bridge server utama (updated)
│   ├── package.json
│   └── node_modules/
├── lib/
│   └── services/
│       └── aion_bridge_service.dart  # Flutter service (updated)
├── docs/
│   └── aionk-bridge-send.md    # Dokumentasi ini
├── aionk.bat                   # Startup script
└── serverk.bat                 # Alternative startup script
```

---

## Environment Variables

| Variable | Value | Deskripsi |
|----------|-------|-----------|
| `AIONUI_BASE_URL` | `http://127.0.0.1:55018` | Aion UI runtime bridge URL |
| `AIONUI_WORK_DIR` | `%APPDATA%\AionUi\aionui` | Aion UI working directory |
| `AIONUI_HELPER_BIN` | `...\aioncore.exe` | Path ke aioncore CLI |

---

## Lihat Juga

- [Aion UI Database Schema](aionk-bridge-send.md#arsitektur)
- [Session Message Skill](C:/Users/Pongo/AppData/Roaming/AionUi/aionui/builtin-skills/auto-inject/session-message/SKILL.md)
- [DocuCraft Architecture](C:/Users/Pongo/docucraft_app/.claude/CLAUDE.md)
