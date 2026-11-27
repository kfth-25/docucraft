// DocuCraft — PPTX Import Service
// Meng-parse file .pptx sungguhan menjadi model Slide internal
//
// .pptx adalah ZIP berisi file XML mengikuti spesifikasi Office Open XML.
// Importer ini mengekstrak slide, shape, teks, gambar, chart, SmartArt, dan positioning.
// Platform: mobile/desktop (memakai dart:io). Web memakai fromBytes() secara langsung.

import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/slide.dart';
// dart:io only on mobile/desktop; web uses fromBytes() which doesn't need File


/// Result of importing a .pptx file
class ImportResult {
  final List<Slide> slides;
  final String? title;
  final int totalSlides;
  final List<String> warnings;

  ImportResult({
    required this.slides,
    this.title,
    required this.totalSlides,
    List<String>? warnings,
  }) : warnings = warnings ?? [];
}

/// Import a .pptx file into Slide V2 model
class PptxImporter {
  /// Import from bytes (for web/file_picker)
  static ImportResult? fromBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive.isEmpty) return null;

      // Parse content types
      _parseContentTypes(archive);

      // Find presentation.xml
      final presFile = archive.firstWhere(
        (f) => f.name == 'ppt/presentation.xml',
      );
      if (presFile == null) return null;

      final presXml = utf8.decode(presFile.content as List<int>);
      final presDoc = XmlDocument.parse(presXml);

      // Get slide count from sldIdLst
      final sldIds = presDoc.findAllElements('p:sldId', namespace: 'http://schemas.openxmlformats.org/presentationml/2006/main');
      final slideCount = sldIds.length;

      // Parse each slide
      final slides = <Slide>[];
      final warnings = <String>[];
      String? title;

      for (var i = 0; i < slideCount; i++) {
        final slideFile = archive.firstWhere(
          (f) => f.name == 'ppt/slides/slide${i + 1}.xml',
        );
        if (slideFile == null) {
          warnings.add('Slide ${i + 1} not found in PPTX');
          continue;
        }

        final slideXml = utf8.decode(slideFile.content as List<int>);
        final parsed = _parseSlideXml(slideXml, i, warnings);
        if (parsed != null) {
          slides.add(parsed);
          if (i == 0 && parsed.title.isNotEmpty) {
            title = parsed.title;
          }
        }
      }

      return ImportResult(
        slides: slides,
        title: title,
        totalSlides: slideCount,
        warnings: warnings,
      );
    } catch (e) {
      print('⚠️ PPTX parse error: $e');
      return null;
    }
  }

  // ── Private parsers ──

  static List<String> _parseContentTypes(Archive archive) {
    final ctFile = archive.firstWhere(
      (f) => f.name == '[Content_Types].xml',
    );
    if (ctFile == null) return [];
    final ctXml = utf8.decode(ctFile.content as List<int>);
    final ctDoc = XmlDocument.parse(ctXml);
    return ctDoc.findAllElements('Override')
      .map((e) => e.getAttribute('ContentType') ?? '')
      .toList();
  }

  static Slide? _parseSlideXml(String xml, int index, List<String> warnings) {
    final doc = XmlDocument.parse(xml);

    // Check if slide is hidden
    final cSld = doc.findAllElements('p:cSld').firstOrNull;
    if (cSld != null) {
      final showAttr = cSld.getAttribute('show');
      if (showAttr == '0') {
        // Hidden slide — warn and skip
        warnings.add('Slide ${index + 1}: hidden slide, di-skip');
        return null;
      }
    }

    // Extract background — try gradient first, fallback to solid
    String bgColor = '6366F1';
    // Try gradient fill
    final gradFill = doc.findAllElements('a:gradFill').firstOrNull;
    if (gradFill != null) {
      // Try to match gradient to known DocuCraft gradients
      for (final gs in gradFill.findAllElements('a:gs')) {
        final color = gs.findAllElements('a:srgbClr').firstOrNull;
        if (color != null) {
          bgColor = color.getAttribute('val') ?? '6366F1';
          break; // Use first gradient stop color
        }
      }
    } else {
      // Fallback to solid fill
      final bgSolid = doc.findAllElements('a:solidFill')
        .map((e) => e.findAllElements('a:srgbClr'))
        .expand((e) => e)
        .firstOrNull;
      if (bgSolid != null) {
        bgColor = bgSolid.getAttribute('val') ?? '6366F1';
      }
    }

    final gradientName = _colorToGradient(bgColor);

    // Extract title from first text box or shape
    String title = 'Slide ${index + 1}';
    String subtitle = '';

    final elements = <SlideElement>[];
    int imageCount = 0, chartCount = 0, tableCount = 0;

    // Parse all sp elements (shapes/text boxes)
    for (final sp in doc.findAllElements('p:sp')) {
      final parsed = _parseShape(sp);
      if (parsed != null) {
        elements.add(SlideElement(
          type: parsed.isText ? ElementType.text : ElementType.shape,
          x: parsed.x, y: parsed.y, width: parsed.width, height: parsed.height,
          rotation: parsed.rotation,
          content: parsed.content,
          textStyle: parsed.isText ? TextStyleData(
            fontSize: parsed.fontSize,
            colorValue: parsed.colorValue,
            fontWeight: parsed.bold ? 'bold' : 'normal',
            fontStyle: parsed.italic ? 'italic' : 'normal',
            textAlign: parsed.textAlign,
          ) : null,
          shapeStyle: !parsed.isText ? ShapeStyleData(
            fillColorValue: parsed.fillColor,
          ) : null,
        ));
        // First text element with meaningful content = title
        if (title == 'Slide ${index + 1}' && parsed.content.isNotEmpty && parsed.isText) {
          title = parsed.content;
        }
      }
    }

    // Parse images (p:pic)
    for (final pic in doc.findAllElements('p:pic')) {
      final xfrm = pic.findAllElements('a:xfrm').firstOrNull;
      if (xfrm == null) continue;
      final off = xfrm.findAllElements('a:off').firstOrNull;
      final ext = xfrm.findAllElements('a:ext').firstOrNull;
      if (off == null || ext == null) continue;

      final x = (int.tryParse(off.getAttribute('x') ?? '0') ?? 0) / 12700;
      final y = (int.tryParse(off.getAttribute('y') ?? '0') ?? 0) / 12700;
      final w = (int.tryParse(ext.getAttribute('cx') ?? '0') ?? 0) / 12700;
      final h = (int.tryParse(ext.getAttribute('cy') ?? '0') ?? 0) / 12700;
      final rot = int.tryParse(xfrm.getAttribute('rot') ?? '0') ?? 0;

      elements.add(SlideElement(
        type: ElementType.image,
        x: x.toDouble(), y: y.toDouble(), width: w.toDouble(), height: h.toDouble(),
        rotation: rot / 60000.0, // EMU rotation → degrees
        imageStyle: ImageStyleData(placeholderLabel: '🖼 Image'),
      ));
      imageCount++;
    }

    // Parse tables (a:tbl)
    for (final tbl in doc.findAllElements('a:tbl')) {
      final nv = tbl.findElements('a:nvGraphicFramePr').firstOrNull;
      final cnvPr = nv?.findElements('a:cNvPr').firstOrNull;
      final rot = int.tryParse(cnvPr?.findElements('a:cNvPr').firstOrNull?.getAttribute('rot') ?? '0') ?? 0;

      // Get position from parent graphic frame
      final grpFrame = tbl.ancestors.whereType<XmlElement>().where((e) => e.name.local == 'graphicFrame').firstOrNull;
      final xfrm = grpFrame?.findElements('a:xfrm').firstOrNull;
      final off = xfrm?.findElements('a:off').firstOrNull;
      final ext = xfrm?.findElements('a:ext').firstOrNull;

      final x = off != null ? (int.tryParse(off.getAttribute('x') ?? '0') ?? 0) / 12700 : 100;
      final y = off != null ? (int.tryParse(off.getAttribute('y') ?? '0') ?? 0) / 12700 : 100;
      final w = ext != null ? (int.tryParse(ext.getAttribute('cx') ?? '0') ?? 0) / 12700 : 600;
      final h = ext != null ? (int.tryParse(ext.getAttribute('cy') ?? '0') ?? 0) / 12700 : 400;

      // Parse rows and cells
      final rows = tbl.findAllElements('a:tr').toList();
      final cols = rows.isNotEmpty ? rows.first.findAllElements('a:tc').length : 3;
      final cells = rows.map((row) =>
        row.findAllElements('a:tc').map((tc) {
          // Get text from all a:t elements in cell
          final texts = tc.findAllElements('a:t').map((t) => t.innerText).join();
          return texts;
        }).toList()
      ).toList();

      final hasHeader = tbl.findAllElements('a:tblPr').firstOrNull?.getAttribute('firstRow') == '1';
      final td = TableData(
        rows: cells.length.clamp(1, 50),
        cols: cols.clamp(1, 20),
        cells: cells,
        hasHeader: hasHeader,
      );
      elements.add(SlideElement(
        type: ElementType.table,
        x: x.toDouble(), y: y.toDouble(), width: w.toDouble(), height: h.toDouble(),
        tableData: td,
      ));
      tableCount++;
    }

    // Parse charts (c:chart)
    final chartFrames = doc.findAllElements('p:graphicFrame').where((gf) =>
      gf.innerXml.contains('c:chart')).toList();
    for (final frame in chartFrames) {
      final parsed = _parseChart(frame);
      if (parsed != null) {
        elements.add(parsed);
        chartCount++;
      }
    }

    // Parse SmartArt (dgm:)
    final smartArtFrames = doc.findAllElements('p:graphicFrame').where((gf) =>
      gf.innerXml.contains('dgm:') || gf.innerXml.contains('dgm')).toList();
    for (final frame in smartArtFrames) {
      final parsed = _parseSmartArt(frame);
      if (parsed != null) {
        elements.add(parsed);
      }
    }

    // Parse additional shapes: connectors, groups, etc.
    for (final cxnSp in doc.findAllElements('p:cxnSp')) {
      final parsed = _parseConnector(cxnSp);
      if (parsed != null) {
        elements.add(SlideElement(
          type: ElementType.shape,
          x: parsed.x, y: parsed.y, width: parsed.width, height: parsed.height,
          rotation: parsed.rotation,
          shapeStyle: ShapeStyleData(
            fillColorValue: parsed.fillColor,
            strokeColorValue: parsed.strokeColor,
            strokeWidth: parsed.strokeWidth,
            shapeType: 'line',
          ),
        ));
      }
    }

    // Parse groups (p:grpSp)
    for (final grpSp in doc.findAllElements('p:grpSp')) {
      final groupElements = _parseGroup(grpSp);
      elements.addAll(groupElements);
    }

    // Add summary warnings
    if (imageCount > 0) warnings.add('Slide ${index + 1}: $imageCount gambar diimport sebagai placeholder');
    if (tableCount > 0) warnings.add('Slide ${index + 1}: $tableCount tabel diimport');
    if (chartCount > 0) warnings.add('Slide ${index + 1}: $chartCount chart diimport sebagai placeholder');

    return Slide(
      title: title,
      subtitle: subtitle,
      backgroundGradient: gradientName,
      elements: elements,
    );
  }

  static _ParsedElement? _parseShape(XmlElement sp) {
    // Get bounding box (xfrm)
    final xfrm = sp.findAllElements('a:xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findAllElements('a:off').firstOrNull;
    final ext = xfrm.findAllElements('a:ext').firstOrNull;
    if (off == null || ext == null) return null;

    // Convert EMU to design units (1 design unit = 12700 EMU)
    final x = (int.tryParse(off.getAttribute('x') ?? '0') ?? 0) / 12700;
    final y = (int.tryParse(off.getAttribute('y') ?? '0') ?? 0) / 12700;
    final w = (int.tryParse(ext.getAttribute('cx') ?? '0') ?? 0) / 12700;
    final h = (int.tryParse(ext.getAttribute('cy') ?? '0') ?? 0) / 12700;

    // Read rotation from EMU (60000 EMU = 1 degree)
    final rotEmu = xfrm.getAttribute('rot');
    final rotation = (int.tryParse(rotEmu ?? '0') ?? 0) / 60000.0;

    // Check if it's a text box
    final nvSpPr = sp.findAllElements('p:cNvSpPr').firstOrNull;
    final isText = nvSpPr?.getAttribute('txBox') == '1';

    // Extract text content
    String content = '';
    double fontSize = 14;
    int colorValue = 0xFFFFFFFF;
    bool bold = false;
    bool italic = false;
    String textAlign = 'left';

    if (isText) {
      for (final rPr in sp.findAllElements('a:rPr')) {
        fontSize = (int.tryParse(rPr.getAttribute('sz') ?? '1400') ?? 1400) / 100;
        bold = rPr.getAttribute('b') == '1';
        italic = rPr.getAttribute('i') == '1';

        final colorEl = rPr.findAllElements('a:srgbClr').firstOrNull;
        if (colorEl != null) {
          final hex = colorEl.getAttribute('val') ?? 'FFFFFF';
          colorValue = int.tryParse('FF$hex', radix: 16) ?? 0xFFFFFFFF;
        }
      }

      final pPr = sp.findAllElements('a:pPr').firstOrNull;
      textAlign = pPr?.getAttribute('algn') ?? 'left';
    }

    // Get text runs
    for (final t in sp.findAllElements('a:t')) {
      content += t.innerText;
    }

    // Get fill color for shapes
    int fillColor = 0x4DFFFFFF;
    final solidFill = sp.findAllElements('a:solidFill').firstOrNull;
    if (solidFill != null) {
      final hex = solidFill.findAllElements('a:srgbClr').firstOrNull?.getAttribute('val');
      if (hex != null) {
        fillColor = int.tryParse('FF$hex', radix: 16) ?? fillColor;
      }
    }

    return _ParsedElement(
      x: x.toDouble(), y: y.toDouble(), width: w.toDouble(), height: h.toDouble(),
      rotation: rotation,
      content: content,
      isText: isText,
      fontSize: fontSize,
      colorValue: colorValue,
      bold: bold,
      italic: italic,
      textAlign: textAlign,
      fillColor: fillColor,
    );
  }

  static String _colorToGradient(String hex) {
    final h = hex.toUpperCase();
    const map = {
      '6366F1': 'indigo', '4F46E5': 'indigo',
      'A855F7': 'purple', 'EC4899': 'purple',
      '3B82F6': 'blue', '0891B2': 'blue',
      '10B981': 'emerald', '0D9488': 'emerald',
      'F59E0B': 'amber', 'EA580C': 'amber',
      'F43F5E': 'rose', 'BE185D': 'rose',
      '14B8A6': 'teal', '0E7490': 'teal',
    };
    return map[h] ?? 'indigo';
  }

  // ── Chart parser ──

  static SlideElement? _parseChart(XmlElement frame) {
    final xfrm = frame.findAllElements('a:xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findAllElements('a:off').firstOrNull;
    final ext = xfrm.findAllElements('a:ext').firstOrNull;
    if (off == null || ext == null) return null;

    final x = (int.tryParse(off.getAttribute('x') ?? '0') ?? 0) / 12700;
    final y = (int.tryParse(off.getAttribute('y') ?? '0') ?? 0) / 12700;
    final w = (int.tryParse(ext.getAttribute('cx') ?? '0') ?? 0) / 12700;
    final h = (int.tryParse(ext.getAttribute('cy') ?? '0') ?? 0) / 12700;
    final rot = int.tryParse(xfrm.getAttribute('rot') ?? '0') ?? 0;

    return SlideElement(
      type: ElementType.chart,
      x: x.toDouble(), y: y.toDouble(), width: w.toDouble(), height: h.toDouble(),
      rotation: rot / 60000.0,
      chartData: ChartData(
        chartType: 'bar',
        dataSets: [
          ChartDataSet(values: [10, 20, 15, 25, 30], label: 'Chart Data', colorValue: 0xFF6366F1),
        ],
        labels: ['Q1', 'Q2', 'Q3', 'Q4', 'Q5'],
      ),
    );
  }

  // ── SmartArt parser ──

  static SlideElement? _parseSmartArt(XmlElement frame) {
    final xfrm = frame.findAllElements('a:xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findAllElements('a:off').firstOrNull;
    final ext = xfrm.findAllElements('a:ext').firstOrNull;
    if (off == null || ext == null) return null;

    final x = (int.tryParse(off.getAttribute('x') ?? '0') ?? 0) / 12700;
    final y = (int.tryParse(off.getAttribute('y') ?? '0') ?? 0) / 12700;
    final w = (int.tryParse(ext.getAttribute('cx') ?? '0') ?? 0) / 12700;
    final h = (int.tryParse(ext.getAttribute('cy') ?? '0') ?? 0) / 12700;
    final rot = int.tryParse(xfrm.getAttribute('rot') ?? '0') ?? 0;

    // Try to detect SmartArt type from the XML
    String smartArtType = 'process';
    final xml = frame.innerXml.toLowerCase();
    if (xml.contains('orgchart') || xml.contains('org')) smartArtType = 'orgChart';
    else if (xml.contains('cycle')) smartArtType = 'cycle';
    else if (xml.contains('pyramid')) smartArtType = 'pyramid';
    else if (xml.contains('hierarchy')) smartArtType = 'hierarchy';
    else if (xml.contains('matrix')) smartArtType = 'matrix';
    else if (xml.contains('relationship')) smartArtType = 'relationship';

    return SlideElement(
      type: ElementType.shape,
      x: x.toDouble(), y: y.toDouble(), width: w.toDouble(), height: h.toDouble(),
      rotation: rot / 60000.0,
      content: 'SmartArt: ${smartArtType.capitalize()}',
      shapeStyle: ShapeStyleData(
        fillColorValue: 0xFF6366F1,
        shapeType: 'roundedRect',
      ),
    );
  }

  // ── Connector parser ──

  static _ParsedConnector? _parseConnector(XmlElement cxnSp) {
    final xfrm = cxnSp.findAllElements('a:xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findAllElements('a:off').firstOrNull;
    final ext = xfrm.findAllElements('a:ext').firstOrNull;
    if (off == null || ext == null) return null;

    final x = (int.tryParse(off.getAttribute('x') ?? '0') ?? 0) / 12700;
    final y = (int.tryParse(off.getAttribute('y') ?? '0') ?? 0) / 12700;
    final w = (int.tryParse(ext.getAttribute('cx') ?? '0') ?? 0) / 12700;
    final h = (int.tryParse(ext.getAttribute('cy') ?? '0') ?? 0) / 12700;
    final rot = int.tryParse(xfrm.getAttribute('rot') ?? '0') ?? 0;

    // Get connector style
    int fillColor = 0xFF6366F1;
    int? strokeColor;
    double strokeWidth = 2.0;

    final ln = cxnSp.findAllElements('a:ln').firstOrNull;
    if (ln != null) {
      strokeWidth = (int.tryParse(ln.getAttribute('w') ?? '20000') ?? 20000) / 10000;
      final solidFill = ln.findAllElements('a:solidFill').firstOrNull;
      if (solidFill != null) {
        final hex = solidFill.findAllElements('a:srgbClr').firstOrNull?.getAttribute('val');
        if (hex != null) {
          strokeColor = int.tryParse('FF$hex', radix: 16);
        }
      }
    }

    final solidFill = cxnSp.findAllElements('a:solidFill').firstOrNull;
    if (solidFill != null) {
      final hex = solidFill.findAllElements('a:srgbClr').firstOrNull?.getAttribute('val');
      if (hex != null) {
        fillColor = int.tryParse('FF$hex', radix: 16) ?? fillColor;
      }
    }

    return _ParsedConnector(
      x: x.toDouble(), y: y.toDouble(), width: w.toDouble(), height: h.toDouble(),
      rotation: rot / 60000.0,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
    );
  }

  // ── Group parser ──

  static List<SlideElement> _parseGroup(XmlElement grpSp) {
    final elements = <SlideElement>[];

    // Get group transform
    final xfrm = grpSp.findAllElements('a:xfrm').firstOrNull;
    double groupX = 0, groupY = 0, groupRotation = 0;
    if (xfrm != null) {
      final off = xfrm.findAllElements('a:off').firstOrNull;
      if (off != null) {
        groupX = (int.tryParse(off.getAttribute('x') ?? '0') ?? 0) / 12700;
        groupY = (int.tryParse(off.getAttribute('y') ?? '0') ?? 0) / 12700;
      }
      final rot = int.tryParse(xfrm.getAttribute('rot') ?? '0') ?? 0;
      groupRotation = rot / 60000.0;
    }

    // Parse shapes inside group
    for (final sp in grpSp.findAllElements('p:sp')) {
      final parsed = _parseShape(sp);
      if (parsed != null) {
        // Apply group transform to child
        final adjustedX = (parsed.x + groupX) * math.cos(groupRotation) - (parsed.y + groupY) * math.sin(groupRotation);
        final adjustedY = (parsed.x + groupX) * math.sin(groupRotation) + (parsed.y + groupY) * math.cos(groupRotation);

        elements.add(SlideElement(
          type: parsed.isText ? ElementType.text : ElementType.shape,
          x: adjustedX, y: adjustedY, width: parsed.width, height: parsed.height,
          rotation: parsed.rotation + groupRotation,
          content: parsed.content,
          textStyle: parsed.isText ? TextStyleData(
            fontSize: parsed.fontSize,
            colorValue: parsed.colorValue,
            fontWeight: parsed.bold ? 'bold' : 'normal',
            fontStyle: parsed.italic ? 'italic' : 'normal',
            textAlign: parsed.textAlign,
          ) : null,
          shapeStyle: !parsed.isText ? ShapeStyleData(
            fillColorValue: parsed.fillColor,
          ) : null,
        ));
      }
    }

    return elements;
  }

  }

/// Parsed element from shape
class _ParsedElement {
  final double x, y, width, height, rotation;
  final String content;
  final bool isText;
  final double fontSize;
  final int colorValue;
  final bool bold;
  final bool italic;
  final String textAlign;
  final int fillColor;

  _ParsedElement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.content = '',
    this.isText = true,
    this.fontSize = 14,
    this.colorValue = 0xFFFFFFFF,
    this.bold = false,
    this.italic = false,
    this.textAlign = 'left',
    this.fillColor = 0x4DFFFFFF,
  });
}

/// Parsed connector
class _ParsedConnector {
  final double x, y, width, height, rotation;
  final int fillColor;
  final int? strokeColor;
  final double strokeWidth;

  _ParsedConnector({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.fillColor,
    this.strokeColor,
    this.strokeWidth = 2.0,
  });
}

/// Helper extension for String capitalize
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}