// DocuCraft — Slide Provider (Core State Management)
// Di-refactor untuk mendelegasikan persistence, undo/redo, collab, dan AI ke adapter khusus

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/slide.dart';
import '../models/template_registry_v2.dart';
import '../services/ai_generation.dart';
import 'slide_repository.dart';
import 'undo_redo_manager.dart';
import 'collab_sync_adapter.dart';

class SlideProvider extends ChangeNotifier {
  // ── Core State ──
  List<Slide> _slides = [];
  int _currentSlideIndex = 0;
  String? _selectedElementId;
  String? _selectedSlideId;
  String _currentProjectId = 'default';
  String _currentProjectTitle = 'Presentasi Baru';

  // ── Adapters ──
  final SlideRepository _repository = SlideRepository();
  final UndoRedoManager _undoRedo = UndoRedoManager();
  final CollabSyncAdapter _collab = CollabSyncAdapter();
  // AI adapter is used directly via static methods

  // ── Getters ──
  List<Slide> get slides => _slides;
  int get currentSlideIndex => _currentSlideIndex;
  Slide? get currentSlide => _slides.isEmpty ? null : _slides[_currentSlideIndex];
  String? get selectedElementId => _selectedElementId;
  String? get selectedSlideId => _selectedSlideId;
  bool get canUndo => _undoRedo.canUndo;
  bool get canRedo => _undoRedo.canRedo;
  int get undoCount => _undoRedo.undoCount;
  int get redoCount => _undoRedo.redoCount;
  List<DateTime> get undoTimestamps => _undoRedo.undoTimestamps;
  List<DateTime> get redoTimestamps => _undoRedo.redoTimestamps;
  String get currentProjectId => _currentProjectId;
  String get currentProjectTitle => _currentProjectTitle;
  List<Slide> get visibleSlides => _slides.where((s) => !s.hidden).toList();
  int get totalSlides => _slides.length;
  bool get hasDrawStrokes => _checkDrawStrokes();

  SlideProvider() {
    // Initialize adapters with this provider
    _collab.updateProvider(this);
  }

  // ── Initialization ──
  Future<void> initFromStorage() async {
    final slides = await _repository.loadSlidesForProject(_currentProjectId);
    if (slides.isEmpty) {
      await initWithTemplate();
      return;
    }
    _slides = slides;
    _repository.updateState(_currentProjectId, _slides);
    _undoRedo.clear();
    notifyListeners();
  }

  Future<void> initWithTemplate() async {
    final slides = await _repository.initWithTemplate(_currentProjectId);
    _slides = slides;
    _repository.updateState(_currentProjectId, _slides);
    _currentSlideIndex = 0;
    _undoRedo.clear();
    notifyListeners();
    await _save();
  }

  Future<void> openProject(String projectId, String title) async {
    _currentProjectId = projectId;
    _currentProjectTitle = title;
    _repository.updateState(_currentProjectId, _slides);
    _selectedElementId = null;
    await initFromStorage();
    notifyListeners();
  }

  String createNewProject({String? title, String? templateId}) {
    final id = _repository.createNewProject(title: title, templateId: templateId);
    _currentProjectId = id;
    _currentProjectTitle = title ?? 'Presentasi Baru';
    _repository.updateState(_currentProjectId, _slides);

    // Load template jika ada templateId
    if (templateId != null) {
      _loadTemplateSlide(templateId, customData: {'title': title}).then((slide) {
        if (slide != null) {
          _slides.clear();
          _slides.add(slide);
          _currentSlideIndex = 0;
          notifyListeners();
          _save();
        }
      });
    }

    return id;
  }

  Future<void> deleteProject(String projectId) async {
    await _repository.deleteProject(projectId);
    if (_currentProjectId == projectId) {
      _currentProjectId = 'default';
      _currentProjectTitle = 'Presentasi Baru';
      _repository.updateState(_currentProjectId, _slides);
      await initFromStorage();
    }
    notifyListeners();
  }

  void updateProjectTitle(String newTitle) {
    _currentProjectTitle = newTitle;
    _repository.updateProjectTitle(newTitle);
    notifyListeners();
  }

  List<Map<String, dynamic>> getAllProjects() {
    return _repository.getAllProjects();
  }

  // ── Auto-save ──
  void startAutoSave() {
    _repository.updateState(_currentProjectId, _slides);
    _repository.startAutoSave();
  }

  void stopAutoSave() {
    _repository.stopAutoSave();
  }

  /// Public method to save current project to storage
  Future<void> saveToStorage() async {
    await _save();
  }

  Future<void> _save() async {
    _repository.updateState(_currentProjectId, _slides);
    await _repository.saveSlidesForProject(_currentProjectId, _slides);
  }

  /// Load template dari TemplateRegistryV2 dan buat Slide dengan elements dari SVG slots
  Future<Slide?> _loadTemplateSlide(String templateId, {Map<String, dynamic>? customData}) async {
    final registry = TemplateRegistryV2();
    await registry.initialize();

    final deck = registry.getDeck(templateId);
    if (deck == null) return null;

    // Ambil slide pertama dari deck (first layout)
    if (deck.slideLayoutIds.isEmpty) return null;
    final firstLayoutId = deck.slideLayoutIds.first;
    final layout = registry.getLayout(firstLayoutId);
    if (layout == null) return null;

    // Bind template slots dengan data
    final slotsData = Map<String, dynamic>.from(customData ?? {});
    final svg = registry.bindTemplateSvg(firstLayoutId, slotsData);

    // Parse SVG jadi SlideElements
    final elements = _svgToSlideElements(svg, layout);

    final slide = Slide(
      title: customData?['title'] ?? 'Slide',
      subtitle: customData?['paragraph'] ?? '',
      backgroundGradient: 'indigo',
      layoutId: firstLayoutId,
      templateId: templateId,
      templateData: customData,
      elements: elements,
    );

    return slide;
  }

  /// Convert SVG string to SlideElements
  List<SlideElement> _svgToSlideElements(String svg, LayoutTemplate layout) {
    final elements = <SlideElement>[];

    // Extract text elements
    final textRegex = RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true);
    for (final match in textRegex.allMatches(svg)) {
      final fullTag = match.group(0) as String;
      final text = match.group(1) as String;

      // Extract attributes
      final x = _extractAttr(fullTag, 'x') ?? 100.0;
      final y = _extractAttr(fullTag, 'y') ?? 100.0;
      final fontSize = _extractAttr(fullTag, 'font-size') ?? 24.0;
      final fontWeight = _extractAttrString(fullTag, 'font-weight') ?? 'normal';
      final textAlign = _extractAttrString(fullTag, 'text-anchor') ?? 'left';
      final fill = _extractAttrString(fullTag, 'fill') ?? '#000000';

      // Skip metadata/chart text
      if (text.contains('Chart:') || text.contains('chartData')) continue;

      elements.add(SlideElement(
        type: ElementType.text,
        content: text,
        x: x,
        y: y,
        width: 400,
        height: 80,
        textStyle: TextStyleData(
          fontSize: fontSize,
          colorValue: _parseColor(fill),
          fontWeight: fontWeight,
          textAlign: textAlign,
        ),
      ));
    }

    // Extract rect/shape elements
    final rectRegex = RegExp(r'<rect[^>]*\/>', dotAll: true);
    for (final match in rectRegex.allMatches(svg)) {
      final fullTag = match.group(0)!;
      final x = _extractAttr(fullTag, 'x') ?? 100.0;
      final y = _extractAttr(fullTag, 'y') ?? 100.0;
      final width = _extractAttr(fullTag, 'width') ?? 200.0;
      final height = _extractAttr(fullTag, 'height') ?? 100.0;
      final fill = _extractAttrString(fullTag, 'fill') ?? '#6366F1';
      final rx = _extractAttr(fullTag, 'rx') ?? 8.0;

      // Skip background rect (full canvas)
      if (width > 1000 && height > 500) continue;

      elements.add(SlideElement(
        type: ElementType.shape,
        x: x,
        y: y,
        width: width,
        height: height,
        shapeStyle: ShapeStyleData(
          fillColorValue: _parseColor(fill),
          borderRadius: rx,
          shapeType: 'rect',
        ),
      ));
    }

    // Extract image elements
    final imageRegex = RegExp(r'<image[^>]*\/>', dotAll: true);
    for (final match in imageRegex.allMatches(svg)) {
      final fullTag = match.group(0)! as String;
      final x = _extractAttr(fullTag, 'x') ?? 100.0;
      final y = _extractAttr(fullTag, 'y') ?? 100.0;
      final width = _extractAttr(fullTag, 'width') ?? 200.0;
      final height = _extractAttr(fullTag, 'height') ?? 150.0;
      final href = _extractAttrString(fullTag, 'href') ?? '';

      elements.add(SlideElement(
        type: ElementType.image,
        x: x,
        y: y,
        width: width,
        height: height,
        imageStyle: ImageStyleData(
          src: href,
          placeholderLabel: '🖼 Image',
        ),
      ));
    }

    return elements;
  }

  String? _extractAttrString(String tag, String attr) {
    // Escape special regex characters in attr
    final escapedAttr = attr.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (match) => '\\${match.group(0)}');
    final regex = RegExp('$escapedAttr\\s*=\\s*["\']([^"\']+)["\']');
    final match = regex.firstMatch(tag);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  double _extractAttr(String tag, String attr) {
    final value = _extractAttrString(tag, attr);
    if (value != null) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  int _parseColor(String color) {
    if (color.startsWith('#')) {
      return int.parse(color.substring(1), radix: 16) | 0xFF000000;
    }
    if (color.startsWith('var(')) {
      // CSS variable - fallback
      return 0xFF000000;
    }
    return 0xFF000000;
  }

  // ── Undo/Redo ──
  void _pushUndo() {
    _undoRedo.pushUndo(_slides, _currentSlideIndex);
  }

  void captureUndo() => _pushUndo();

  void undo() {
    final result = _undoRedo.undo();
    if (result == null) return;
    _slides = (result['slides'] as List).map((s) => Slide.fromJson(s)).toList();
    _repository.updateState(_currentProjectId, _slides);
    _currentSlideIndex = result['currentIndex'] ?? 0;
    _selectedElementId = null;
    notifyListeners();
    _save();
  }

  void redo() {
    final result = _undoRedo.redo();
    if (result == null) return;
    _slides = (result['slides'] as List).map((s) => Slide.fromJson(s)).toList();
    _repository.updateState(_currentProjectId, _slides);
    _currentSlideIndex = result['currentIndex'] ?? 0;
    _selectedElementId = null;
    notifyListeners();
    _save();
  }

  // ── Snapshot helper ──
  Map<String, dynamic> _snapshot() => {
    'slides': _slides.map((s) => s.toJson()).toList(),
    'currentIndex': _currentSlideIndex,
  };

  // ── Slide Management ──
  void switchSlide(int index) {
    if (index >= 0 && index < _slides.length) {
      _currentSlideIndex = index;
      _selectedElementId = null;
      _selectedSlideId = _slides[index].id;
      notifyListeners();
    }
  }

  void selectSlide(String slideId) {
    final index = _slides.indexWhere((s) => s.id == slideId);
    if (index >= 0) {
      _currentSlideIndex = index;
      _selectedElementId = null;
      _selectedSlideId = slideId;
      notifyListeners();
    }
  }

  void clearSlideSelection() {
    _selectedSlideId = null;
    notifyListeners();
  }

  void addSlide() {
    _pushUndo();
    final newSlide = Slide(
      title: 'Slide Baru',
      subtitle: 'Subtitle',
      backgroundGradient: 'white',
      version: 1,
      lastModifiedAt: DateTime.now(),
    );
    _slides.add(newSlide);
    _currentSlideIndex = _slides.length - 1;
    notifyListeners();
    _save();
    _collab.onLocalEdit('slide_add', slideId: newSlide.id, data: {'slide': newSlide.toJson()});
  }

  /// Load template slide dan tambahkan ke project
  Future<void> loadTemplateSlide(String templateId, {Map<String, dynamic>? customData, int? index}) async {
    final slide = await _loadTemplateSlide(templateId, customData: customData);
    if (slide != null) {
      addNewSlide(slide, index);
    }
  }

  void addNewSlide(Slide slide, int? index) {
    _pushUndo();
    if (index != null && index >= 0 && index <= _slides.length) {
      _slides.insert(index, slide);
      _currentSlideIndex = index;
    } else {
      _slides.add(slide);
      _currentSlideIndex = _slides.length - 1;
    }
    notifyListeners();
    _save();
    _collab.onLocalEdit('slide_add', slideId: slide.id, data: {'slide': slide.toJson()});
  }

  void replaceCurrentSlide(Slide newSlide) {
    if (_slides.isEmpty || _currentSlideIndex >= _slides.length) return;
    _pushUndo();
    _slides[_currentSlideIndex] = newSlide;
    _selectedElementId = null;
    notifyListeners();
    _save();
  }

  void updateSlideContent(Map<String, dynamic> newContent) {
    final slide = currentSlide;
    if (slide == null) return;
    _pushUndo();
    slide.templateData = newContent;
    if (newContent['title'] != null) slide.title = newContent['title'] as String;
    if (newContent['paragraph'] != null) slide.subtitle = newContent['paragraph'] as String;
    slide.bumpVersion();
    notifyListeners();
    _save();
    _collab.onLocalEdit('element_update', slideId: slide.id, data: newContent);
  }

  Future<void> applyLayoutToCurrentSlide(String layoutId, Map<String, dynamic> content) async {
    final slide = currentSlide;
    if (slide == null) return;

    // Try to load template from registry first
    final registry = TemplateRegistryV2();
    await registry.initialize();
    final layout = registry.getLayout(layoutId);

    if (layout != null) {
      // Bind template slots dengan data
      final slotsData = Map<String, dynamic>.from(content);
      final svg = registry.bindTemplateSvg(layoutId, content);
      final elements = _svgToSlideElements(svg, layout);

      _pushUndo();
      slide.layoutId = layoutId;
      slide.templateData = content;
      slide.elements = elements; // Replace dengan elements dari template
      if (content['title'] != null) slide.title = content['title'] as String;
      if (content['paragraph'] != null) slide.subtitle = content['paragraph'] as String;
      slide.bumpVersion();
      notifyListeners();
      _save();
    } else {
      // Fallback ke behavior lama
      _pushUndo();
      slide.layoutId = layoutId;
      slide.templateData = content;
      slide.elements.clear();
      if (content['title'] != null) slide.title = content['title'] as String;
      if (content['paragraph'] != null) slide.subtitle = content['paragraph'] as String;
      slide.bumpVersion();
      notifyListeners();
      _save();
    }
  }

  void applyAiResult(List<Slide> aiSlides, {bool replaceAll = false}) {
    _pushUndo();
    if (replaceAll) {
      _slides = aiSlides;
      _repository.updateState(_currentProjectId, _slides);
      _currentSlideIndex = 0;
    } else {
      for (final slide in aiSlides) {
        _slides.add(slide);
      }
      _currentSlideIndex = _slides.length - 1;
    }
    _selectedElementId = null;
    notifyListeners();
    _save();
  }

  void duplicateSlide() {
    if (_slides.isEmpty) return;
    _pushUndo();
    final original = _slides[_currentSlideIndex];
    final clone = Slide(
      title: original.title + ' (Copy)',
      subtitle: original.subtitle,
      backgroundGradient: original.backgroundGradient,
      elements: original.elements.map((e) => SlideElement.fromJson(e.toJson())).toList(),
      version: 1,
      lastModifiedAt: DateTime.now(),
    );
    _slides.insert(_currentSlideIndex + 1, clone);
    _currentSlideIndex++;
    notifyListeners();
    _save();
    _collab.onLocalEdit('slide_add', slideId: clone.id, data: {'slide': clone.toJson()});
  }

  void deleteSlide(int? index) {
    if (_slides.length <= 1) return;
    _pushUndo();
    final idx = index ?? _currentSlideIndex;
    final deletedSlide = _slides[idx];
    _slides.removeAt(idx);
    if (_currentSlideIndex >= _slides.length) {
      _currentSlideIndex = _slides.length - 1;
    }
    _selectedElementId = null;
    notifyListeners();
    _save();
    _collab.onLocalEdit('slide_delete', slideId: deletedSlide.id);
  }

  void reorderSlide(int oldIndex, int newIndex) {
    _pushUndo();
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _slides.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _slides.length) newIndex = _slides.length;

    final slide = _slides.removeAt(oldIndex);
    if (oldIndex < newIndex) {
      newIndex--;
    }
    if (newIndex > _slides.length) newIndex = _slides.length;
    _slides.insert(newIndex, slide);

    if (_currentSlideIndex == oldIndex) {
      _currentSlideIndex = newIndex;
    } else if (_currentSlideIndex > oldIndex && _currentSlideIndex <= newIndex) {
      _currentSlideIndex--;
    } else if (_currentSlideIndex < oldIndex && _currentSlideIndex >= newIndex) {
      _currentSlideIndex++;
    }
    notifyListeners();
    _save();
    _collab.onLocalEdit('slide_reorder', data: {'oldIndex': oldIndex, 'newIndex': newIndex});
  }

  void toggleHideSlide() {
    if (_slides.isEmpty) return;
    _pushUndo();
    _slides[_currentSlideIndex].hidden = !_slides[_currentSlideIndex].hidden;
    if (_slides[_currentSlideIndex].hidden && _currentSlideIndex > 0) {
      _currentSlideIndex--;
    }
    notifyListeners();
    _save();
  }

  // ── Element Management ──
  void selectElement(String? id) {
    _selectedElementId = id;
    notifyListeners();
  }

  void addElement(SlideElement element) {
    if (_slides.isEmpty) return;
    _pushUndo();
    final slide = _slides[_currentSlideIndex];
    slide.bumpVersion();

    // Smart positioning: find a spot that doesn't overlap existing elements
    const double canvasW = 1920;
    const double canvasH = 1080;
    final existing = slide.elements;
    double x = 120, y = 120;
    if (existing.isNotEmpty) {
      bool placed = false;
      for (double ty = 60; ty < canvasH - 150 && !placed; ty += 100) {
        for (double tx = 60; tx < canvasW - 200 && !placed; tx += 200) {
          final testL = tx, testT = ty, testR = tx + element.width, testB = ty + element.height;
          final overlaps = existing.any((e) =>
            testL < e.x + e.width && testR > e.x &&
            testT < e.y + e.height && testB > e.y);
          if (!overlaps) { x = tx; y = ty; placed = true; }
        }
      }
    }
    element.x = x;
    element.y = y;
    element.zIndex = slide.elements.length;
    element.version = 1;
    element.lastModifiedAt = DateTime.now();
    slide.elements.add(element);
    _selectedElementId = element.id;
    notifyListeners();
    _save();
    _collab.onLocalEdit('element_add', slideId: slide.id, data: {'element': element.toJson()});
  }

  void updateElementPosition(String id, double x, double y) {
    if (_slides.isEmpty) return;
    _pushUndo();
    final el = _getElement(id);
    if (el == null) return;
    el.x = x;
    el.y = y;
    el.bumpVersion();
    notifyListeners();
    _save();
    _collab.onLocalEdit('element_update', slideId: currentSlide?.id, elementId: id, data: {'x': x, 'y': y});
  }

  void updateElementSize(String id, double w, double h) {
    if (_slides.isEmpty) return;
    _pushUndo();
    final el = _getElement(id);
    if (el == null) return;
    el.width = w;
    el.height = h;
    el.bumpVersion();
    notifyListeners();
    _save();
    _collab.onLocalEdit('element_update', slideId: currentSlide?.id, elementId: id, data: {'width': w, 'height': h});
  }

  void updateElementContent(String id, String content) {
    if (_slides.isEmpty) return;
    _pushUndo();
    final el = _getElement(id);
    if (el == null) return;
    el.content = content;
    el.richRuns = null;

    // Auto-resize height for text elements based on content length
    if (el.type == ElementType.text && el.textStyle != null) {
      final fontSize = el.textStyle!.fontSize;
      final avgCharWidth = fontSize * 0.6;
      final charsPerLine = (el.width / avgCharWidth).floor();
      if (charsPerLine > 0) {
        final lineCount = (content.length / charsPerLine).ceil().clamp(1, 30);
        final newHeight = (lineCount * fontSize * 1.5) + 16;
        if (newHeight > el.height) {
          el.height = newHeight.clamp(30.0, 1080.0);
        }
      }
    }

    el.bumpVersion();
    notifyListeners();
    _save();
    _collab.onLocalEdit('element_update', slideId: currentSlide?.id, elementId: id, data: {'content': content});
  }

  void updateElementStyle(String id, Map<String, dynamic> styleUpdates) {
    if (_slides.isEmpty) return;
    _pushUndo();
    final el = _getElement(id);
    if (el == null) return;

    switch (el.type) {
      case ElementType.text:
      case ElementType.icon:
        el.textStyle ??= TextStyleData();
        for (final entry in styleUpdates.entries) {
          _applyTextStyleField(el.textStyle!, entry.key, entry.value);
        }
        break;
      case ElementType.shape:
        el.shapeStyle ??= ShapeStyleData();
        for (final entry in styleUpdates.entries) {
          _applyShapeStyleField(el.shapeStyle!, entry.key, entry.value);
        }
        break;
      case ElementType.image:
        el.imageStyle ??= ImageStyleData();
        for (final entry in styleUpdates.entries) {
          _applyImageStyleField(el.imageStyle!, entry.key, entry.value);
        }
        break;
      default:
        el.extra ??= {};
        el.extra!.addAll(styleUpdates);
    }

    el.bumpVersion();
    notifyListeners();
    _save();
    _collab.onLocalEdit('element_update', slideId: currentSlide?.id, elementId: id, data: styleUpdates);
  }

  void _applyTextStyleField(TextStyleData style, String key, dynamic value) {
    switch (key) {
      case 'fontSize': style.fontSize = (value as num).toDouble(); break;
      case 'colorValue': style.colorValue = value as int; break;
      case 'fontWeight': style.fontWeight = value as String; break;
      case 'fontStyle': style.fontStyle = value as String; break;
      case 'textAlign': style.textAlign = value as String; break;
      case 'fontFamily': style.fontFamily = value as String?; break;
      case 'letterSpacing': style.letterSpacing = (value as num).toDouble(); break;
      case 'lineHeight': style.lineHeight = (value as num).toDouble(); break;
    }
  }

  void _applyShapeStyleField(ShapeStyleData style, String key, dynamic value) {
    switch (key) {
      case 'fillColorValue': style.fillColorValue = value as int; break;
      case 'strokeColorValue': style.strokeColorValue = value as int?; break;
      case 'strokeWidth': style.strokeWidth = (value as num).toDouble(); break;
      case 'borderRadius': style.borderRadius = (value as num).toDouble(); break;
      case 'opacity': style.opacity = (value as num).toDouble(); break;
    }
  }

  void _applyImageStyleField(ImageStyleData style, String key, dynamic value) {
    switch (key) {
      case 'src': style.src = value as String?; break;
      case 'placeholderLabel': style.placeholderLabel = value as String?; break;
      case 'opacity': style.opacity = (value as num).toDouble(); break;
      case 'borderRadius': style.borderRadius = (value as num).toDouble(); break;
    }
  }

  void deleteElement(String id) {
    if (_slides.isEmpty) return;
    _pushUndo();
    _slides[_currentSlideIndex].elements.removeWhere((e) => e.id == id);
    if (_selectedElementId == id) _selectedElementId = null;
    notifyListeners();
    _save();
    _collab.onLocalEdit('element_delete', slideId: currentSlide?.id, elementId: id);
  }

  void updateSlideBackground(String gradient) {
    if (_slides.isEmpty) return;
    _pushUndo();
    _slides[_currentSlideIndex].backgroundGradient = gradient;
    _slides[_currentSlideIndex].bumpVersion();
    notifyListeners();
    _save();
  }

  void updateSlideBackgroundCustom(Color color1, Color color2) {
    if (_slides.isEmpty) return;
    _pushUndo();
    final hex1 = color1.toARGB32().toRadixString(16).substring(2).toUpperCase();
    final hex2 = color2.toARGB32().toRadixString(16).substring(2).toUpperCase();
    _slides[_currentSlideIndex].backgroundGradient = 'custom_$hex1,$hex2';
    _slides[_currentSlideIndex].bumpVersion();
    notifyListeners();
    _save();
  }

  void updateSlideTitle(String title) {
    if (_slides.isEmpty) return;
    _pushUndo();
    _slides[_currentSlideIndex].title = title;
    _slides[_currentSlideIndex].bumpVersion();
    notifyListeners();
    _save();
  }

  /// Update text layout metrics (contentHeight, overflowXPx) on an element.
  /// Called by SlideCanvas after actual text layout measurement.
  /// Does NOT push to undo or trigger collab sync — layout metrics are transient
  /// measurement data, not user edits.
  void updateTextLayoutMetrics(String id, {double? contentHeight, double? overflowXPx}) {
    if (_slides.isEmpty) return;
    final el = _getElement(id);
    if (el == null || el.type != ElementType.text) return;
    el.textStyle ??= TextStyleData();
    el.textStyle!.contentHeight = contentHeight;
    el.textStyle!.overflowXPx = overflowXPx;
    // No undo, no collab, no save — this is transient measurement data.
    // We just notify listeners so QC picks up the fresh metrics.
    notifyListeners();
  }

  void updateElementZIndex(String id, int newZIndex) {
    if (_slides.isEmpty) return;
    _pushUndo();
    final el = _getElement(id);
    if (el == null) return;
    el.zIndex = newZIndex;
    el.bumpVersion();
    notifyListeners();
    _save();
  }

  void bringForward(String id) {
    if (_slides.isEmpty) return;
    final el = _getElement(id);
    if (el == null) return;
    final maxZ = _slides[_currentSlideIndex].elements
        .fold(0, (int max, e) => e.zIndex > max ? e.zIndex : max);
    if (el.zIndex < maxZ) {
      updateElementZIndex(id, el.zIndex + 1);
    }
  }

  void sendBackward(String id) {
    if (_slides.isEmpty) return;
    final el = _getElement(id);
    if (el == null || el.zIndex <= 0) return;
    updateElementZIndex(id, el.zIndex - 1);
  }

  // ── Presenter Notes ──
  void setPresenterNotes(String notes) {
    if (currentSlide == null) return;
    currentSlide!.extra ??= {};
    currentSlide!.extra!['notes'] = notes;
    notifyListeners();
    _save();
  }

  String? getPresenterNotes() {
    return currentSlide?.extra?['notes'] as String?;
  }

  void updateCurrentSlideBg(String gradientName) {
    if (_slides.isEmpty) return;
    _pushUndo();
    _slides[_currentSlideIndex].backgroundGradient = gradientName;
    notifyListeners();
    _save();
  }

  // ── Bulk Operations ──
  void applyTemplate(String template) {
    _pushUndo();
    const gradientMap = <String, String>{
      'blue-corporate': 'blue',
      'dark-minimal': 'teal',
      'purple-creative': 'purple',
      'green-nature': 'emerald',
      'amber-warm': 'amber',
      'clean-white': 'indigo',
    };
    const titleSizeMap = <String, double>{
      'blue-corporate': 42,
      'dark-minimal': 48,
      'purple-creative': 40,
      'green-nature': 36,
      'amber-warm': 44,
      'clean-white': 38,
    };
    const bodySizeMap = <String, double>{
      'blue-corporate': 18,
      'dark-minimal': 20,
      'purple-creative': 16,
      'green-nature': 16,
      'amber-warm': 18,
      'clean-white': 14,
    };
    final centerAlign = template == 'blue-corporate' || template == 'dark-minimal' || template == 'amber-warm';

    final bg = gradientMap[template] ?? 'indigo';
    final titleSize = titleSizeMap[template] ?? 36;
    final bodySize = bodySizeMap[template] ?? 18;

    for (var slide in _slides) {
      slide.backgroundGradient = bg;
      for (var el in slide.elements) {
        if (el.type == ElementType.text && el.textStyle != null) {
          if (el.textStyle!.fontSize >= 30) {
            el.textStyle!.fontSize = titleSize;
            if (centerAlign) el.textStyle!.textAlign = 'center';
          } else {
            el.textStyle!.fontSize = bodySize;
          }
        }
      }
      if (centerAlign) {
        final hasAccent = slide.elements.any((e) =>
          e.type == ElementType.shape && e.height <= 10 && e.height >= 4);
        if (!hasAccent) {
          slide.elements.add(SlideElement(
            type: ElementType.shape,
            x: 760, y: 0, width: 400, height: 6,
            shapeStyle: ShapeStyleData(
              fillColorValue: 0x99FFFFFF,
              borderRadius: 0,
            ),
            zIndex: -1,
          ));
        }
      }
      slide.bumpVersion();
    }
    notifyListeners();
    _save();
  }

  void applyLayout(String type) {
    if (currentSlide == null) return;
    final slide = currentSlide!;
    _pushUndo();
    slide.bumpVersion();

    if (type == 'blank') {
      slide.elements.clear();
      notify();
      return;
    }

    if (slide.elements.isNotEmpty) {
      if (type == 'title' && slide.elements.length == 1) {
        final el = slide.elements.first;
        el.x = 60; el.y = 360; el.width = 800; el.height = 120;
        if (el.textStyle != null) {
          el.textStyle!.fontSize = 48;
          el.textStyle!.fontWeight = 'bold';
          el.textStyle!.textAlign = 'center';
        }
      } else if (type == 'content') {
        for (var i = 0; i < slide.elements.length; i++) {
          final el = slide.elements[i];
          if (i == 0) {
            el.x = 60; el.y = 60; el.width = 800; el.height = 80;
            if (el.textStyle != null) {
              el.textStyle!.fontSize = 36;
              el.textStyle!.fontWeight = 'bold';
            }
          } else {
            el.x = 60; el.y = 160 + (i - 1) * 200; el.width = 800; el.height = 400;
            if (el.textStyle != null && el.textStyle!.fontSize < 30) {
              el.textStyle!.fontSize = 18;
            }
          }
        }
      } else if (type == 'two-column') {
        final mid = (slide.elements.length / 2).ceil();
        for (var i = 0; i < slide.elements.length; i++) {
          final el = slide.elements[i];
          if (i < mid) {
            el.x = 60; el.y = 200 + (i * 150); el.width = 400; el.height = 500;
          } else {
            el.x = 520; el.y = 200 + ((i - mid) * 150); el.width = 400; el.height = 500;
          }
          if (el.textStyle != null && el.textStyle!.fontSize >= 30) {
            el.textStyle!.textAlign = 'center';
          }
        }
      } else if (type == 'image-text') {
        final firstNonText = slide.elements.indexWhere((e) => e.type != ElementType.text);
        if (firstNonText >= 0) {
          slide.elements[firstNonText].x = 60;
          slide.elements[firstNonText].y = 150;
          slide.elements[firstNonText].width = 500;
          slide.elements[firstNonText].height = 600;
        }
        for (var i = 0; i < slide.elements.length; i++) {
          if (i != firstNonText) {
            slide.elements[i].x = 600; slide.elements[i].y = 200;
            slide.elements[i].width = 380; slide.elements[i].height = 400;
          }
        }
      }
    } else {
      if (type == 'title') {
        slide.elements.add(SlideElement(
          type: ElementType.text, content: 'Judul Presentasi',
          x: 60, y: 360, width: 800, height: 120,
          textStyle: TextStyleData(fontSize: 48, fontWeight: 'bold', textAlign: 'center'),
        ));
      } else if (type == 'content') {
        slide.elements.add(SlideElement(
          type: ElementType.text, content: 'Judul',
          x: 60, y: 60, width: 800, height: 80,
          textStyle: TextStyleData(fontSize: 36, fontWeight: 'bold'),
        ));
        slide.elements.add(SlideElement(
          type: ElementType.text, content: 'Konten utama',
          x: 60, y: 300, width: 800, height: 400,
          textStyle: TextStyleData(fontSize: 18),
        ));
      } else if (type == 'two-column') {
        slide.elements.add(SlideElement(
          type: ElementType.text, content: 'Kolom Kiri',
          x: 60, y: 200, width: 400, height: 500,
          textStyle: TextStyleData(fontSize: 16, textAlign: 'center'),
        ));
        slide.elements.add(SlideElement(
          type: ElementType.text, content: 'Kolom Kanan',
          x: 520, y: 200, width: 400, height: 500,
          textStyle: TextStyleData(fontSize: 16, textAlign: 'center'),
        ));
      } else if (type == 'image-text') {
        slide.elements.add(SlideElement(
          type: ElementType.image, x: 60, y: 150, width: 500, height: 600,
        ));
        slide.elements.add(SlideElement(
          type: ElementType.text, content: 'Deskripsi',
          x: 600, y: 200, width: 380, height: 400,
          textStyle: TextStyleData(fontSize: 18),
        ));
      }
    }
    notify();
    _save();
  }

  // ── Manual notify ──
  void notify() {
    notifyListeners();
    _save();
  }

  // ── JSON Serialization ──
  Map<String, dynamic> toJson() => _snapshot();

  void fromJson(Map<String, dynamic> json) {
    _slides = (json['slides'] as List).map((s) => Slide.fromJson(s)).toList();
    _currentSlideIndex = json['currentIndex'] ?? 0;
    _undoRedo.clear();
    notifyListeners();
    _save();
  }

  // ── Internal helpers ──
  SlideElement? _getElement(String id) {
    if (_slides.isEmpty || _currentSlideIndex >= _slides.length) return null;
    try {
      return _slides[_currentSlideIndex].elements.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  bool _checkDrawStrokes() {
    if (_slides.isEmpty || _currentSlideIndex >= _slides.length) return false;
    final slide = _slides[_currentSlideIndex];
    return slide.elements.any((e) =>
      e.type == ElementType.draw &&
      e.drawData != null &&
      e.drawData!.strokes.isNotEmpty
    );
  }

  // ── AI Batch Snapshots (for QC revert) ──
  final Map<int, List<Slide>> _snapshots = {};
  int _batchIdCounter = 0;

  /// Begin an undoable batch. Returns a batch ID for restoreSnapshot.
  int beginBatch() {
    _batchIdCounter++;
    _snapshots[_batchIdCounter] = _deepCopySlides(_slides);
    return _batchIdCounter;
  }

  /// Restore slides to a previously saved batch snapshot.
  void restoreSnapshot(int batchId) {
    final snap = _snapshots.remove(batchId);
    if (snap == null) return;
    _slides = snap;
    notifyListeners();
    _save();
  }

  List<Slide> _deepCopySlides(List<Slide> slides) {
    return slides.map((s) => Slide.fromJson(s.toJson())).toList();
  }

  // ── Collab Sync API ──
  Future<void> initCollab({
    required String documentId,
    required String userId,
    required String userName,
  }) async {
    await _collab.init(documentId: documentId, userId: userId, userName: userName);
  }

  void disposeCollab() {
    _collab.dispose();
  }

  // ── AI Generation API ──
  Future<SvgGenerateResult> generateFromPrompt(String prompt, {String? model}) async {
    return await AiGenerationService.sketchToDesignSvg(Uint8List(0), prompt, model: model);
  }

  Future<SvgGenerateResult> redesignSlide(String prompt, {String? model}) async {
    return await AiGenerationService.sketchToDesignSvg(Uint8List(0), prompt, currentSlide: currentSlide, model: model);
  }

  Future<SvgGenerateResult> generateFromSketch(String prompt, {String? model}) async {
    return await AiGenerationService.generateFromSketchSvg(
      {'regions': [], 'strokeCount': 0, 'canvasSize': {'width': 1920, 'height': 1080}},
      prompt,
      currentSlide: currentSlide,
      model: model,
    );
  }

  Future<List<String>> generateOutline(String topic, {String? model}) async {
    return [];
  }

  Future<SvgGenerateResult> generateSingleSlide(String topic, {String? model}) async {
    return await AiGenerationService.sketchToDesignSvg(Uint8List(0), topic, model: model);
  }

  Future<String> checkAiConnection() async {
    return 'online';
  }

  // ── Sync Engine API (for backward compatibility) ──
  void syncAddSlide(Slide slide) {
    _pushUndo();
    _slides.add(slide);
    notifyListeners();
    _save();
  }

  void syncRemoveSlide(String slideId) {
    _pushUndo();
    final idx = _slides.indexWhere((s) => s.id == slideId);
    if (idx >= 0 && _slides.length > 1) {
      _slides.removeAt(idx);
      if (_currentSlideIndex >= _slides.length) {
        _currentSlideIndex = _slides.length - 1;
      }
      notifyListeners();
      _save();
    }
  }

  void syncAddElementToSlide(String slideId, SlideElement element) {
    final slide = _slides.where((s) => s.id == slideId).firstOrNull;
    if (slide != null) {
      _pushUndo();
      slide.elements.add(element);
      slide.bumpVersion();
      notifyListeners();
      _save();
    }
  }

  void syncUpdateElement(String slideId, String elementId, String content) {
    final slide = _slides.where((s) => s.id == slideId).firstOrNull;
    if (slide != null) {
      final el = slide.elements.where((e) => e.id == elementId).firstOrNull;
      if (el != null) {
        el.content = content;
        el.richRuns = null;
        el.bumpVersion();
        slide.bumpVersion();
        notifyListeners();
        _save();
      }
    }
  }

  void syncRemoveElement(String slideId, String elementId) {
    final slide = _slides.where((s) => s.id == slideId).firstOrNull;
    if (slide != null) {
      _pushUndo();
      slide.elements.removeWhere((e) => e.id == elementId);
      slide.bumpVersion();
      notifyListeners();
      _save();
    }
  }

  void syncApplySnapshot(List<Slide> remoteSlides) {
    if (remoteSlides.isEmpty) return;
    _pushUndo();
    _slides = remoteSlides;
    if (_currentSlideIndex >= _slides.length) {
      _currentSlideIndex = 0;
    }
    notifyListeners();
    _save();
  }

  void updateSlideTitleBySync(String slideId, String title) {
    final slide = _slides.where((s) => s.id == slideId).firstOrNull;
    if (slide != null) {
      slide.title = title;
      slide.bumpVersion();
      notifyListeners();
      _save();
    }
  }

  void updateSlideBgBySync(String slideId, String gradient) {
    final slide = _slides.where((s) => s.id == slideId).firstOrNull;
    if (slide != null) {
      slide.backgroundGradient = gradient;
      slide.bumpVersion();
      notifyListeners();
      _save();
    }
  }
}