// DocuCraft — Document Provider (State Management for Documents)
// Mengelola CRUD dokumen, editing block, folder, dan integrasi CRDT.
// Lokal saja (tidak terhubung ke workspace GenOffice).

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../services/storage_service.dart';

class DocumentProvider extends ChangeNotifier {
  // ── Core State ──
  Document? _currentDocument;
  List<Map<String, dynamic>> _documentList = [];
  List<DocumentFolder> _folders = [];
  String? _currentFolderId;

  // ── Auto-save ──
  Timer? _autoSaveTimer;
  bool _dirty = false;

  // ── Getters ──
  Document? get currentDocument => _currentDocument;
  List<Map<String, dynamic>> get documentList => _documentList;
  List<DocumentFolder> get folders => _folders;
  String? get currentFolderId => _currentFolderId;
  bool get hasUnsavedChanges => _dirty;

  // ── Initialization ──
  Future<void> init() async {
    _documentList = StorageService.loadDocumentList();
    _folders = StorageService.loadDocumentFolders()
        .map((f) => DocumentFolder.fromJson(f))
        .toList();
    notifyListeners();
  }

  // ── Document CRUD ──

  /// Create a new empty document and open it.
  Future<Document> createDocument({String? title, String? folderId}) async {
    final doc = Document(
      title: title ?? 'Untitled Document',
      folderId: folderId ?? _currentFolderId,
      blocks: [DocumentBlock.paragraph('')],
    );
    _currentDocument = doc;
    _dirty = true;
    await _saveCurrent();
    _documentList = StorageService.loadDocumentList();
    notifyListeners();
    return doc;
  }

  /// Open an existing document by ID.
  Future<void> openDocument(String docId) async {
    final doc = StorageService.loadDocument(docId);
    if (doc == null) return;
    _currentDocument = doc;
    _dirty = false;
    notifyListeners();
  }

  /// Save the current document to storage.
  Future<void> saveCurrent() async {
    await _saveCurrent();
  }

  Future<void> _saveCurrent() async {
    if (_currentDocument == null) return;
    _currentDocument!.updatedAt = DateTime.now();
    await StorageService.saveDocument(_currentDocument!.id, _currentDocument!);
    _dirty = false;
    _documentList = StorageService.loadDocumentList();
    notifyListeners();
  }

  /// Delete a document by ID.
  Future<void> deleteDocument(String docId) async {
    await StorageService.deleteDocument(docId);
    if (_currentDocument?.id == docId) {
      _currentDocument = null;
    }
    _documentList = StorageService.loadDocumentList();
    notifyListeners();
  }

  /// Update document title.
  void updateTitle(String newTitle) {
    if (_currentDocument == null) return;
    _currentDocument!.title = newTitle;
    _markDirty();
  }

  // ── Block Editing ──

  /// Insert a new block after the given index (or at end if null).
  void insertBlock(int? afterIndex, DocumentBlock block) {
    if (_currentDocument == null) return;
    final idx = afterIndex ?? (_currentDocument!.blocks.length - 1);
    _currentDocument!.blocks.insert(idx + 1, block);
    _markDirty();
  }

  /// Update a block at the given index.
  void updateBlock(int index, DocumentBlock updated) {
    if (_currentDocument == null) return;
    if (index < 0 || index >= _currentDocument!.blocks.length) return;
    _currentDocument!.blocks[index] = updated;
    _markDirty();
  }

  /// Delete a block at the given index (keeps at least one block).
  void deleteBlock(int index) {
    if (_currentDocument == null) return;
    if (_currentDocument!.blocks.length <= 1) return;
    _currentDocument!.blocks.removeAt(index);
    _markDirty();
  }

  /// Change block type at the given index.
  void changeBlockType(int index, BlockType newType) {
    if (_currentDocument == null) return;
    if (index < 0 || index >= _currentDocument!.blocks.length) return;
    _currentDocument!.blocks[index].type = newType;
    _markDirty();
  }

  /// Move a block from one position to another.
  void moveBlock(int fromIndex, int toIndex) {
    if (_currentDocument == null) return;
    final blocks = _currentDocument!.blocks;
    if (fromIndex < 0 || fromIndex >= blocks.length) return;
    if (toIndex < 0 || toIndex >= blocks.length) return;
    final block = blocks.removeAt(fromIndex);
    blocks.insert(toIndex, block);
    _markDirty();
  }

  /// Replace the whole document content with plain text (split into paragraphs).
  /// Used to sync GenOffice-authored document content into the Flutter workspace.
  void replaceContent(String text) {
    if (_currentDocument == null) return;
    if (text.trim().isEmpty) return;
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return;
    _currentDocument!.blocks = paragraphs
        .map((p) => DocumentBlock.paragraph(p))
        .toList();
    _dirty = true;
    notifyListeners();
    // Persist immediately so content survives navigation / dispose.
    _saveCurrent();
  }

  /// Replace the whole document with structured blocks from GenOffice,
  /// preserving bold/italic/underline runs, headings, lists, and tables.
  void replaceFromGenOffice(List<dynamic> blocks) {
    if (_currentDocument == null) return;
    if (blocks.isEmpty) return;
    final converted = <DocumentBlock>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final type = map['type']?.toString() ?? 'paragraph';

      if (type == 'table') {
        final tableData = (map['tableData'] as List?)
            ?.map((row) => (row as List).map((c) => c?.toString() ?? '').toList())
            .toList();
        if (tableData != null && tableData.isNotEmpty) {
          converted.add(DocumentBlock(
            type: BlockType.table,
            tableData: tableData,
            tableHasHeader: map['hasHeader'] == true,
            tableColWidthsPct: (map['colWidthsPct'] as List?)
                ?.map((w) => (w as num).toDouble())
                .toList(),
            tableCells: (map['cells'] as List?)
                ?.map((row) => (row as List)
                    .map((c) => TableBlockCell.fromJson(Map<String, dynamic>.from(c as Map)))
                    .toList())
                .toList(),
          ));
        }
        continue;
      }

      final runs = (map['runs'] as List?)
          ?.map((r) {
            if (r is! Map) return TextRun(text: r?.toString() ?? '');
            return TextRun(
              text: r['text']?.toString() ?? '',
              bold: r['bold'] == true,
              italic: r['italic'] == true,
              underline: r['underline'] == true,
              strikethrough: r['strike'] == true,
              color: r['color']?.toString(),
              fontFamily: r['font']?.toString(),
              fontSize: r['sizePt'] != null ? (r['sizePt'] as num).toDouble() : null,
            );
          })
          .toList() ??
          [];

      BlockType bt = BlockType.paragraph;
      if (type == 'heading') {
        final level = (map['level'] as num?)?.toInt() ?? 1;
        bt = level <= 1
            ? BlockType.heading1
            : level == 2
                ? BlockType.heading2
                : BlockType.heading3;
      } else if (type == 'bulletList') {
        bt = BlockType.bulletList;
      } else if (type == 'numberedList') {
        bt = BlockType.numberedList;
      }

      converted.add(DocumentBlock(type: bt, runs: runs));
    }
    if (converted.isEmpty) return;
    _currentDocument!.blocks = converted;
    _dirty = true;
    notifyListeners();
    // Persist immediately so content survives navigation / dispose.
    _saveCurrent();
  }

  // ── Folders ──

  /// Create a new folder.
  Future<DocumentFolder> createFolder(String name, {String color = '#2563EB'}) async {
    final folder = DocumentFolder(name: name, color: color);
    _folders.add(folder);
    await StorageService.saveDocumentFolders(
        _folders.map((f) => f.toJson()).toList());
    notifyListeners();
    return folder;
  }

  /// Delete a folder (documents inside become unlinked, not deleted).
  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    await StorageService.saveDocumentFolders(
        _folders.map((f) => f.toJson()).toList());
    notifyListeners();
  }

  /// Set current folder filter.
  void setCurrentFolder(String? folderId) {
    _currentFolderId = folderId;
    notifyListeners();
  }

  /// Move a document to a folder.
  Future<void> moveToFolder(String docId, String? folderId) async {
    final doc = StorageService.loadDocument(docId);
    if (doc == null) return;
    doc.folderId = folderId;
    await StorageService.saveDocument(docId, doc);
    _documentList = StorageService.loadDocumentList();
    notifyListeners();
  }

  /// Get documents filtered by current folder.
  List<Map<String, dynamic>> get filteredDocuments {
    if (_currentFolderId == null) return _documentList;
    return _documentList.where((d) => d['folderId'] == _currentFolderId).toList();
  }

  /// Get all saved documents as Document objects.
  List<Document> getAllDocuments() {
    return _documentList.map((m) => Document(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? 'Untitled',
      blocks: [],
    )).toList();
  }

  // ── Auto-save ──

  void startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_dirty) _saveCurrent();
    });
  }

  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  void _markDirty() {
    _dirty = true;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoSave();
    super.dispose();
  }
}
