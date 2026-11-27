// DocuCraft — Storage Service
// Hive-based local storage (IndexedDB otomatis di web, native di mobile)
// Kapasitas: ikut disk space device (~50GB+)

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/slide.dart';
import '../models/document.dart';

class StorageService {
  static const _boxName = 'docucraft_db';
  static const _schemaKey = 'schema_version';
  static const _currentSchemaVersion = 2; // Naikkan tiap breaking change
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    // Kalau schema berubah → reset semua data lama
    final savedVersion = _box.get(_schemaKey, defaultValue: 1);
    if (savedVersion != _currentSchemaVersion) {
      await _box.clear();
      await _box.put(_schemaKey, _currentSchemaVersion);
      debugPrint('🔄 StorageSchema: reset ke versi $_currentSchemaVersion (data lama dibersihkan)');
    }
  }

  // ── Projects List ──
  static Future<void> saveProjectList(List<Map<String, dynamic>> list) async {
    await _box.put('project_list', jsonEncode(list));
  }

  static List<Map<String, dynamic>> loadProjectList() {
    try {
      final raw = _box.get('project_list', defaultValue: '[]');
      if (raw == null || raw.toString().isEmpty) return [];
      return (jsonDecode(raw.toString()) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Per-project Slides ──
  static Future<void> saveSlidesForProject(String projectId, List<Slide> slides) async {
    final json = slides.map((s) => s.toJson()).toList();
    await _box.put('slides_$projectId', jsonEncode(json));
  }

  static List<Slide> loadSlidesForProject(String projectId) {
    try {
      final raw = _box.get('slides_$projectId', defaultValue: '[]');
      if (raw == null || raw.toString().isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw.toString());
      return list.map((j) => Slide.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('⚠️ StorageService: data corrupt — ${e.toString().substring(0, 100)}');
      return [];
    }
  }

  static Future<void> deleteProject(String projectId) async {
    await _box.delete('slides_$projectId');
    await _box.delete('chat_$projectId');
    final list = loadProjectList();
    list.removeWhere((p) => p['id'] == projectId);
    await saveProjectList(list);
  }

  // ── Legacy single-slide storage (for backward compat) ──
  static Future<void> saveSlides(List<Slide> slides) async {
    final json = slides.map((s) => s.toJson()).toList();
    await _box.put('slides_data_all', jsonEncode(json));
  }

  static List<Slide> loadSlides() {
    try {
      final raw = _box.get('slides_data_all', defaultValue: '[]');
      if (raw == null || raw.toString().isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw.toString());
      return list.map((j) => Slide.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('⚠️ StorageService: data corrupt — ${e.toString().substring(0, 100)}');
      return [];
    }
  }

  // ── User Config ──
  static Future<void> saveConfig(Map<String, dynamic> config) async {
    await _box.put('user_config', jsonEncode(config));
  }

  static Map<String, dynamic> loadConfig() {
    try {
      final raw = _box.get('user_config', defaultValue: '{}');
      if (raw == null || raw.toString().isEmpty) return {};
      return jsonDecode(raw.toString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ── Clear all ──
  static Future<void> clearAll() async {
    await _box.clear();
  }

  // ── Box stats ──
  static String get stats {
    final keys = _box.keys.length;
    final size = _box.length;
    return '$keys keys, ~${size ~/ 1024}KB used';
  }

  // ── CRDT Snapshots ──
  static Future<void> saveCrdtSnapshot(String documentId, Uint8List snapshot) async {
    await _box.put('crdt_snapshot_$documentId', snapshot);
  }

  static Future<Uint8List?> loadCrdtSnapshot(String documentId) async {
    final data = _box.get('crdt_snapshot_$documentId');
    if (data == null) return null;
    return Uint8List.fromList(data as List<int>);
  }

  // ── Documents ──

  /// Save a document list index (metadata only, not content).
  static Future<void> saveDocumentList(List<Map<String, dynamic>> list) async {
    await _box.put('document_list', jsonEncode(list));
  }

  /// Load the document list index.
  static List<Map<String, dynamic>> loadDocumentList() {
    try {
      final raw = _box.get('document_list', defaultValue: '[]');
      if (raw == null || raw.toString().isEmpty) return [];
      return (jsonDecode(raw.toString()) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Save a full document (blocks + metadata) by ID.
  static Future<void> saveDocument(String docId, Document doc) async {
    // Save full document content
    await _box.put('document_$docId', jsonEncode(doc.toJson()));

    // Update document list index (upsert)
    final list = loadDocumentList();
    final idx = list.indexWhere((e) => e['id'] == docId);
    final entry = {
      'id': docId,
      'title': doc.title,
      if (doc.folderId != null) 'folderId': doc.folderId,
      'createdAt': doc.createdAt.toIso8601String(),
      'updatedAt': doc.updatedAt.toIso8601String(),
      if (doc.coverColor != null) 'coverColor': doc.coverColor,
    };
    if (idx >= 0) {
      list[idx] = entry;
    } else {
      list.insert(0, entry);
    }
    await saveDocumentList(list);
  }

  /// Load a full document by ID.
  static Document? loadDocument(String docId) {
    try {
      final raw = _box.get('document_$docId');
      if (raw == null || raw.toString().isEmpty) return null;
      return Document.fromJson(jsonDecode(raw.toString()) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('⚠️ StorageService: document corrupt — ${e.toString().substring(0, 100)}');
      return null;
    }
  }

  /// Delete a document by ID.
  static Future<void> deleteDocument(String docId) async {
    await _box.delete('document_$docId');
    final list = loadDocumentList();
    list.removeWhere((e) => e['id'] == docId);
    await saveDocumentList(list);
  }

  // ── Document Folders ──

  /// Save folder list.
  static Future<void> saveDocumentFolders(List<Map<String, dynamic>> folders) async {
    await _box.put('doc_folders', jsonEncode(folders));
  }

  /// Load folder list.
  static List<Map<String, dynamic>> loadDocumentFolders() {
    try {
      final raw = _box.get('doc_folders', defaultValue: '[]');
      if (raw == null || raw.toString().isEmpty) return [];
      return (jsonDecode(raw.toString()) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── AI Chat Sessions ──

  /// Save the AI chat history for a project/workspace (list of message maps).
  static Future<void> saveChatSession(String projectId, List<Map<String, dynamic>> messages) async {
    await _box.put('chat_$projectId', jsonEncode(messages));
  }

  /// Load the AI chat history for a project/workspace.
  static List<Map<String, dynamic>> loadChatSession(String projectId) {
    try {
      final raw = _box.get('chat_$projectId', defaultValue: '[]');
      if (raw == null || raw.toString().isEmpty) return [];
      return (jsonDecode(raw.toString()) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
