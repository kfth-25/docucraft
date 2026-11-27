// DocuCraft — Slide Repository (Persistence Layer)
// Diekstrak dari SlideProvider demi single responsibility

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import '../models/slide.dart';
import '../services/storage_service.dart';

class SlideRepository {
  static const String _defaultProjectId = 'default';

  String _currentProjectId = _defaultProjectId;
  String _currentProjectTitle = 'Presentasi Baru';

  /// Current in-memory slide list, kept in sync by the provider so the
  /// auto-save timer always reads fresh data instead of a stale reference.
  List<Slide>? _currentSlides;

  String get currentProjectId => _currentProjectId;
  String get currentProjectTitle => _currentProjectTitle;

  Timer? _autoSaveTimer;

  /// Load slides for a project
  Future<List<Slide>> loadSlidesForProject(String projectId) async {
    try {
      final slides = StorageService.loadSlidesForProject(projectId);
      // Sanitize: skip elements with invalid dimensions
      for (final slide in slides) {
        slide.elements.removeWhere((e) =>
          !e.width.isFinite || !e.height.isFinite || e.width <= 0 || e.height <= 0);
      }
      return slides;
    } catch (e) {
      print('⚠️ Failed to load slides: $e');
      return [];
    }
  }

  /// Save slides for a project
  Future<void> saveSlidesForProject(String projectId, List<Slide> slides) async {
    try {
      await StorageService.saveSlidesForProject(projectId, slides);
      // Update project list metadata
      final list = StorageService.loadProjectList();
      final idx = list.indexWhere((p) => p['id'] == projectId);
      if (idx >= 0) {
        list[idx]['slideCount'] = slides.length;
        list[idx]['updatedAt'] = DateTime.now().toIso8601String();
        final firstTemplateId = slides.isNotEmpty ? slides.first.templateId : null;
        if (firstTemplateId != null) {
          list[idx]['templateId'] = firstTemplateId;
        }
        await StorageService.saveProjectList(list);
      }
    } catch (e) {
      print('⚠️ Failed to save slides: $e');
    }
  }

  /// Initialize storage with HTML template if empty
  Future<List<Slide>> initWithTemplate(String projectId) async {
    final slides = await loadSlidesForProject(projectId);
    if (slides.isNotEmpty) return slides;

    // Fallback to HTML template (Presenton IntroSlide style)
    try {
      final slide = Slide(
        title: 'Strategi Pemasaran Digital 2026',
        subtitle: 'Membangun brand awareness dan meningkatkan konversi melalui strategi omnichannel yang terukur.',
        backgroundGradient: 'custom_FFFFFF,FFFFFF',
        layoutId: 'intro-slide-layout',
        templateData: {
          'title': 'Strategi Pemasaran Digital 2026',
          'paragraph': 'Membangun brand awareness dan meningkatkan konversi melalui strategi omnichannel yang terukur.',
          'companyName': 'Acme Corp',
          'website': 'www.acme.com',
          'cardName': 'Kemal A.',
          'cardDate': 'Jan 2026',
          'imageUrl': 'https://images.unsplash.com/photo-1522199710521-72d69614c702?w=1200&q=80&auto=format&fit=crop',
        },
      );
      return [slide];
    } catch (e) {
      print('⚠️ Template init error: $e');
      return [Slide(title: 'Presentasi Baru', subtitle: 'Klik untuk mengedit', backgroundGradient: 'indigo')];
    }
  }

  /// Create a new project
  String createNewProject({String? title, String? templateId}) {
    final id = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final name = title ?? 'Presentasi Baru';

    final list = StorageService.loadProjectList();
    list.insert(0, {
      'id': id,
      'title': name,
      'createdAt': DateTime.now().toIso8601String(),
      'slideCount': 0,
      if (templateId != null) 'templateId': templateId,
    });
    StorageService.saveProjectList(list);

    return id;
  }

  /// Open existing project
  Future<void> openProject(String projectId, String title) async {
    _currentProjectId = projectId;
    _currentProjectTitle = title;
  }

  /// Update project title
  void updateProjectTitle(String newTitle) {
    _currentProjectTitle = newTitle;
    final list = StorageService.loadProjectList();
    final idx = list.indexWhere((p) => p['id'] == _currentProjectId);
    if (idx >= 0) {
      list[idx]['title'] = newTitle;
      StorageService.saveProjectList(list);
    }
  }

  /// Delete project
  Future<void> deleteProject(String projectId) async {
    await StorageService.deleteProject(projectId);
    if (_currentProjectId == projectId) {
      _currentProjectId = _defaultProjectId;
      _currentProjectTitle = 'Presentasi Baru';
    }
  }

  /// Get all projects for dashboard
  List<Map<String, dynamic>> getAllProjects() {
    return StorageService.loadProjectList();
  }

  /// Update the current project ID and slide list references so the auto-save
  /// timer always reads the latest values instead of stale captured copies.
  void updateState(String projectId, List<Slide> slides) {
    _currentProjectId = projectId;
    _currentSlides = slides;
  }

  /// Start periodic auto-save (every 30s). Reads the current project ID
  /// and slide list from the repository's tracked state so it always
  /// persists to the correct project even if the provider switches projects.
  void startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_currentSlides != null) {
        saveSlidesForProject(_currentProjectId, _currentSlides!);
      }
    });
  }

  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// Save CRDT snapshot for a document
  Future<void> saveSnapshot(String documentId, Uint8List snapshot) async {
    try {
      await StorageService.saveCrdtSnapshot(documentId, snapshot);
    } catch (e) {
      print('⚠️ Failed to save CRDT snapshot: $e');
    }
  }

  /// Load CRDT snapshot for a document
  Future<Uint8List?> loadSnapshot(String documentId) async {
    try {
      return await StorageService.loadCrdtSnapshot(documentId);
    } catch (e) {
      print('⚠️ Failed to load CRDT snapshot: $e');
      return null;
    }
  }
}