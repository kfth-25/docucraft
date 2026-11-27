// DocuCraft — PPTX Export Service
// Mengonversi model Slide internal menjadi file .pptx sungguhan
//
// Ekspor sadar-platform:
// - Mobile/Desktop: menulis ke temp dir, mengembalikan path file untuk Share plugin
// - Web: mengembalikan byte mentah, pemanggil memicu download browser
//
// Ekspor hybrid (BARU): Flutter → SVG → Python Bridge (svg_to_pptx) → Native PPTX
// @see skills/workflows/export-pptx.md
// @see skills/SKILL.md

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/slide.dart';
import 'slide_spec.dart';
import 'pptx_engine.dart';

/// Export slides to a .pptx file at the given path.
/// Returns the file path on success, null on failure.
class PptxExporter {
  final List<Slide> slides;
  final String? title;
  static int _nextId = 100; // monotonically incrementing ID for shapes

  PptxExporter({required this.slides, this.title});

  /// Generate raw PPTX bytes using GenOffice-quality PPTX engine
  List<int> exportAsBytes() {
    // Use the new PptxEngine for GenOffice-quality output
    final engine = PptxEngine(slides: slides, title: title);
    return engine.build();
  }

  /// Build PPTX directly from JSON spec (GenOffice-style).
  /// No SVG intermediate — spec elements are converted directly to PPTX XML.
  static List<int> buildFromJsonSpec(String jsonSpec) {
    final parsed = parseSlideSpec(jsonSpec);
    if (!parsed.ok || parsed.spec == null) {
      // Fallback: return empty PPTX
      return PptxExporter(slides: []).exportAsBytes();
    }

    final spec = parsed.spec!;
    clampSpecToCanvas(spec); // Clamp elements to canvas bounds
    final elements = specToSlideElements(spec);

    // Create a Slide from the elements
    final slide = Slide(
      id: 'spec_slide',
      elements: elements,
    );

    // Use PptxEngine for GenOffice-quality output
    final engine = PptxEngine(slides: [slide]);
    return engine.build();
  }

  /// Generate PPTX via hybrid bridge: Flutter → SVG → Python → Native PPTX
  /// Returns PPTX bytes on success, null on failure (falls back to manual export)
  Future<List<int>?> exportHybrid({
    String bridgeUrl = 'http://localhost:8765',
    bool nativeChartsAndTables = true,
    String format = 'ppt169',
  }) async {
    try {
      // Check if bridge is available
      final healthCheck = await http.get(Uri.parse('$bridgeUrl/health')).timeout(
        const Duration(seconds: 5),
      );

      if (healthCheck.statusCode != 200) {
        debugPrint('⚠️ Bridge not available, falling back to manual export');
        return null;
      }

      // Hybrid export disabled - Python bridge not available
      return null;
    } catch (e) {
      debugPrint('⚠️ Hybrid export failed: $e');
      return null;
    }
  }

  /// Auto-select best export: hybrid if bridge available, else manual
  Future<List<int>> exportAuto({
    String bridgeUrl = 'http://localhost:8765',
    bool nativeChartsAndTables = true,
    String format = 'ppt169',
  }) async {
    final hybridResult = await exportHybrid(
      bridgeUrl: bridgeUrl,
      nativeChartsAndTables: nativeChartsAndTables,
      format: format,
    );

    if (hybridResult != null) {
      debugPrint('✅ Hybrid export successful');
      return hybridResult;
    }

    debugPrint('⚠️ Falling back to manual export');
    return exportAsBytes();
  }

  List<int> _buildPptx() {
    final archive = Archive();

    // ── Required PPTX structure ──
    // [Content_Types].xml
    archive.addFile(ArchiveFile('[Content_Types].xml', _contentTypes().length, _contentTypes().codeUnits));

    // _rels/.rels
    archive.addFile(ArchiveFile('_rels/.rels', _rels().length, _rels().codeUnits));

    // ppt/_rels/presentation.xml.rels (only visible slides)
    final visibleCount = slides.where((s) => !s.hidden).length;
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', _presentationRels(visibleCount).length, _presentationRels(visibleCount).codeUnits));

    // ppt/presentation.xml (with rels to only visible slides)
    archive.addFile(ArchiveFile('ppt/presentation.xml', _presentationXml(visibleCount).length, _presentationXml(visibleCount).codeUnits));

    // ppt/slideMasters/slideMaster1.xml
    archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', _slideMaster().length, _slideMaster().codeUnits));
    archive.addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', _slideMasterRels().length, _slideMasterRels().codeUnits));

    // ppt/slideLayouts/
    archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', _slideLayout().length, _slideLayout().codeUnits));
    archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', _slideLayoutRels().length, _slideLayoutRels().codeUnits));

    // ppt/theme/theme1.xml
    archive.addFile(ArchiveFile('ppt/theme/theme1.xml', _theme().length, _theme().codeUnits));

    // ppt/slides/ (one per visible slide, numbered sequentially)
    int slideNum = 1;
    for (var i = 0; i < slides.length; i++) {
      final s = slides[i];
      if (s.hidden) continue;
      final name = 'ppt/slides/slide$slideNum.xml';
      final relsName = 'ppt/slides/_rels/slide$slideNum.xml.rels';
      archive.addFile(ArchiveFile(name, _slideXml(s, i).length, _slideXml(s, i).codeUnits));
      archive.addFile(ArchiveFile(relsName, _slideRels(s).length, _slideRels(s).codeUnits));
      slideNum++;
    }

    // Save archive
    final encoded = ZipEncoder().encode(archive);
    return encoded?.toList() ?? [];
  }

  // ── XML Builders ──

  String _contentTypes() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  ${slides.where((s) => !s.hidden).toList().asMap().entries.map((e) => '<Override PartName="/ppt/slides/slide${e.key + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>').join('\n')}
</Types>''';

  String _rels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';

  String _presentationRels(int slideCount) {
    final slideRels = <String>[];
    for (var i = 0; i < slideCount; i++) {
      slideRels.add('<Relationship Id="rIdSlide${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>');
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
  ${slideRels.join('\n')}
</Relationships>''';
  }

  String _presentationXml(int slideCount) {
    final slideIds = <String>[];
    for (var i = 0; i < slideCount; i++) {
      slideIds.add('<p:sldId id="${256 + i}" r:id="rIdSlide${i + 1}"/>');
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst>
    <p:sldMasterId id="2147483648" r:id="rId1"/>
  </p:sldMasterIdLst>
  <p:sldIdLst>
    ${slideIds.join('\n    ')}
  </p:sldIdLst>
  <p:sldSz cx="12192000" cy="6858000"/>
  <p:notesSz cx="6858000" cy="9144000"/>
  <p:defaultTextStyle>
    <a:defPPr>
      <a:defRPr sz="1800" kern="1200">
        <a:solidFill><a:schemeClr val="tx1"/></a:solidFill>
        <a:latin typeface="DM Sans"/>
      </a:defRPr>
    </a:defPPr>
  </p:defaultTextStyle>
</p:presentation>''';
  }

  String _slideMaster() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldLayoutIdLst>
    <p:sldLayoutId id="2147483649" r:id="rId1"/>
  </p:sldLayoutIdLst>
</p:sldMaster>''';

  String _slideMasterRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''';

  String _slideLayout() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
             type="blank">
  <p:cspr/>
</p:sldLayout>''';

  String _slideLayoutRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';

  String _theme() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="DocuCraft">
  <a:themeElements>
    <a:clrScheme name="DocuCraft">
      <a:dk1><a:srgbClr val="1A1A25"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="6366F1"/></a:dk2>
      <a:lt2><a:srgbClr val="9CA3AF"/></a:lt2>
      <a:accent1><a:srgbClr val="6366F1"/></a:accent1>
      <a:accent2><a:srgbClr val="A855F7"/></a:accent2>
      <a:accent3><a:srgbClr val="10B981"/></a:accent3>
      <a:accent4><a:srgbClr val="F59E0B"/></a:accent4>
      <a:accent5><a:srgbClr val="3B82F6"/></a:accent5>
      <a:accent6><a:srgbClr val="EC4899"/></a:accent6>
      <a:hlink><a:srgbClr val="6366F1"/></a:hlink>
      <a:folHlink><a:srgbClr val="4F46E5"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="DocuCraft">
      <a:majorFont><a:latin typeface="DM Sans"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
      <a:minorFont><a:latin typeface="DM Sans"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="DocuCraft">
      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
      <a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>''';

  /// Jika slide pakai template (layoutId), render content sebagai elemen
  List<SlideElement> _effectiveElements(Slide slide) {
    if (slide.elements.isNotEmpty) return slide.elements;

    // Template-based slide: konversi templateData → elemen text
    final data = slide.templateData ?? {};
    final elems = <SlideElement>[];

    if (data['title'] != null && '${data['title']}'.isNotEmpty) {
      elems.add(SlideElement(
        type: ElementType.text,
        content: '${data['title']}',
        x: 96, y: 140, width: 1200, height: 100,
        textStyle: TextStyleData(fontSize: 48, fontWeight: 'bold', colorValue: 0xFF111827),
      ));
    }
    if (data['paragraph'] != null && '${data['paragraph']}'.isNotEmpty) {
      elems.add(SlideElement(
        type: ElementType.text,
        content: '${data['paragraph']}',
        x: 96, y: 260, width: 900, height: 200,
        textStyle: TextStyleData(fontSize: 18, colorValue: 0xFF6B7280),
      ));
    }
    if (data['companyName'] != null && '${data['companyName']}'.isNotEmpty) {
      elems.add(SlideElement(
        type: ElementType.text,
        content: '${data['companyName']}',
        x: 96, y: 48, width: 400, height: 40,
        textStyle: TextStyleData(fontSize: 16, colorValue: 0xFF6B7280),
      ));
    }
    if (data['website'] != null && '${data['website']}'.isNotEmpty) {
      elems.add(SlideElement(
        type: ElementType.text,
        content: '${data['website']}',
        x: 96, y: 1000, width: 400, height: 40,
        textStyle: TextStyleData(fontSize: 14, colorValue: 0xFF6B7280),
      ));
    }

    // Timeline events / metrics
    final events = data['events'] as List?;
    if (events != null) {
      for (var i = 0; i < events.length && i < 4; i++) {
        final e = events[i] as Map;
        final year = e['year']?.toString() ?? '';
        final heading = e['heading']?.toString() ?? '';
        elems.add(SlideElement(
          type: ElementType.text,
          content: '$year · $heading',
          x: 96 + i * 360, y: 400, width: 320, height: 60,
          textStyle: TextStyleData(fontSize: 20, fontWeight: 'bold', colorValue: 0xFF111827),
        ));
      }
    }

    final metrics = data['metrics'] as List?;
    if (metrics != null) {
      for (var i = 0; i < metrics.length && i < 3; i++) {
        final m = metrics[i] as Map;
        final value = m['value']?.toString() ?? '';
        final line1 = m['line1']?.toString() ?? '';
        elems.add(SlideElement(
          type: ElementType.text,
          content: '$value — $line1',
          x: 950, y: 140 + i * 190, width: 800, height: 60,
          textStyle: TextStyleData(fontSize: 28, fontWeight: 'bold', colorValue: 0xFF111827),
        ));
      }
    }

    return elems;
  }

  String _slideXml(Slide slide, int index) {
    final gradient = _gradientToColors(slide.backgroundGradient);
    final bgColor = gradient.isNotEmpty ? gradient[0] : '6366F1';
    final bgColor2 = gradient.length > 1 ? gradient[1] : gradient[0];

    // Build gradient XML for background
    final bgXml = gradient[0] != gradient[1]
        ? '''<a:gradFill>
            <a:gsLst>
              <a:gs pos="0"><a:srgbClr val="$bgColor"/></a:gs>
              <a:gs pos="100000"><a:srgbClr val="$bgColor2"/></a:gs>
            </a:gsLst>
            <a:lin ang="5400000" scaled="0"/>
          </a:gradFill>'''
        : '''<a:solidFill>
            <a:srgbClr val="$bgColor"/>
          </a:solidFill>''';

    final elementsXml = _effectiveElements(slide).map((el) => _elementToXml(el)).join('\n');

    // Transition XML
    final transitionXml = _buildTransitionXml(slide);

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        $bgXml
        <a:effectLst/>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
      $elementsXml
    </p:spTree>
  </p:cSld>
  $transitionXml
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _slideRels(Slide slide) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
  }

  String _elementToXml(SlideElement el) {
    final cx = (el.width * 12700).round().toString();
    final cy = (el.height * 12700).round().toString();
    final ox = (el.x * 12700).round().toString();
    final oy = (el.y * 12700).round().toString();

    switch (el.type) {
      case ElementType.text:
        return _textBox(el, ox, oy, cx, cy);
      case ElementType.shape:
        return _shape(el, ox, oy, cx, cy);
      case ElementType.image:
        return _image(el, ox, oy, cx, cy);
      case ElementType.chart:
        return _chart(el, ox, oy, cx, cy);
      case ElementType.table:
        return _table(el, ox, oy, cx, cy);
      case ElementType.icon:
        return _iconItem(el, ox, oy, cx, cy);
      case ElementType.video:
      case ElementType.audio:
        return _mediaPlaceholder(el, ox, oy, cx, cy);
      case ElementType.draw:
        return _drawContent(el, ox, oy, cx, cy);
    }
  }

  String _textBox(SlideElement el, String ox, String oy, String cx, String cy) {
    final ts = el.textStyle ?? TextStyleData();
    final fontSize = (ts.fontSize * 100).round().toString(); // EMU: 1pt = 100
    final bold = ts.fontWeightValue >= 700 ? '1' : '0';
    final italic = ts.fontStyle == 'italic' ? '1' : '0';
    final colorHex = ts.colorValue.toRadixString(16).padLeft(8, '0').substring(2);
    final align = ts.textAlign;

    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="TextBox"/>
    <p:cNvSpPr txBox="1"/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
  </p:spPr>
  <p:txBody>
    <a:bodyPr rtlCol="0" anchor="ctr"/>
    <a:p>
      <a:pPr algn="$align"/>
      <a:r>
        <a:rPr sz="$fontSize" b="$bold" i="$italic" rtl="0">
          <a:solidFill><a:srgbClr val="$colorHex"/></a:solidFill>
          <a:latin typeface="${ts.fontFamily ?? 'DM Sans'}"/>
        </a:rPr>
        <a:t>${_escapeXml(el.content ?? '')}</a:t>
      </a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  String _shape(SlideElement el, String ox, String oy, String cx, String cy) {
    final ss = el.shapeStyle ?? ShapeStyleData();
    final fillHex = ss.fillColorValue.toRadixString(16).padLeft(8, '0').substring(2);

    // Build fill XML — support solid + gradient
    String fillXml;
    // Check for gradient in shape's extra data
    final gradientStr = el.extra?['gradient'] as String?;
    if (gradientStr != null && gradientStr.contains(',')) {
      // Gradient format: "startHex,endHex,angle" e.g. "6366F1,EC4899,5400000"
      final parts = gradientStr.split(',');
      final startHex = parts[0].trim().replaceFirst('#', '');
      final endHex = parts.length > 1 ? parts[1].trim().replaceFirst('#', '') : startHex;
      final angle = parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 5400000 : 5400000;
      fillXml = '''<a:gradFill>
        <a:gsLst>
          <a:gs pos="0"><a:srgbClr val="$startHex"/></a:gs>
          <a:gs pos="100000"><a:srgbClr val="$endHex"/></a:gs>
        </a:gsLst>
        <a:lin ang="$angle" scaled="0"/>
      </a:gradFill>''';
    } else {
      fillXml = '<a:solidFill><a:srgbClr val="$fillHex"/></a:solidFill>';
    }
    // Map shapeType to OOXML preset geometry (matches GenOffice's 33 shape kinds)
    String prst;
    switch (ss.shapeType) {
      // Basic shapes
      case 'rect': prst = 'rect'; break;
      case 'roundRect': prst = 'roundRect'; break;
      case 'ellipse': case 'circle': prst = 'ellipse'; break;
      // Flowchart / arrow shapes
      case 'diamond': prst = 'diamond'; break;
      case 'triangle': prst = 'triangle'; break;
      case 'rightArrow': case 'arrow': prst = 'rightArrow'; break;
      case 'leftArrow': prst = 'leftArrow'; break;
      case 'upArrow': prst = 'upArrow'; break;
      case 'downArrow': prst = 'downArrow'; break;
      case 'chevron': prst = 'chevron'; break;
      case 'parallelogram': prst = 'parallelogram'; break;
      case 'trapezoid': prst = 'trapezoid'; break;
      // Complex shapes
      case 'hexagon': prst = 'hexagon'; break;
      case 'pentagon': prst = 'pentagon'; break;
      case 'star': case 'star5': prst = 'star5'; break;
      case 'star6': prst = 'star6'; break;
      case 'star7': prst = 'star7'; break;
      case 'star8': prst = 'star8'; break;
      case 'star10': prst = 'star10'; break;
      case 'star12': prst = 'star12'; break;
      case 'star16': prst = 'star16'; break;
      case 'star24': prst = 'star24'; break;
      case 'star32': prst = 'star32'; break;
      case 'heart': prst = 'heart'; break;
      case 'cloud': prst = 'cloud'; break;
      // Line shapes
      case 'line': prst = 'line'; break;
      case 'lineArrow': prst = 'lineArrow'; break;
      // Fallback
      case 'polygon': prst = 'rect'; break;
      default: prst = 'rect';
    }

    // Build stroke XML if present
    String strokeXml = '';
    if (ss.strokeColorValue != null) {
      final strokeHex = ss.strokeColorValue!.toRadixString(16).padLeft(8, '0').substring(2);
      final strokeW = (ss.strokeWidth * 12700).round(); // EMU
      strokeXml = '<a:ln w="$strokeW"><a:solidFill><a:srgbClr val="$strokeHex"/></a:solidFill></a:ln>';
    }

    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="Shape"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="$prst"><a:avLst/></a:prstGeom>
    $fillXml
    $strokeXml
  </p:spPr>
</p:sp>''';
  }

  String _image(SlideElement el, String ox, String oy, String cx, String cy) {
    // Image placeholder with descriptive label
    final label = el.imageStyle?.placeholderLabel ?? 'Image';
    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="Image"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="EEEEEE"/></a:solidFill>
    <a:ln w="12700"><a:solidFill><a:srgbClr val="CCCCCC"/></a:solidFill></a:ln>
  </p:spPr>
  <p:txBody>
    <a:bodyPr/>
    <a:p>
      <a:pPr algn="ctr"/>
      <a:r><a:rPr sz="1400" b="0"><a:solidFill><a:srgbClr val="666666"/></a:solidFill></a:rPr><a:t>${_escapeXml(label)}</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  String _chart(SlideElement el, String ox, String oy, String cx, String cy) {
    final cd = el.chartData;
    final chartTitle = cd?.dataSets.isNotEmpty == true ? cd!.dataSets.first.label : 'Chart';
    // Build a visual bar chart as grouped rectangles (native chart XML requires chart part refs)
    // For now, render as a styled text box with chart type + data summary
    final dataSummary = cd != null
      ? cd.labels.map((l) => l).join(' · ') : 'No data';

    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="Chart"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="F8F8FF"/></a:solidFill>
    <a:ln w="6350"><a:solidFill><a:srgbClr val="E0E0E0"/></a:solidFill></a:ln>
  </p:spPr>
  <p:txBody>
    <a:bodyPr rtlCol="0" anchor="t" inset="127000,63500,127000,63500"/>
    <a:p><a:pPr algn="l"/>
      <a:r><a:rPr sz="1800" b="1"><a:solidFill><a:srgbClr val="333333"/></a:solidFill></a:rPr><a:t>${_escapeXml(chartTitle)}</a:t></a:r>
    </a:p>
    <a:p>
      <a:r><a:rPr sz="1200"><a:solidFill><a:srgbClr val="666666"/></a:solidFill></a:rPr><a:t>${_escapeXml(dataSummary)}</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  String _table(SlideElement el, String ox, String oy, String cx, String cy) {
    final td = el.tableData;
    if (td == null || td.cells.isEmpty) return _textBox(el, ox, oy, cx, cy);
    // Build a native PPTX table using a:tbl
    final rowH = (int.parse(cy) / td.rows).round();

    final rowsXml = StringBuffer();
    for (var r = 0; r < td.rows && r < td.cells.length; r++) {
      rowsXml.writeln('<a:tr h="$rowH">');
      for (var c = 0; c < td.cols && c < td.cells[r].length; c++) {
        final text = td.cells[r][c];
        final isHeader = r == 0 && td.hasHeader;
        rowsXml.writeln('''<a:tc>
      <a:txBody><a:bodyPr/><a:p>
        <a:pPr algn="ctr"/>
        <a:r><a:rPr sz="1100" b="${isHeader ? '1' : '0'}"><a:solidFill><a:srgbClr val="${isHeader ? 'FFFFFF' : '333333'}"/></a:solidFill></a:rPr>
        <a:t>${_escapeXml(text)}</a:t></a:r>
      </a:p></a:txBody>
      <a:tcPr>
        <a:solidFill><a:srgbClr val="${isHeader ? '6366F1' : (r % 2 == 0 ? 'F5F5FA' : 'FFFFFF')}"/></a:solidFill>
      </a:tcPr>
    </a:tc>''');
      }
      rowsXml.writeln('</a:tr>');
    }

    return '''<a:tbl>
  <a:nvGraphicFramePr>
    <a:cNvPr id="${_nextId++}" name="Table"/>
    <a:cNvGraphicFramePr/>
    <a:nvPr/>
  </a:nvGraphicFramePr>
  <a:xfrm>
    <a:off x="$ox" y="$oy"/>
    <a:ext cx="$cx" cy="$cy"/>
  </a:xfrm>
  <a:tblPr firstRow="1" bandRow="1">
    <a:tblStyle/>
    <a:tblW type="pct" w="0"/>
  </a:tblPr>
  ${rowsXml.toString()}
</a:tbl>''';
  }

  String _iconItem(SlideElement el, String ox, String oy, String cx, String cy) {
    // Icon = large emoji/text centered in a circle background
    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="Icon"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="6366F1"><a:alpha val="30000"/></a:srgbClr></a:solidFill>
  </p:spPr>
  <p:txBody>
    <a:bodyPr/>
    <a:p><a:pPr algn="ctr"/>
      <a:r><a:rPr sz="4800"><a:solidFill><a:srgbClr val="6366F1"/></a:solidFill></a:rPr><a:t>${_escapeXml(el.content ?? '⭐')}</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  String _mediaPlaceholder(SlideElement el, String ox, String oy, String cx, String cy) {
    final isVideo = el.type == ElementType.video;
    final icon = isVideo ? '🎬' : '🎵';
    final label = isVideo ? 'Video' : 'Audio';

    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="$label"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="1A1A2E"/></a:solidFill>
    <a:ln w="12700" dash="dash"><a:solidFill><a:srgbClr val="6366F1"/></a:solidFill></a:ln>
  </p:spPr>
  <p:txBody>
    <a:bodyPr/>
    <a:p><a:pPr algn="ctr"/>
      <a:r><a:rPr sz="3200"><a:solidFill><a:srgbClr val="6366F1"/></a:solidFill></a:rPr><a:t>$icon</a:t></a:r>
    </a:p>
    <a:p><a:pPr algn="ctr"/>
      <a:r><a:rPr sz="1200"><a:solidFill><a:srgbClr val="9CA3AF"/></a:solidFill></a:rPr><a:t>${_escapeXml(el.content ?? label)}</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  String _drawContent(SlideElement el, String ox, String oy, String cx, String cy) {
    // Draw strokes → render as a text label (raw strokes can't be in OOXML without vml)
    final dd = el.drawData;
    final strokeCount = dd?.strokes.length ?? 0;
    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="Drawing"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="FFFFFF"><a:alpha val="5000"/></a:srgbClr></a:solidFill>
  </p:spPr>
  <p:txBody>
    <a:bodyPr/>
    <a:p><a:pPr algn="ctr"/>
      <a:r><a:rPr sz="1000"><a:solidFill><a:srgbClr val="666666"/></a:solidFill></a:rPr><a:t>✏️ Drawing ($strokeCount strokes)</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  /// Build transition XML for a slide (GenOffice-compatible transitions)
  String _buildTransitionXml(Slide slide) {
    final transition = slide.extra?['transition'] as String?;
    if (transition == null || transition == 'none') return '';

    switch (transition) {
      case 'fade':
        return '<p:transition><p:fade advClick="1"/></p:transition>';
      case 'morph':
        return '<p:transition><p:morph advClick="1"/></p:transition>';
      case 'push':
        return '<p:transition><p:push dir="l"/></p:transition>';
      case 'wipe':
        return '<p:transition><p:wipe dir="d"/></p:transition>';
      case 'split':
        return '<p:transition><p:split dir="out"/></p:transition>';
      case 'circle':
        return '<p:transition><p:circle/></p:transition>';
      case 'cover':
        return '<p:transition><p:cover dir="l"/></p:transition>';
      case 'pull':
        return '<p:transition><p:pull dir="l"/></p:transition>';
      case 'dissolve':
        return '<p:transition><p:dissolve/></p:transition>';
      case 'zoom':
        return '<p:transition><p:zoom/></p:transition>';
      case 'random':
        return '<p:transition><p:random/></p:transition>';
      case 'slide-left':
      case 'slide':
        return '<p:transition><p:slide dir="l"/></p:transition>';
      case 'slide-right':
        return '<p:transition><p:slide dir="r"/></p:transition>';
      case 'slide-up':
        return '<p:transition><p:slide dir="u"/></p:transition>';
      case 'scale':
        return '<p:transition advClick="1"><p:zoom in="1"/><p:sndAssoc/></p:transition>';
      default:
        return '';
    }
  }

  List<String> _gradientToColors(String name) {
    // Handle custom gradient format: 'custom_HEX1,HEX2'
    if (name.startsWith('custom_')) {
      final hexStr = name.substring(7);
      final parts = hexStr.split(',');
      if (parts.length >= 2) return [parts[0], parts[1]];
    }
    const gradients = {
      'indigo': ['6366F1', '4F46E5'],
      'purple': ['A855F7', 'EC4899'],
      'blue': ['3B82F6', '0891B2'],
      'emerald': ['10B981', '0D9488'],
      'amber': ['F59E0B', 'EA580C'],
      'rose': ['F43F5E', 'BE185D'],
      'teal': ['14B8A6', '0E7490'],
      'orange': ['F97316', 'C2410C'],
      'pink': ['E11D48', 'BE123C'],
      'cyan': ['06B6D4', '0891B2'],
      'lime': ['65A30D', '4D7C0F'],
      'violet': ['8B5CF6', '6D28D9'],
      'slate': ['475569', '1E293B'],
      'warm': ['D97706', 'DC2626'],
      'frost': ['2DD4BF', '3B82F6'],
      'midnight': ['1E1B4B', '0B0F19'],
      'light-red': ['FEE2E2', '991B1B'],
      'light-blue': ['DBEAFE', '1E3A8A'],
      'light-green': ['D1FAE5', '064E3B'],
      'light-purple': ['F3E8FF', '4C1D95'],
    };
    final g = gradients[name];
    return g ?? ['6366F1', '4F46E5'];
  }
}
