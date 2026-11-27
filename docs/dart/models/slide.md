# Slide Model

**File:** `lib/models/slide.dart`
**Role:** Data Model
**Step:** Step 5 (Design Spec Authoring)

## Overview
`Slide` adalah model utama yang merepresentasikan satu slide dalam presentasi. Slide berisi elemen visual (teks, gambar, bentuk) dan metadata.

## Class Hierarchy

```
Slide
├── id: String (UUID v7)
├── title: String
├── subtitle: String
├── backgroundGradient: String
├── hidden: bool
├── elements: List<SlideElement>
├── extra: Map<String, dynamic>?
├── version: int (CRDT metadata)
├── lastModifiedBy: String?
├── lastModifiedAt: DateTime?
├── drawStrokes: List<Map<String, dynamic>>
├── templateId: String?
├── layoutId: String?
└── templateData: Map<String, dynamic>?
```

## SlideElement

```
SlideElement
├── id: String (UUID v7)
├── type: ElementType (enum)
├── x, y, width, height: double
├── rotation: double
├── zIndex: int
├── content: String?
├── textStyle: TextStyleData?
├── shapeStyle: ShapeStyleData?
├── imageStyle: ImageStyleData?
├── chartData: ChartData?
├── tableData: TableData?
├── drawData: DrawData?
├── extra: Map<String, dynamic>?
├── version: int
├── lastModifiedBy: String?
├── lastModifiedAt: DateTime?
└── templateSlotId: String?
```

## ElementType Enum

| Value | Description |
|-------|-------------|
| `text` | Text element |
| `image` | Image element |
| `shape` | Shape element (rect, circle, dll) |
| `chart` | Chart element (bar, line, pie) |
| `table` | Table element |
| `icon` | Icon element |
| `video` | Video element |
| `audio` | Audio element |
| `draw` | Drawing/sketch element |

## TextStyleData

```
TextStyleData
├── fontSize: double (default: 14)
├── colorValue: int (default: 0xFFFFFFFF)
├── fontWeight: String (default: 'normal')
├── fontStyle: String (default: 'normal')
├── textAlign: String (default: 'left')
├── fontFamily: String?
├── letterSpacing: double?
├── lineHeight: double?
├── wordSpacing: double?
└── textDecoration: String (default: 'none')
```

## ShapeStyleData

```
ShapeStyleData
├── fillColorValue: int (default: 0xFF6366F1)
├── strokeColorValue: int?
├── strokeWidth: double (default: 1)
├── borderRadius: double (default: 8)
├── opacity: double (default: 1)
└── shapeType: String (default: 'rect')
```

## Shape Types

| Type | Description |
|------|-------------|
| `rect` | Rectangle |
| `circle` | Circle/Ellipse |
| `diamond` | Diamond (rotated square) |
| `triangle` | Triangle (clipped path) |
| `arrow` | Arrow shape |
| `hexagon` | Hexagon shape |

## ChartData

```
ChartData
├── chartType: String (bar, line, pie, donut)
├── dataSets: List<ChartDataSet>
└── labels: List<String>
```

## TableData

```
TableData
├── rows: int (default: 3)
├── cols: int (default: 3)
├── cells: List<List<String>>
└── hasHeader: bool (default: true)
```

## DrawData

```
DrawData
└── strokes: List<DrawStroke>

DrawStroke
├── colorValue: int
├── size: double
├── points: List<List<double>> ([[x, y], ...])
└── label: String?
```

## CRUD Operations

### Create
```dart
final slide = Slide(
  title: 'Judul Slide',
  subtitle: 'Subtitle',
  backgroundGradient: 'indigo',
);
```

### Read
```dart
final element = slide.elements.firstWhere((e) => e.id == elementId);
```

### Update
```dart
slide.title = 'Judul Baru';
slide.bumpVersion(); // version++
```

### Delete
```dart
slide.elements.removeWhere((e) => e.id == elementId);
```

## JSON Serialization

### toJson()
```dart
Map<String, dynamic> json = slide.toJson();
```

### fromJson()
```dart
final slide = Slide.fromJson(json);
```

## Version History

| Version | Changes |
|---------|---------|
| 1 | Initial version |
| 2 | Added CRDT metadata (version, lastModifiedBy, lastModifiedAt) |
| 3 | Added template support (templateId, layoutId, templateData) |

## Related Files
- `slide_provider.dart` - State management
- `slide_repository.dart` - Persistence
- `slide_canvas.dart` - UI rendering
- `slide_editor_screen.dart` - Editor UI
