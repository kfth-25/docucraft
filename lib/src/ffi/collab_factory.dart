// DocuCraft — Collaboration Factory
//
// Menyediakan pergantian mudah antara sync legacy dan sync Loro CRDT.
// Penggunaan:
//   final provider = await CollabFactory.createSlideProvider(
//     documentId: 'doc-123',
//     userId: 'user-abc',
//     userName: 'Rina',
//     useCrdt: true,  // Set false untuk mode legacy
//   );

import '../../providers/slide_provider.dart';
import 'slide_provider_crdt.dart';
import 'collab_websocket_crdt.dart';
import 'crdt_provider.dart';

import 'dart:typed_data';
import 'dart:convert';

enum CollabMode { legacy, crdt }

class CollabFactory {
  /// Create a SlideProvider with the chosen collaboration mode
  static Future<dynamic> createSlideProvider({
    required String documentId,
    required String userId,
    required String userName,
    CollabMode mode = CollabMode.crdt,
    Uint8List? existingSnapshot,
  }) async {
    switch (mode) {
      case CollabMode.crdt:
        return await _createCrdtProvider(
          documentId: documentId,
          userId: userId,
          userName: userName,
          existingSnapshot: existingSnapshot,
        );
      case CollabMode.legacy:
        return _createLegacyProvider();
    }
  }

  static Future<SlideProviderCrdt> _createCrdtProvider({
    required String documentId,
    required String userId,
    required String userName,
    Uint8List? existingSnapshot,
  }) async {
    final provider = SlideProviderCrdt();
    await provider.initCollab(
      documentId: documentId,
      userId: userId,
      userName: userName,
      snapshot: existingSnapshot,
    );
    return provider;
  }

  static SlideProvider _createLegacyProvider() {
    return SlideProvider();
  }

  /// Create CRDT WebSocket sync service
  static CrdtWebSocketSync createWebSocketSync({
    required String documentId,
    required String userId,
    required String userName,
    String serverUrl = 'ws://127.0.0.1:9101',
  }) {
    return CrdtWebSocketSync(
      documentId: documentId,
      userId: userId,
      userName: userName,
      serverUrl: serverUrl,
    );
  }

  /// Create a standalone CRDT document (without SlideProvider)
  static Future<CrdtDocument> createCrdtDocument({
    required String documentId,
    Uint8List? snapshot,
  }) async {
    return snapshot != null
        ? await CrdtDocument.fromSnapshot(documentId, snapshot)
        : await CrdtDocument.create(documentId);
  }
}

/// Migration helper: convert legacy SlideProvider state to CRDT
class CollabMigration {
  /// Export legacy provider state as CRDT snapshot
  static Future<Uint8List> exportLegacyToCrdt(
    SlideProvider legacyProvider,
    String documentId,
  ) async {
    final crdtDoc = await CrdtDocument.create(documentId);

    // Rebuild slides in CRDT from legacy
    for (int i = 0; i < legacyProvider.slides.length; i++) {
      final slide = legacyProvider.slides[i];
      final crdtSlideId = await crdtDoc.createSlide(layout: slide.backgroundGradient);
      await crdtDoc.setSlideTitle(crdtSlideId, slide.title);
      await crdtDoc.setSlideBody(crdtSlideId, slide.subtitle);
    }

    return await crdtDoc.exportSnapshot();
  }

  /// Import CRDT snapshot to legacy provider (one-way, for fallback)
  static Future<void> importCrdtToLegacy(
    SlideProvider legacyProvider,
    Uint8List snapshot,
  ) async {
    final crdtDoc = await CrdtDocument.fromSnapshot('temp', snapshot);
    final json = await crdtDoc.toJson();
    final data = jsonDecode(json) as Map<String, dynamic>;
    legacyProvider.fromJson(data);
  }
}