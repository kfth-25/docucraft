// DocuCraft — Document Model
// Dokumen rich text dengan konten berbasis block (gaya Notion/Quill)
// Lokal saja (Flutter + CRDT), tidak terhubung ke workspace GenOffice.

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Block type enumeration for document content blocks.
enum BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  checklist,
  quote,
  code,
  divider,
  image,
  table,
}

/// A single styled text run within a block (for inline formatting).
class TextRun {
  String text;
  bool bold;
  bool italic;
  bool underline;
  bool strikethrough;
  String? color; // hex '#RRGGBB' or null for default
  String? fontFamily;
  double? fontSize;

  TextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.color,
    this.fontFamily,
    this.fontSize,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (underline) 'underline': true,
    if (strikethrough) 'strikethrough': true,
    if (color != null) 'color': color,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (fontSize != null) 'fontSize': fontSize,
  };

  factory TextRun.fromJson(Map<String, dynamic> json) => TextRun(
    text: json['text']?.toString() ?? '',
    bold: json['bold'] == true,
    italic: json['italic'] == true,
    underline: json['underline'] == true,
    strikethrough: json['strikethrough'] == true,
    color: json['color']?.toString(),
    fontFamily: json['fontFamily']?.toString(),
    fontSize: (json['fontSize'] as num?)?.toDouble(),
  );

  TextRun copyWith({String? text, bool? bold, bool? italic, bool? underline,
      bool? strikethrough, String? color, String? fontFamily, double? fontSize}) {
    return TextRun(
      text: text ?? this.text,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

/// Per-cell style for a table block, mirroring GenOffice's `TableCell` shape
/// (align/fill/color/bold). `fill`/`color` are hex without '#' (w:shd/w:color).
class TableBlockCell {
  final String? align; // 'left' | 'center' | 'right' | 'justify' | 'distribute'
  final String? fill; // hex without '#'
  final String? color; // hex without '#'
  final bool bold;

  TableBlockCell({this.align, this.fill, this.color, this.bold = false});

  Map<String, dynamic> toJson() => {
    if (align != null) 'align': align,
    if (fill != null) 'fill': fill,
    if (color != null) 'color': color,
    if (bold) 'bold': true,
  };

  factory TableBlockCell.fromJson(Map<String, dynamic> json) => TableBlockCell(
    align: json['align']?.toString(),
    fill: json['fill']?.toString(),
    color: json['color']?.toString(),
    bold: json['bold'] == true,
  );
}

/// A content block in the document.
/// Each block has a type, a list of inline text runs, and optional metadata.
class DocumentBlock {
  final String id;
  BlockType type;
  List<TextRun> runs;

  // List-specific fields
  bool? checked; // for checklist items

  // Image-specific fields
  String? imageUrl;
  double? imageWidth;
  double? imageHeight;
  String? imageCaption;

  // Table-specific fields
  List<List<String>>? tableData; // 2D array of cell text
  bool tableHasHeader; // first row is a header (bold + shaded)
  List<double>? tableColWidthsPct; // column widths as percentages (sum ~100)
  List<List<TableBlockCell>>? tableCells; // per-cell style, parallel to tableData

  // Alignment (paragraphs, headings)
  String align; // 'left', 'center', 'right', 'justify'

  DocumentBlock({
    String? id,
    required this.type,
    List<TextRun>? runs,
    this.checked,
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    this.imageCaption,
    this.tableData,
    this.tableHasHeader = false,
    this.tableColWidthsPct,
    this.tableCells,
    this.align = 'left',
  }) : id = id ?? _uuid.v4(),
       runs = runs ?? [];

  /// Convenience: plain text content of this block.
  String get text => runs.map((r) => r.text).join();

  /// Convenience: create a paragraph block with plain text.
  factory DocumentBlock.paragraph(String text) => DocumentBlock(
    type: BlockType.paragraph,
    runs: [TextRun(text: text)],
  );

  /// Convenience: create a heading block.
  factory DocumentBlock.heading(String text, {int level = 1}) => DocumentBlock(
    type: level == 1 ? BlockType.heading1 : level == 2 ? BlockType.heading2 : BlockType.heading3,
    runs: [TextRun(text: text, bold: true)],
  );

  /// Convenience: create a divider block.
  factory DocumentBlock.divider() => DocumentBlock(
    type: BlockType.divider,
    runs: [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'runs': runs.map((r) => r.toJson()).toList(),
    if (checked != null) 'checked': checked,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (imageWidth != null) 'imageWidth': imageWidth,
    if (imageHeight != null) 'imageHeight': imageHeight,
    if (imageCaption != null) 'imageCaption': imageCaption,
    if (tableData != null) 'tableData': tableData,
    if (tableHasHeader) 'tableHasHeader': true,
    if (tableColWidthsPct != null) 'tableColWidthsPct': tableColWidthsPct,
    if (tableCells != null) 'tableCells': tableCells!.map((r) => r.map((c) => c.toJson()).toList()).toList(),
    'align': align,
  };

  factory DocumentBlock.fromJson(Map<String, dynamic> json) => DocumentBlock(
    id: json['id']?.toString(),
    type: BlockType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => BlockType.paragraph,
    ),
    runs: (json['runs'] as List?)
        ?.map((r) => TextRun.fromJson(r as Map<String, dynamic>))
        .toList(),
    checked: json['checked'] as bool?,
    imageUrl: json['imageUrl']?.toString(),
    imageWidth: (json['imageWidth'] as num?)?.toDouble(),
    imageHeight: (json['imageHeight'] as num?)?.toDouble(),
    imageCaption: json['imageCaption']?.toString(),
    tableData: (json['tableData'] as List?)
        ?.map((row) => (row as List).map((c) => c.toString()).toList())
        .toList(),
    tableHasHeader: json['tableHasHeader'] == true,
    tableColWidthsPct: (json['tableColWidthsPct'] as List?)
        ?.map((w) => (w as num).toDouble())
        .toList(),
    tableCells: (json['tableCells'] as List?)
        ?.map((row) => (row as List)
            .map((c) => TableBlockCell.fromJson(c as Map<String, dynamic>))
            .toList())
        .toList(),
    align: json['align']?.toString() ?? 'left',
  );
}

/// A folder for organizing documents (virtual, Hive-based).
class DocumentFolder {
  final String id;
  String name;
  String color; // hex color for folder icon
  DateTime createdAt;

  DocumentFolder({
    String? id,
    required this.name,
    this.color = '#2563EB',
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DocumentFolder.fromJson(Map<String, dynamic> json) => DocumentFolder(
    id: json['id']?.toString(),
    name: json['name']?.toString() ?? 'Untitled',
    color: json['color']?.toString() ?? '#2563EB',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

/// Full document model with blocks, metadata, and folder association.
class Document {
  final String id;
  String title;
  String? folderId;
  List<DocumentBlock> blocks;
  DateTime createdAt;
  DateTime updatedAt;
  String? coverColor; // hex color for document cover/header accent

  Document({
    String? id,
    required this.title,
    this.folderId,
    List<DocumentBlock>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.coverColor,
  }) : id = id ?? _uuid.v4(),
       blocks = blocks ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Convert to JSON for Hive storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (folderId != null) 'folderId': folderId,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (coverColor != null) 'coverColor': coverColor,
  };

  /// Parse from JSON.
  factory Document.fromJson(Map<String, dynamic> json) => Document(
    id: json['id']?.toString(),
    title: json['title']?.toString() ?? 'Untitled Document',
    folderId: json['folderId']?.toString(),
    blocks: (json['blocks'] as List?)
        ?.map((b) => DocumentBlock.fromJson(b as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    coverColor: json['coverColor']?.toString(),
  );

  /// Create a blank document with a title paragraph.
  factory Document.empty({String? title}) => Document(
    title: title ?? 'Untitled Document',
    blocks: [DocumentBlock.paragraph('')],
  );
}
