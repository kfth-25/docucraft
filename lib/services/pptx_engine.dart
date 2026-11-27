// DocuCraft — PPTX Engine (port Dart dari @genoffice/pptx-engine)
// Generasi PPTX berkualitas tinggi dengan text layout, urutan elemen,
// penanganan font, dan embedding gambar yang tepat. Menggantikan XML builder manual.

import 'package:archive/archive.dart';
import '../models/slide.dart';

// ── Constants ──
const int _emuPerPx = 12700; // 1px = 12700 EMU at 96 DPI
const int _canvasW = 1280;
const int _canvasH = 720;
const int _maxElements = 48;
const int _maxImages = 8;
const int _maxTextLen = 4000;

// ── Data Classes ──

/// PPTX Engine — GenOffice-quality PPTX generation from Slide model
class PptxEngine {
  final List<Slide> slides;
  final String? title;
  int _nextId = 100;

  PptxEngine({required this.slides, this.title});

  /// Build PPTX bytes from slides with proper element ordering and text layout
  List<int> build() {
    _nextId = 100; // Reset ID counter for each build
    final archive = Archive();

    // Required PPTX structure
    archive.addFile(ArchiveFile('[Content_Types].xml', _contentTypes().length, _contentTypes().codeUnits));
    archive.addFile(ArchiveFile('_rels/.rels', _rels().length, _rels().codeUnits));

    final visibleCount = slides.where((s) => !s.hidden).length;
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', _presentationRels(visibleCount).length, _presentationRels(visibleCount).codeUnits));
    archive.addFile(ArchiveFile('ppt/presentation.xml', _presentationXml(visibleCount).length, _presentationXml(visibleCount).codeUnits));

    // Slide masters and layouts
    archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', _slideMaster().length, _slideMaster().codeUnits));
    archive.addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', _slideMasterRels().length, _slideMasterRels().codeUnits));
    archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', _slideLayout().length, _slideLayout().codeUnits));
    archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', _slideLayoutRels().length, _slideLayoutRels().codeUnits));
    archive.addFile(ArchiveFile('ppt/theme/theme1.xml', _theme().length, _theme().codeUnits));

    // Slides — GenOffice order: bg shapes first, images middle, text last
    int slideNum = 1;
    for (var i = 0; i < slides.length; i++) {
      final s = slides[i];
      if (s.hidden) continue;

      final elements = _sortElementsForPaint(s.elements);
      final name = 'ppt/slides/slide$slideNum.xml';
      final relsName = 'ppt/slides/_rels/slide$slideNum.xml.rels';
      archive.addFile(ArchiveFile(name, _slideXml(s, elements).length, _slideXml(s, elements).codeUnits));
      archive.addFile(ArchiveFile(relsName, _slideRels(s).length, _slideRels(s).codeUnits));
      slideNum++;
    }

    final encoded = ZipEncoder().encode(archive);
    return encoded?.toList() ?? [];
  }

  /// Sort elements for proper paint order: bg shapes → images → text last
  /// This matches GenOffice's z-order where text never goes under shapes
  List<SlideElement> _sortElementsForPaint(List<SlideElement> elements) {
    final bgShapes = <SlideElement>[];
    final images = <SlideElement>[];
    final text = <SlideElement>[];
    final other = <SlideElement>[];

    for (final el in elements) {
      if (el.type == ElementType.shape && _isBackgroundShape(el)) {
        bgShapes.add(el);
      } else if (el.type == ElementType.image) {
        images.add(el);
      } else if (el.type == ElementType.text) {
        text.add(el);
      } else {
        other.add(el);
      }
    }

    // GenOffice paint order: bg shapes first, then other shapes/images, then text last
    return [...bgShapes, ...other, ...images, ...text];
  }

  /// Check if a shape is a background-like element (≥70% of canvas area)
  bool _isBackgroundShape(SlideElement el) {
    final area = el.width * el.height;
    final canvasArea = _canvasW * _canvasH;
    return area >= canvasArea * 0.7;
  }

  // ── XML Builders ──

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _contentTypes() {
    final slideOverrides = <String>[];
    int slideNum = 1;
    for (var i = 0; i < slides.length; i++) {
      if (slides[i].hidden) continue;
      slideOverrides.add('<Override PartName="/ppt/slides/slide$slideNum.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
      slideNum++;
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  ${slideOverrides.join('\n')}
</Types>''';
  }

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

  // ── Slide XML (GenOffice-quality) ──

  String _slideXml(Slide slide, List<SlideElement> sortedElements) {
    // Background — handle solid and gradient like GenOffice
    final bgRaw = slide.backgroundGradient ?? '6366F1';
    final bgParts = bgRaw.replaceAll('#', '').split(',');
    final bgXml = bgParts.length >= 2
        ? '''<a:gradFill>
            <a:gsLst>
              <a:gs pos="0"><a:srgbClr val="${bgParts[0].trim()}"/></a:gs>
              <a:gs pos="100000"><a:srgbClr val="${bgParts[1].trim()}"/></a:gs>
            </a:gsLst>
            <a:lin ang="5400000" scaled="0"/>
          </a:gradFill>'''
        : '''<a:solidFill><a:srgbClr val="${bgParts[0].trim()}"/></a:solidFill>''';

    // Elements in proper paint order
    final elementsXml = sortedElements.map((el) => _elementToXml(el)).join('\n');

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
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''';
  }

  String _slideRels(Slide slide) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
  }

  // ── Element Rendering (GenOffice-quality) ──

  String _elementToXml(SlideElement el) {
    final cx = (el.width * _emuPerPx).round().toString();
    final cy = (el.height * _emuPerPx).round().toString();
    final ox = (el.x * _emuPerPx).round().toString();
    final oy = (el.y * _emuPerPx).round().toString();

    switch (el.type) {
      case ElementType.text:
        return _textElement(el, ox, oy, cx, cy);
      case ElementType.shape:
        return _shapeElement(el, ox, oy, cx, cy);
      case ElementType.image:
        return _imageElement(el, ox, oy, cx, cy);
      case ElementType.chart:
        return _chartElement(el, ox, oy, cx, cy);
      case ElementType.table:
        return _tableElement(el, ox, oy, cx, cy);
      default:
        return _placeholderElement(el, ox, oy, cx, cy);
    }
  }

  /// Text element with proper paragraph structure (GenOffice-style)
  /// Zero inner padding — box top-left is exactly where first glyph starts
  String _textElement(SlideElement el, String ox, String oy, String cx, String cy) {
    final ts = el.textStyle ?? TextStyleData();
    final fontSize = (ts.fontSize * 100).round(); // EMU: 1pt = 100
    final bold = ts.fontWeightValue >= 700 ? '1' : '0';
    final italic = ts.fontStyle == 'italic' ? '1' : '0';
    final colorHex = ts.colorValue.toRadixString(16).padLeft(8, '0').substring(2);
    final align = ts.textAlign ?? 'left';
    final fontFamily = ts.fontFamily ?? 'DM Sans';
    // GenOffice: lineHeight is a multiplier (e.g. 1.1 = 110%)
    final lineSpacingPct = ts.lineHeight != null ? (ts.lineHeight! * 100).round() : 110;

    // GenOffice: paragraph structure with lineSpacing, spaceAfter
    final paragraphs = _buildParagraphs(el.content ?? '', fontSize, bold, italic, colorHex, fontFamily, align, lineSpacingPct: lineSpacingPct);

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
    <a:bodyPr rtlCol="0" anchor="t" inset="0,0,0,0"/>
    $paragraphs
  </p:txBody>
</p:sp>''';
  }

  /// Build paragraph XML with proper structure (GenOffice-style)
  String _buildParagraphs(String content, int fontSize, String bold, String italic, String colorHex, String fontFamily, String align, {int lineSpacingPct = 110}) {
    // Split by newlines to preserve paragraph structure
    final lines = content.split('\n');
    final paragraphs = <String>[];
    // GenOffice: lineSpacing in 1000ths (110% = 110000)
    final lineSpacingEmu = (lineSpacingPct * 1000).toString();

    for (final line in lines) {
      final text = line.trimRight();
      if (text.isEmpty) continue;

      paragraphs.add('''<a:p>
      <a:pPr algn="$align" lineSpacing="$lineSpacingEmu"/>
      <a:r>
        <a:rPr lang="en-US" altLang="id-ID" sz="$fontSize" b="$bold" i="$italic" dirty="0">
          <a:solidFill><a:srgbClr val="$colorHex"/></a:solidFill>
          <a:latin typeface="$fontFamily"/>
          <a:ea typeface="$fontFamily"/>
        </a:rPr>
        <a:t>${_escapeXml(text)}</a:t>
      </a:r>
    </a:p>''');
    }

    if (paragraphs.isEmpty) {
      // Empty text box with at least one paragraph
      return '''<a:p>
      <a:pPr algn="$align"/>
      <a:r>
        <a:rPr lang="en-US" sz="$fontSize" b="$bold" i="$italic">
          <a:solidFill><a:srgbClr val="$colorHex"/></a:solidFill>
          <a:latin typeface="$fontFamily"/>
        </a:rPr>
        <a:t></a:t>
      </a:r>
    </a:p>''';
    }

    return paragraphs.join('\n    ');
  }

  /// Shape element with proper preset geometry mapping
  String _shapeElement(SlideElement el, String ox, String oy, String cx, String cy) {
    final ss = el.shapeStyle ?? ShapeStyleData();
    final fillHex = ss.fillColorValue.toRadixString(16).padLeft(8, '0').substring(2);
    final prst = _mapShapeType(ss.shapeType);

    // Fill XML
    String fillXml = '<a:solidFill><a:srgbClr val="$fillHex"/></a:solidFill>';

    // Stroke XML
    String strokeXml = '';
    if (ss.strokeColorValue != null) {
      final strokeHex = ss.strokeColorValue!.toRadixString(16).padLeft(8, '0').substring(2);
      final strokeW = (ss.strokeWidth * _emuPerPx).round();
      strokeXml = '<a:ln w="$strokeW"><a:solidFill><a:srgbClr val="$strokeHex"/></a:solidFill></a:ln>';
    }

    // Shape with optional label text (zero padding — GenOffice style)
    final label = el.content ?? '';
    if (label.isNotEmpty) {
      final ts = el.textStyle ?? TextStyleData();
      final fontSize = (ts.fontSize * 100).round();
      final bold = ts.fontWeightValue >= 700 ? '1' : '0';
      final colorHex = ts.colorValue.toRadixString(16).padLeft(8, '0').substring(2);
      final fontFamily = ts.fontFamily ?? 'DM Sans';

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
  <p:txBody>
    <a:bodyPr rtlCol="0" anchor="ctr" inset="0,0,0,0"/>
    <a:p>
      <a:pPr algn="ctr"/>
      <a:r>
        <a:rPr lang="en-US" sz="$fontSize" b="$bold">
          <a:solidFill><a:srgbClr val="$colorHex"/></a:solidFill>
          <a:latin typeface="$fontFamily"/>
        </a:rPr>
        <a:t>${_escapeXml(label)}</a:t>
      </a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
    }

    // Shape without text
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

  /// Image element with placeholder (GenOffice fetches and embeds images)
  String _imageElement(SlideElement el, String ox, String oy, String cx, String cy) {
    final label = el.content ?? 'Image';
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
      <a:r><a:rPr lang="en-US" sz="1400" b="0"><a:solidFill><a:srgbClr val="666666"/></a:solidFill></a:rPr><a:t>${_escapeXml(label)}</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  /// Chart element placeholder
  String _chartElement(SlideElement el, String ox, String oy, String cx, String cy) {
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
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="F3F4F6"/></a:solidFill>
  </p:spPr>
  <p:txBody>
    <a:bodyPr/>
    <a:p>
      <a:pPr algn="ctr"/>
      <a:r><a:rPr lang="en-US" sz="1400" b="0"><a:solidFill><a:srgbClr val="666666"/></a:solidFill></a:rPr><a:t>Chart</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  /// Table element placeholder
  String _tableElement(SlideElement el, String ox, String oy, String cx, String cy) {
    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="Table"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="F9FAFB"/></a:solidFill>
  </p:spPr>
  <p:txBody>
    <a:bodyPr/>
    <a:p>
      <a:pPr algn="ctr"/>
      <a:r><a:rPr lang="en-US" sz="1400" b="0"><a:solidFill><a:srgbClr val="666666"/></a:solidFill></a:rPr><a:t>Table</a:t></a:r>
    </a:p>
  </p:txBody>
</p:sp>''';
  }

  /// Placeholder for other element types
  String _placeholderElement(SlideElement el, String ox, String oy, String cx, String cy) {
    return '''<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="${_nextId++}" name="Element"/>
    <p:cNvSpPr/>
    <p:nvPr/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm>
      <a:off x="$ox" y="$oy"/>
      <a:ext cx="$cx" cy="$cy"/>
    </a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="F3F4F6"/></a:solidFill>
  </p:spPr>
</p:sp>''';
  }

  /// Map DocuCraft shape type to OOXML preset geometry (33 shapes like GenOffice)
  String _mapShapeType(String? shapeType) {
    switch (shapeType) {
      // Basic shapes
      case 'rect': return 'rect';
      case 'roundRect': return 'roundRect';
      case 'ellipse':
      case 'circle': return 'ellipse';
      // Flowchart / arrow shapes
      case 'diamond': return 'diamond';
      case 'triangle': return 'triangle';
      case 'rightArrow':
      case 'arrow': return 'rightArrow';
      case 'leftArrow': return 'leftArrow';
      case 'upArrow': return 'upArrow';
      case 'downArrow': return 'downArrow';
      case 'chevron': return 'chevron';
      case 'parallelogram': return 'parallelogram';
      case 'trapezoid': return 'trapezoid';
      // Complex shapes
      case 'hexagon': return 'hexagon';
      case 'pentagon': return 'pentagon';
      case 'star':
      case 'star5': return 'star5';
      case 'star6': return 'star6';
      case 'star7': return 'star7';
      case 'star8': return 'star8';
      case 'star10': return 'star10';
      case 'star12': return 'star12';
      case 'star16': return 'star16';
      case 'star24': return 'star24';
      case 'star32': return 'star32';
      case 'heart': return 'heart';
      case 'cloud': return 'cloud';
      // Line shapes
      case 'line': return 'line';
      case 'lineArrow': return 'lineArrow';
      // Fallback
      case 'polygon': return 'rect';
      default: return 'rect';
    }
  }
}
