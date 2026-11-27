// DocuCraft — PPT Metadata Model
// Response dari Python server setelah generate PPT

/// PPT Metadata - hasil generate dari server
class PptMetadata {
  final String projectId;
  final String projectName;
  final String format;
  final CanvasConfig canvas;
  final List<PptPage> pages;
  final QualityCheckResult qualityCheck;
  final ExportInfo? export;
  final DesignSpec? designSpec;

  PptMetadata({
    required this.projectId,
    required this.projectName,
    required this.format,
    required this.canvas,
    required this.pages,
    required this.qualityCheck,
    this.export,
    this.designSpec,
  });

  factory PptMetadata.fromJson(Map<String, dynamic> json) {
    return PptMetadata(
      projectId: json['project_id'] ?? '',
      projectName: json['project_name'] ?? '',
      format: json['format'] ?? 'ppt169',
      canvas: CanvasConfig.fromJson(json['canvas'] ?? {}),
      pages: (json['pages'] as List?)?.map((p) => PptPage.fromJson(p)).toList() ?? [],
      qualityCheck: QualityCheckResult.fromJson(json['quality_check'] ?? {}),
      export: json['export'] != null ? ExportInfo.fromJson(json['export']) : null,
      designSpec: json['design_spec'] != null ? DesignSpec.fromJson(json['design_spec']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'project_name': projectName,
    'format': format,
    'canvas': canvas.toJson(),
    'pages': pages.map((p) => p.toJson()).toList(),
    'quality_check': qualityCheck.toJson(),
    if (export != null) 'export': export!.toJson(),
    if (designSpec != null) 'design_spec': designSpec!.toJson(),
  };
}

/// Canvas configuration
class CanvasConfig {
  final double width;
  final double height;
  final String viewBox;

  CanvasConfig({
    required this.width,
    required this.height,
    required this.viewBox,
  });

  factory CanvasConfig.fromJson(Map<String, dynamic> json) {
    return CanvasConfig(
      width: (json['width'] ?? 1920).toDouble(),
      height: (json['height'] ?? 1080).toDouble(),
      viewBox: json['viewBox'] ?? '0 0 1920 1080',
    );
  }

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'viewBox': viewBox,
  };
}

/// PPT Page - satu slide
class PptPage {
  final int pageNumber;
  final String title;
  final String? subtitle;
  final String svgContent;
  final List<PageElement> elements;
  final String? backgroundGradient;
  final PageLayout? layout;

  PptPage({
    required this.pageNumber,
    required this.title,
    this.subtitle,
    required this.svgContent,
    required this.elements,
    this.backgroundGradient,
    this.layout,
  });

  factory PptPage.fromJson(Map<String, dynamic> json) {
    return PptPage(
      pageNumber: json['page'] ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      svgContent: json['svg'] ?? '',
      elements: (json['elements'] as List?)?.map((e) => PageElement.fromJson(e)).toList() ?? [],
      backgroundGradient: json['background_gradient'],
      layout: json['layout'] != null ? PageLayout.fromJson(json['layout']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'page': pageNumber,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'svg': svgContent,
    'elements': elements.map((e) => e.toJson()).toList(),
    if (backgroundGradient != null) 'background_gradient': backgroundGradient,
    if (layout != null) 'layout': layout!.toJson(),
  };
}

/// Page element (text, shape, image, chart)
class PageElement {
  final String type; // text, shape, image, chart, table, icon
  final double x;
  final double y;
  final double width;
  final double height;
  final String? content;
  final Map<String, dynamic>? style;
  final Map<String, dynamic>? data;

  PageElement({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.content,
    this.style,
    this.data,
  });

  factory PageElement.fromJson(Map<String, dynamic> json) {
    return PageElement(
      type: json['type'] ?? 'text',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 100).toDouble(),
      height: (json['height'] ?? 50).toDouble(),
      content: json['content'],
      style: json['style'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    if (content != null) 'content': content,
    if (style != null) 'style': style,
    if (data != null) 'data': data,
  };
}

/// Page layout info
class PageLayout {
  final String layoutId;
  final String layoutName;
  final List<String> slots;

  PageLayout({
    required this.layoutId,
    required this.layoutName,
    required this.slots,
  });

  factory PageLayout.fromJson(Map<String, dynamic> json) {
    return PageLayout(
      layoutId: json['layout_id'] ?? '',
      layoutName: json['layout_name'] ?? '',
      slots: List<String>.from(json['slots'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'layout_id': layoutId,
    'layout_name': layoutName,
    'slots': slots,
  };
}

/// Quality check result
class QualityCheckResult {
  final bool passed;
  final List<String> issues;
  final List<String> fixes;
  final int totalElements;
  final int canvasViolations;
  final int textReadabilityIssues;

  QualityCheckResult({
    required this.passed,
    required this.issues,
    required this.fixes,
    required this.totalElements,
    required this.canvasViolations,
    required this.textReadabilityIssues,
  });

  factory QualityCheckResult.fromJson(Map<String, dynamic> json) {
    return QualityCheckResult(
      passed: json['passed'] ?? true,
      issues: List<String>.from(json['issues'] ?? []),
      fixes: List<String>.from(json['fixes'] ?? []),
      totalElements: json['total_elements'] ?? 0,
      canvasViolations: json['canvas_violations'] ?? 0,
      textReadabilityIssues: json['text_readability_issues'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'passed': passed,
    'issues': issues,
    'fixes': fixes,
    'total_elements': totalElements,
    'canvas_violations': canvasViolations,
    'text_readability_issues': textReadabilityIssues,
  };
}

/// Export info
class ExportInfo {
  final String format; // pptx, pdf, svg
  final String? filePath;
  final String? downloadUrl;
  final int fileSizeBytes;
  final DateTime exportedAt;

  ExportInfo({
    required this.format,
    this.filePath,
    this.downloadUrl,
    required this.fileSizeBytes,
    required this.exportedAt,
  });

  factory ExportInfo.fromJson(Map<String, dynamic> json) {
    return ExportInfo(
      format: json['format'] ?? 'pptx',
      filePath: json['file_path'],
      downloadUrl: json['download_url'],
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      exportedAt: DateTime.tryParse(json['exported_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'format': format,
    if (filePath != null) 'file_path': filePath,
    if (downloadUrl != null) 'download_url': downloadUrl,
    'file_size_bytes': fileSizeBytes,
    'exported_at': exportedAt.toIso8601String(),
  };
}

/// Design specification
class DesignSpec {
  final String topic;
  final String? subtitle;
  final String warna;
  final String style;
  final List<String> elemen;
  final int jumlahSlide;
  final String? audience;
  final String? tone;

  DesignSpec({
    required this.topic,
    this.subtitle,
    required this.warna,
    required this.style,
    required this.elemen,
    required this.jumlahSlide,
    this.audience,
    this.tone,
  });

  factory DesignSpec.fromJson(Map<String, dynamic> json) {
    return DesignSpec(
      topic: json['topic'] ?? '',
      subtitle: json['subtitle'],
      warna: json['warna'] ?? '',
      style: json['style'] ?? '',
      elemen: List<String>.from(json['elemen'] ?? []),
      jumlahSlide: json['jumlah_slide'] ?? 1,
      audience: json['audience'],
      tone: json['tone'],
    );
  }

  Map<String, dynamic> toJson() => {
    'topic': topic,
    if (subtitle != null) 'subtitle': subtitle,
    'warna': warna,
    'style': style,
    'elemen': elemen,
    'jumlah_slide': jumlahSlide,
    if (audience != null) 'audience': audience,
    if (tone != null) 'tone': tone,
  };
}
