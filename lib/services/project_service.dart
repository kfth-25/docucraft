// DocuCraft — Project Service (Langkah 2: Inisialisasi Proyek)
// Kelola state dan struktur proyek
// @see docs/7-step-comparison.md#step-2-project-initialization
// @see docs/README.md

import '../models/slide.dart';
import '../models/template_suggestion.dart';

/// Project state
class Project {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<Slide> slides;
  final ProjectConfig config;
  final DesignSpec? designSpec;
  final TemplateSuggestion? selectedTemplate;

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.slides,
    required this.config,
    this.designSpec,
    this.selectedTemplate,
  });
}

/// Project configuration
class ProjectConfig {
  final double canvasWidth;
  final double canvasHeight;
  final String format;

  ProjectConfig({
    this.canvasWidth = 1920,
    this.canvasHeight = 1080,
    this.format = 'ppt169',
  });
}

/// Design specification (Step 5)
class DesignSpec {
  final String topic;
  final String subtitle;
  final String warna;
  final String style;
  final List<String> elemen;
  final int jumlahSlide;
  final String? audience;
  final String? tone;
  final Map<String, dynamic> metadata;

  DesignSpec({
    required this.topic,
    this.subtitle = '',
    required this.warna,
    required this.style,
    required this.elemen,
    required this.jumlahSlide,
    this.audience,
    this.tone,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'subtitle': subtitle,
        'warna': warna,
        'style': style,
        'elemen': elemen,
        'jumlahSlide': jumlahSlide,
        'audience': audience,
        'tone': tone,
        'metadata': metadata,
      };

  factory DesignSpec.fromJson(Map<String, dynamic> json) => DesignSpec(
        topic: json['topic'] ?? '',
        subtitle: json['subtitle'] ?? '',
        warna: json['warna'] ?? '',
        style: json['style'] ?? '',
        elemen: List<String>.from(json['elemen'] ?? []),
        jumlahSlide: json['jumlahSlide'] ?? 1,
        audience: json['audience'],
        tone: json['tone'],
        metadata: json['metadata'] ?? {},
      );

  /// Generate prompt for AI based on design spec
  String toPrompt() {
    final sb = StringBuffer();
    sb.writeln('Buat presentasi dengan detail:');
    sb.writeln('• Topik: $topic');
    if (subtitle.isNotEmpty) sb.writeln('• Subtitle: $subtitle');
    sb.writeln('• Warna: $warna');
    sb.writeln('• Style: $style');
    sb.writeln('• Elemen: ${elemen.join(", ")}');
    sb.writeln('• Jumlah slide: $jumlahSlide');
    if (audience != null) sb.writeln('• Audience: $audience');
    if (tone != null) sb.writeln('• Tone: $tone');
    return sb.toString();
  }
}

class ProjectService {
  static Project? _currentProject;

  /// Initialize new project
  static Project initProject({
    required String name,
    String format = 'ppt169',
  }) {
    final now = DateTime.now();
    _currentProject = Project(
      id: 'project_${now.millisecondsSinceEpoch}',
      name: name,
      createdAt: now,
      modifiedAt: now,
      slides: [],
      config: ProjectConfig(format: format),
    );
    return _currentProject!;
  }

  /// Get current project
  static Project? get currentProject => _currentProject;

  /// Update project
  static void updateProject(Project project) {
    _currentProject = project;
  }

  /// Add slide to project
  static void addSlide(Slide slide) {
    if (_currentProject != null) {
      _currentProject!.slides.add(slide);
    }
  }

  /// Set design spec
  static void setDesignSpec(DesignSpec spec) {
    if (_currentProject != null) {
      _currentProject = Project(
        id: _currentProject!.id,
        name: _currentProject!.name,
        createdAt: _currentProject!.createdAt,
        modifiedAt: DateTime.now(),
        slides: _currentProject!.slides,
        config: _currentProject!.config,
        designSpec: spec,
        selectedTemplate: _currentProject!.selectedTemplate,
      );
    }
  }

  /// Set selected template
  static void setSelectedTemplate(TemplateSuggestion template) {
    if (_currentProject != null) {
      _currentProject = Project(
        id: _currentProject!.id,
        name: _currentProject!.name,
        createdAt: _currentProject!.createdAt,
        modifiedAt: DateTime.now(),
        slides: _currentProject!.slides,
        config: _currentProject!.config,
        designSpec: _currentProject!.designSpec,
        selectedTemplate: template,
      );
    }
  }

  /// Clear project
  static void clear() {
    _currentProject = null;
  }
}
