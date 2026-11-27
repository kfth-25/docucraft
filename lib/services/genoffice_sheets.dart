// DocuCraft — GenOffice Sheets Service
// HTTP client untuk API spreadsheet GenOffice (sheet/open, sheet/prompt, sheet/export)
// Mengikuti pola yang sama dengan AiGenerationService — HTTP + fallback + timeout + logging.
//
// GenOffice harus berjalan di localhost:3001 agar service ini bisa bekerja.
// Jalankan app GenOffice terlebih dahulu, lalu gunakan service ini dari Flutter.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/endpoints.dart';

// ── Configuration ──

class _SheetsConfig {
  // URL backend GenOffice terpusat di Endpoints (lib/config/endpoints.dart).
  static String get baseUrl => Endpoints.apiV1;

  static Duration get openTimeout => const Duration(seconds: 10);
  static Duration get promptTimeout => const Duration(minutes: 2); // AI processing can take time
  static Duration get exportTimeout => const Duration(seconds: 30);
}

// ── Live AI streaming (WebSocket) ──

/// One accumulated chunk of AI text for a specific sheet workspace, streamed
/// from GenOffice's `/ws` while a sheet AI run is still in flight.
class SheetAiDelta {
  final String workspaceId;
  final String text;
  const SheetAiDelta({required this.workspaceId, required this.text});
}

/// Subscribes to GenOffice's WebSocket (`/ws`) and surfaces `sheet-ai` stream
/// events so the Flutter chat can render AI text as it is generated, instead
/// of waiting for the single final reply.
class GenOfficeSheetStream {
  WebSocketChannel? _channel;
  final StreamController<SheetAiDelta> _controller = StreamController.broadcast();

  /// Emits `{ workspaceId, text }` for every `sheet-ai` broadcast, live.
  Stream<SheetAiDelta> get deltas => _controller.stream;

  void connect() {
    if (_channel != null) return;
    try {
      final host = kIsWeb ? 'localhost' : '127.0.0.1';
      _channel = WebSocketChannel.connect(Uri.parse('ws://$host:3001/ws'));
      _channel!.stream.listen(
        (data) {
          try {
            final map = jsonDecode(data.toString()) as Map<String, dynamic>;
            if (map['stream'] != 'sheet-ai') return;
            final workspaceId = map['workspaceId'] as String?;
            final text = map['text'] as String?;
            if (workspaceId == null || workspaceId.isEmpty) return;
            if (text == null || text.isEmpty) return;
            _controller.add(SheetAiDelta(workspaceId: workspaceId, text: text));
          } catch (_) {
            // Ignore malformed / non-JSON frames.
          }
        },
        onError: (Object _) { _channel = null; },
        onDone: () { _channel = null; },
        cancelOnError: true,
      );
    } catch (_) {
      _channel = null;
    }
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _controller.close();
  }
}

// ── Result Types ──

class SheetOpenResult {
  final bool ok;
  final String? workspaceId;
  final String? tabId;
  final int? webContentsId;
  final String? error;

  const SheetOpenResult({required this.ok, this.workspaceId, this.tabId, this.webContentsId, this.error});

  factory SheetOpenResult.fromJson(Map<String, dynamic> json) {
    return SheetOpenResult(
      ok: json['ok'] == true,
      workspaceId: json['workspaceId'] as String?,
      tabId: json['tabId'] as String?,
      webContentsId: json['webContentsId'] as int?,
      error: json['error'] as String?,
    );
  }
}

class SheetPromptResult {
  final bool ok;
  final String? error;
  final String? reply; // AI response text (if any)

  const SheetPromptResult({required this.ok, this.error, this.reply});

  factory SheetPromptResult.fromJson(Map<String, dynamic> json) {
    return SheetPromptResult(
      ok: json['ok'] == true,
      error: json['error'] as String?,
      reply: json['reply'] as String?,
    );
  }
}

class SheetWriteResult {
  final bool ok;
  final int? count; // number of cells written
  final String? error;
  final List<SheetWriteCellResult> results; // computed values of formula cells

  const SheetWriteResult({required this.ok, this.count, this.error, this.results = const []});

  factory SheetWriteResult.fromJson(Map<String, dynamic> json) {
    return SheetWriteResult(
      ok: json['ok'] == true,
      count: json['count'] as int?,
      error: json['error'] as String?,
      results: (json['results'] as List<dynamic>?)
              ?.map((r) => SheetWriteCellResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Computed value of a single formula cell returned by `/sheet/write`.
class SheetWriteCellResult {
  final int row;
  final int column;
  final dynamic value;

  const SheetWriteCellResult({required this.row, required this.column, this.value});

  factory SheetWriteCellResult.fromJson(Map<String, dynamic> json) {
    return SheetWriteCellResult(
      row: json['row'] as int,
      column: json['column'] as int,
      value: json['value'],
    );
  }
}

class SheetExportResult {
  final bool ok;
  final String? base64; // XLSX file as base64
  final String? filePath; // Original file path on disk
  final String? error;

  const SheetExportResult({required this.ok, this.base64, this.filePath, this.error});

  factory SheetExportResult.fromJson(Map<String, dynamic> json) {
    return SheetExportResult(
      ok: json['ok'] == true,
      base64: json['base64'] as String?,
      filePath: json['filePath'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Decode base64 to bytes (for saving to file)
  List<int>? get fileBytes => base64 != null ? base64Decode(base64!) : null;
}

class SheetCell {
  final int row;
  final int column;
  final dynamic value;
  final String? formula;

  const SheetCell({required this.row, required this.column, this.value, this.formula});

  factory SheetCell.fromJson(Map<String, dynamic> json) {
    return SheetCell(
      row: json['row'] as int,
      column: json['column'] as int,
      value: json['value'],
      formula: json['formula'] as String?,
    );
  }

  /// Display value: the computed cell value. Formula cells show their result,
  /// not the raw formula string (that lives in [formula] for the formula bar).
  String get display {
    if (value == null) return '';
    return value.toString();
  }
}

/// One series of a chart read from the workbook (name + categories + values).
class SheetChartSeries {
  final String name;
  final List<String> categories;
  final List<double> values;
  final String? color;

  const SheetChartSeries({required this.name, this.categories = const [], this.values = const [], this.color});

  factory SheetChartSeries.fromJson(Map<String, dynamic> json) {
    return SheetChartSeries(
      name: json['name'] as String? ?? '',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          const [],
      values: (json['values'] as List<dynamic>?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          const [],
      color: json['color'] as String?,
    );
  }
}

/// Cell anchor of a floating chart, mirroring Excel's two-cell anchor: a box
/// from (fromRow, fromColumn) to (toRow, toColumn) plus EMU offsets from each
/// corner cell's top-left (1px = 9525 EMU at 96dpi).
class SheetChartAnchor {
  final int fromRow;
  final int fromColumn;
  final double fromRowOffset;
  final double fromColumnOffset;
  final int toRow;
  final int toColumn;
  final double toRowOffset;
  final double toColumnOffset;

  const SheetChartAnchor({
    required this.fromRow,
    required this.fromColumn,
    this.fromRowOffset = 0,
    this.fromColumnOffset = 0,
    required this.toRow,
    required this.toColumn,
    this.toRowOffset = 0,
    this.toColumnOffset = 0,
  });

  factory SheetChartAnchor.fromJson(Map<String, dynamic> json) {
    return SheetChartAnchor(
      fromRow: (json['fromRow'] as num?)?.toInt() ?? 0,
      fromColumn: (json['fromColumn'] as num?)?.toInt() ?? 0,
      fromRowOffset: (json['fromRowOffset'] as num?)?.toDouble() ?? 0,
      fromColumnOffset: (json['fromColumnOffset'] as num?)?.toDouble() ?? 0,
      toRow: (json['toRow'] as num?)?.toInt() ?? 0,
      toColumn: (json['toColumn'] as num?)?.toInt() ?? 0,
      toRowOffset: (json['toRowOffset'] as num?)?.toDouble() ?? 0,
      toColumnOffset: (json['toColumnOffset'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A chart anchored on a sheet (bar/line/pie/doughnut/area/scatter/radar).
class SheetChart {
  final String title;
  final String chartType;
  final String? barDirection;
  final List<SheetChartSeries> series;
  final SheetChartAnchor anchor;

  const SheetChart({
    required this.title,
    this.chartType = 'barChart',
    this.barDirection,
    this.series = const [],
    this.anchor = const SheetChartAnchor(fromRow: 0, fromColumn: 0, toRow: 8, toColumn: 6),
  });

  factory SheetChart.fromJson(Map<String, dynamic> json) {
    return SheetChart(
      title: json['title'] as String? ?? '',
      chartType: json['chartType'] as String? ?? 'barChart',
      barDirection: json['barDirection'] as String?,
      series: (json['series'] as List<dynamic>?)
              ?.map((s) => SheetChartSeries.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      anchor: json['anchor'] is Map<String, dynamic>
          ? SheetChartAnchor.fromJson(json['anchor'] as Map<String, dynamic>)
          : const SheetChartAnchor(fromRow: 0, fromColumn: 0, toRow: 8, toColumn: 6),
    );
  }
}

/// A merged-cell range (0-based inclusive, matching cell coordinates).
class SheetMerge {
  final int startRow;
  final int startColumn;
  final int endRow;
  final int endColumn;

  const SheetMerge({required this.startRow, required this.startColumn, required this.endRow, required this.endColumn});

  factory SheetMerge.fromJson(Map<String, dynamic> json) {
    return SheetMerge(
      startRow: json['startRow'] as int,
      startColumn: json['startColumn'] as int,
      endRow: json['endRow'] as int,
      endColumn: json['endColumn'] as int,
    );
  }
}

/// Resolved style for a single cell (subset GenOffice sends for display).
class SheetCellStyle {
  final bool bold;
  final bool italic;
  final bool wrap;
  final String? color;
  final String? fill;
  final String? align;
  final String? numberFormat;

  const SheetCellStyle({this.bold = false, this.italic = false, this.wrap = false, this.color, this.fill, this.align, this.numberFormat});

  factory SheetCellStyle.fromJson(Map<String, dynamic> json) {
    return SheetCellStyle(
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      wrap: json['wrap'] == true,
      color: json['color'] as String?,
      fill: json['fill'] as String?,
      align: json['align'] as String?,
      numberFormat: json['numberFormat'] as String?,
    );
  }
}

class SheetDataResult {
  final bool ok;
  final List<SheetCell> cells;
  final List<String> sheetNames;
  final String? activeSheetId;
  final int rowCount;
  final int columnCount;
  final List<SheetChart> charts;
  final List<double> columnWidths;
  final double defaultRowHeight;
  final Map<int, double> rowHeights;
  final List<SheetMerge> merges;
  final Map<String, SheetCellStyle> cellStyles;
  final bool showGridLines;
  final String? error;

  const SheetDataResult({
    required this.ok,
    this.cells = const [],
    this.sheetNames = const [],
    this.activeSheetId,
    this.rowCount = 0,
    this.columnCount = 0,
    this.charts = const [],
    this.columnWidths = const [],
    this.defaultRowHeight = 24,
    this.rowHeights = const {},
    this.merges = const [],
    this.cellStyles = const {},
    this.showGridLines = true,
    this.error,
  });

  factory SheetDataResult.fromJson(Map<String, dynamic> json) {
    return SheetDataResult(
      ok: json['ok'] == true,
      cells: (json['cells'] as List<dynamic>?)
              ?.map((c) => SheetCell.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      sheetNames: (json['sheetNames'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      activeSheetId: json['activeSheetId'] as String?,
      rowCount: json['rowCount'] as int? ?? 0,
      columnCount: json['columnCount'] as int? ?? 0,
      charts: (json['charts'] as List<dynamic>?)
              ?.map((c) => SheetChart.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      columnWidths: (json['columnWidths'] as List<dynamic>?)
              ?.map((w) => (w as num).toDouble())
              .toList() ??
          const [],
      defaultRowHeight: (json['defaultRowHeight'] as num?)?.toDouble() ?? 24,
      rowHeights: (json['rowHeights'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble())) ??
          const {},
      merges: (json['merges'] as List<dynamic>?)
              ?.map((m) => SheetMerge.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
      cellStyles: (json['cellStyles'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, SheetCellStyle.fromJson(v as Map<String, dynamic>))) ??
          const {},
      showGridLines: json['showGridLines'] != false,
      error: json['error'] as String?,
    );
  }

  /// Build a 2D grid from the flat cell list. Returns a list of rows,
  /// where grid[row][column] = display value.
  List<List<String>> toGrid({int maxRows = 200, int maxCols = 26}) {
    final grid = List.generate(
      maxRows,
      (_) => List.filled(maxCols, ''),
    );
    for (final cell in cells) {
      if (cell.row < maxRows && cell.column < maxCols) {
        grid[cell.row][cell.column] = cell.display;
      }
    }
    return grid;
  }
}

// ── Main Service ──

class GenOfficeSheetsService {
  /// Check if GenOffice HTTP server is reachable.
  static Future<bool> isAvailable() async {
    try {
      final uri = Uri.parse('${_SheetsConfig.baseUrl}/health');
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Open a workbook in GenOffice. Returns workspaceId for subsequent calls.
  /// If [filePath] is provided, opens that existing file.
  /// If [title] is provided with no filePath, creates a new blank workbook.
  static Future<SheetOpenResult> openSheet({String? title, String? filePath}) async {
    try {
      debugPrint('📊 [Sheets] Opening sheet: title=$title, filePath=$filePath');
      final uri = Uri.parse('${_SheetsConfig.baseUrl}/sheet/open');
      final body = <String, dynamic>{};
      if (title != null && title.isNotEmpty) body['title'] = title;
      if (filePath != null && filePath.isNotEmpty) body['filePath'] = filePath;

      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_SheetsConfig.openTimeout);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = SheetOpenResult.fromJson(data);

      if (result.ok) {
        debugPrint('✅ [Sheets] Opened workspace ${result.workspaceId} (tab: ${result.tabId})');
      } else {
        debugPrint('❌ [Sheets] Open failed: ${result.error}');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [Sheets] Open error: $e');
      return SheetOpenResult(ok: false, error: e.toString());
    }
  }

  /// Send an AI prompt to a workspace. The prompt is processed by GenOffice's
  /// AI agent (AgentLoop + tools). Returns the AI response.
  static Future<SheetPromptResult> prompt(String workspaceId, String instruction) async {
    if (workspaceId.isEmpty) return const SheetPromptResult(ok: false, error: 'Missing workspaceId');
    if (instruction.trim().isEmpty) return const SheetPromptResult(ok: false, error: 'Empty instruction');

    try {
      debugPrint('💬 [Sheets] Sending prompt to workspace $workspaceId: "${instruction.substring(0, instruction.length > 50 ? 50 : instruction.length)}..."');
      final uri = Uri.parse('${_SheetsConfig.baseUrl}/sheet/prompt-and-reply');
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'workspaceId': workspaceId,
          'prompt': instruction,
        }),
      ).timeout(_SheetsConfig.promptTimeout);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = SheetPromptResult.fromJson(data);

      if (result.ok) {
        debugPrint('✅ [Sheets] Prompt accepted');
      } else {
        debugPrint('❌ [Sheets] Prompt failed: ${result.error}');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [Sheets] Prompt error: $e');
      return SheetPromptResult(ok: false, error: e.toString());
    }
  }

  /// Export the current state of a workbook as XLSX (base64-encoded).
  /// The file is read from disk by GenOffice main process.
  static Future<SheetExportResult> export(String workspaceId) async {
    if (workspaceId.isEmpty) return const SheetExportResult(ok: false, error: 'Missing workspaceId');

    try {
      debugPrint('📥 [Sheets] Exporting workspace $workspaceId');
      final uri = Uri.parse('${_SheetsConfig.baseUrl}/sheet/export');
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'workspaceId': workspaceId}),
      ).timeout(_SheetsConfig.exportTimeout);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = SheetExportResult.fromJson(data);

      if (result.ok) {
        final sizeKb = result.base64 != null ? (result.base64!.length * 3 / 4 / 1024).round() : 0;
        debugPrint('✅ [Sheets] Exported ${result.filePath ?? "unknown"} ($sizeKb KB)');
      } else {
        debugPrint('❌ [Sheets] Export failed: ${result.error}');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [Sheets] Export error: $e');
      return SheetExportResult(ok: false, error: e.toString());
    }
  }

  /// Read cell data from the active workbook via GenOffice sidecar.
  /// Returns a grid of cells with their values.
  static Future<SheetDataResult> getData(String workspaceId, {String? sheetName}) async {
    if (workspaceId.isEmpty) return const SheetDataResult(ok: false, error: 'Missing workspaceId');

    try {
      debugPrint('📊 [Sheets] Reading cell data from workspace $workspaceId (sheet: ${sheetName ?? "default"})');
      final uri = Uri.parse('${_SheetsConfig.baseUrl}/sheet/data');
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'workspaceId': workspaceId,
          if (sheetName != null && sheetName.isNotEmpty) 'sheetName': sheetName,
        }),
      ).timeout(_SheetsConfig.openTimeout);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = SheetDataResult.fromJson(data);

      if (result.ok) {
        debugPrint('✅ [Sheets] Got ${result.cells.length} cells, ${result.sheetNames.length} sheets');
      } else {
        debugPrint('❌ [Sheets] Data read failed: ${result.error}');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [Sheets] Data read error: $e');
      return SheetDataResult(ok: false, error: e.toString());
    }
  }

  /// Write cell edits back to the workbook on disk via GenOffice's sidecar.
  /// [cells] is a list of `{row, column, value}` (0-based row/column, matching
  /// the coordinates returned by [getData]).
  static Future<SheetWriteResult> writeCells(
    String workspaceId,
    String sheetName,
    List<Map<String, dynamic>> cells,
  ) async {
    if (workspaceId.isEmpty) {
      return const SheetWriteResult(ok: false, error: 'Missing workspaceId');
    }
    if (sheetName.trim().isEmpty) {
      return const SheetWriteResult(ok: false, error: 'Missing sheetName');
    }
    if (cells.isEmpty) {
      return const SheetWriteResult(ok: false, error: 'No cells to write');
    }

    try {
      debugPrint('✏️ [Sheets] Writing ${cells.length} cells to "$sheetName" (workspace $workspaceId)');
      final uri = Uri.parse('${_SheetsConfig.baseUrl}/sheet/write');
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'workspaceId': workspaceId,
          'sheetName': sheetName,
          'cells': cells,
        }),
      ).timeout(_SheetsConfig.exportTimeout);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = SheetWriteResult.fromJson(data);

      if (result.ok) {
        debugPrint('✅ [Sheets] Wrote ${result.count} cells');
      } else {
        debugPrint('❌ [Sheets] Write failed: ${result.error}');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [Sheets] Write error: $e');
      return SheetWriteResult(ok: false, error: e.toString());
    }
  }

  /// Convenience: open a file and return the workspaceId (or null on failure).
  static Future<String?> openFile(String filePath) async {
    final result = await openSheet(filePath: filePath);
    return result.ok ? result.workspaceId : null;
  }

  /// Convenience: prompt + export in sequence.
  /// Returns export result after AI has processed the prompt.
  static Future<SheetExportResult> promptAndExport(String workspaceId, String instruction) async {
    final promptResult = await prompt(workspaceId, instruction);
    if (!promptResult.ok) {
      return SheetExportResult(ok: false, error: 'Prompt failed: ${promptResult.error}');
    }
    // Small delay to let AI changes settle
    await Future.delayed(const Duration(milliseconds: 500));
    return export(workspaceId);
  }
}
