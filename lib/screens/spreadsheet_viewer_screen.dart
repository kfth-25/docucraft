// DocuCraft — Spreadsheet Viewer Screen
// Mengikuti desain stitch_keko: aksen hijau, formula bar, tab sheet, tabel data.
// Terhubung ke GenOffice HTTP API untuk operasi Excel sungguhan.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/genoffice_sheets.dart';
import '../themes/app_theme.dart';
import '../widgets/sheet_chart.dart';

/// Parse a `#RRGGBB` / `#RRGGBBAA` hex color string (from cell styles/fills).
Color? _hexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}

/// A single chat turn in the AI Copilot (user prompt ↔ GenOffice AI reply).
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool streaming;
  const _ChatMessage({
    required this.text,
    this.isUser = false,
    this.isError = false,
    this.streaming = false,
  });
}

class SpreadsheetViewerScreen extends StatefulWidget {
  final String? title;
  final String? filePath;

  const SpreadsheetViewerScreen({super.key, this.title, this.filePath});

  @override
  State<SpreadsheetViewerScreen> createState() => _SpreadsheetViewerScreenState();
}

class _SpreadsheetViewerScreenState extends State<SpreadsheetViewerScreen> {
  static const Color _greenAccent = Color(0xFF16A34A);
  static const Color _greenDark = Color(0xFF15803D);
  static const Color _greenLight = Color(0xFFF0FDF4);
  static const Color _greenContainer = Color(0xFFDCFCE7);
  static const Color _greenBorder = Color(0xFFBBF7D0);

  final TextEditingController _formulaController = TextEditingController();
  final TextEditingController _aiInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  int _activeSheet = 0;
  bool _aiSheetOpen = false;

  // ── GenOffice state ──
  String? _workspaceId;
  bool _loading = true;
  bool _genOfficeAvailable = false;
  bool _aiProcessing = false;
  final List<_ChatMessage> _chatMessages = [];
  final GenOfficeSheetStream _sheetStream = GenOfficeSheetStream();
  StreamSubscription<SheetAiDelta>? _sheetStreamSub;

  // Cell data (populated from GenOffice or fallback to mock).
  // Real cell values keyed by "row,col" (0-based, matching GenOffice coordinates
  // so edits can round-trip through /sheet/write unchanged).
  Map<String, String> _values = {};
  int _rowCount = 0;
  int _colCount = 0;
  List<String> _sheetNames = ['Sheet1'];
  String _activeSheetName = 'Sheet1';

  // Selected cell — tapping a cell surfaces its value/formula in the formula
  // bar (real-Excel selection model) instead of immediately opening a dialog.
  int? _selectedRow;
  int? _selectedCol;

  // Raw formula strings keyed by "row,col". The grid shows the computed value;
  // the formula bar shows this string for the selected cell.
  Map<String, String> _formulas = {};

  // Chart + table fidelity (mirrors GenOffice: styles, column widths, row
  // heights, merged cells, gridlines).
  List<SheetChart> _charts = [];
  List<double> _columnWidths = [];
  List<double> _colContentWidths = [];
  Map<int, double> _rowHeights = {};
  List<SheetMerge> _merges = [];
  Map<String, SheetCellStyle> _cellStyles = {};
  double _defaultRowHeight = 32;
  bool _showGridLines = true;

  // Precomputed horizontal merge spans: top-left "row,col" -> endColumn, and
  // the set of cells covered by such a merge (skipped when laying out rows).
  Map<String, int> _mergeColSpan = {};
  Set<String> _mergeCovered = {};

  @override
  void initState() {
    super.initState();
    _initSheet();
    _sheetStreamSub = _sheetStream.deltas.listen(_onSheetAiDelta);
    _sheetStream.connect();
  }

  Future<void> _initSheet() async {
    setState(() { _loading = true; });

    _genOfficeAvailable = await GenOfficeSheetsService.isAvailable();

    if (!_genOfficeAvailable) {
      // Fallback to mock data when GenOffice is not running
      _loadMockData();
      setState(() { _loading = false; });
      return;
    }

    try {
      final result = await GenOfficeSheetsService.openSheet(
        title: widget.title,
        filePath: widget.filePath,
      );

      if (result.ok && mounted) {
        _workspaceId = result.workspaceId;
        // Fetch real cell data from GenOffice
        await _fetchCellData();
        if (mounted) setState(() { _loading = false; });
      } else if (mounted) {
        _loadMockData();
        setState(() { _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        _loadMockData();
        setState(() { _loading = false; });
      }
    }
  }

  /// Fetch cell data for a specific sheet from GenOffice sidecar via HTTP API.
  /// [sheetName] targets one sheet in a multi-sheet workbook; null loads the
  /// first (active) sheet.
  Future<void> _fetchCellData({String? sheetName}) async {
    if (_workspaceId == null) return;
    try {
      final data = await GenOfficeSheetsService.getData(_workspaceId!, sheetName: sheetName);

      // Track the full sheet list + the sheet we're actually showing, so the
      // tabs and every /sheet/write below address the correct sheet name.
      final names = data.sheetNames.isNotEmpty ? data.sheetNames : ['Sheet 1'];
      final activeName = sheetName ?? names[0];
      _sheetNames = names;
      _activeSheetName = activeName;
      final activeIndex = names.indexOf(activeName);
      if (activeIndex >= 0) _activeSheet = activeIndex;

      // Connected to a blank/new workbook (no data yet): show a real empty grid,
      // NOT mock data. The AI copilot populates it.
      if (!data.ok) {
        _showEmptyGrid(sheetNames: names, activeSheetName: activeName);
        return;
      }

      if (data.cells.isEmpty) {
        // Empty but disk-backed: keep the real sheet name(s) from the file so
        // edits round-trip through /sheet/write against the correct sheet.
        _showEmptyGrid(sheetNames: names, activeSheetName: activeName);
        return;
      }

      // Preserve real 0-based coordinates so edits round-trip via /sheet/write.
      final values = <String, String>{};
      final formulas = <String, String>{};
      int maxRow = 0;
      int maxCol = 0;
      for (final cell in data.cells) {
        values['${cell.row},${cell.column}'] = cell.display;
        if (cell.formula != null && cell.formula!.isNotEmpty) {
          formulas['${cell.row},${cell.column}'] = cell.formula!;
        }
        if (cell.row > maxRow) maxRow = cell.row;
        if (cell.column > maxCol) maxCol = cell.column;
      }

      _values = values;
      _formulas = formulas;
      // Fixed minimum grid so the sheet always renders as a full, scrollable
      // spreadsheet (GenOffice/Excel behaviour) rather than shrinking to the
      // used range whenever the AI writes a small table.
      _rowCount = maxRow + 1 < _minGridRows ? _minGridRows : maxRow + 1;
      _colCount = maxCol + 1 < _minGridCols ? _minGridCols : maxCol + 1;
      _colContentWidths = _computeContentWidths(values, _colCount);

      _charts = data.charts;
      _columnWidths = data.columnWidths;
      _rowHeights = data.rowHeights;
      _merges = data.merges;
      _cellStyles = data.cellStyles;
      _defaultRowHeight = data.defaultRowHeight;
      _showGridLines = data.showGridLines;

      // Precompute horizontal merged-cell spans (single-row spans across
      // columns — the common title/header merge) for the grid renderer.
      final colSpan = <String, int>{};
      final covered = <String>{};
      for (final m in _merges) {
        if (m.startRow == m.endRow && m.endColumn > m.startColumn) {
          colSpan['${m.startRow},${m.startColumn}'] = m.endColumn;
          for (var c = m.startColumn + 1; c <= m.endColumn; c++) {
            covered.add('${m.startRow},$c');
          }
        }
      }
      _mergeColSpan = colSpan;
      _mergeCovered = covered;

      debugPrint('📊 [Sheets] Grid loaded: $_rowCount rows × $_colCount cols (sheet "$_activeSheetName")');
    } catch (e) {
      debugPrint('❌ [Sheets] Failed to fetch cell data: $e');
      // We're connected; a read hiccup shouldn't swap in mock financial data.
      _showEmptyGrid(activeSheetName: sheetName);
    }
  }

  /// Switch the visible sheet: update the active name/index, reset per-sheet
  /// selection state, and re-fetch that sheet's cells from GenOffice.
  Future<void> _selectSheet(int index) async {
    if (index < 0 || index >= _sheetNames.length) return;
    setState(() {
      _activeSheet = index;
      _activeSheetName = _sheetNames[index];
      _selectedRow = null;
      _selectedCol = null;
      _formulaController.clear();
    });
    await _fetchCellData(sheetName: _sheetNames[index]);
  }

  /// Connected-but-empty workbook: render a blank sheet (no mock data).
  /// [sheetNames] preserves the real sheet name(s) read back from the file so
  /// cell edits round-trip against the correct sheet (GenOffice uses "Sheet1").
  void _showEmptyGrid({List<String>? sheetNames, String? activeSheetName}) {
    _values = {};
    _formulas = {};
    _selectedRow = null;
    _selectedCol = null;
    _rowCount = _minGridRows;
    _colCount = _minGridCols;
    _sheetNames = (sheetNames != null && sheetNames.isNotEmpty) ? sheetNames : ['Sheet1'];
    _activeSheetName = activeSheetName ?? _sheetNames[0];
    _charts = [];
    _columnWidths = [];
    _colContentWidths = [];
    _rowHeights = {};
    _merges = [];
    _cellStyles = {};
    _defaultRowHeight = 32;
    _showGridLines = true;
    _mergeColSpan = {};
    _mergeCovered = {};
    debugPrint('📊 [Sheets] Empty workbook — showing blank grid (sheet "$_activeSheetName")');
  }

  void _loadMockData() {
    const mock = [
      ['Pendapatan SaaS', '250.000.000', '278.400.000'],
      ['Biaya Cloud Infra', '45.000.000', '41.250.000'],
      ['Gaji & Benefit Tim', '110.000.000', '108.000.000'],
      ['Pemasaran & Iklan', '35.000.000', '39.500.000'],
      ['Operasional Kantor', '22.000.000', '20.500.000'],
      ['R&D Software Tools', '15.000.000', '14.800.000'],
    ];
    final values = <String, String>{};
    for (var r = 0; r < mock.length; r++) {
      for (var c = 0; c < mock[r].length; c++) {
        values['$r,$c'] = mock[r][c];
      }
    }
    _values = values;
    _formulas = {};
    _selectedRow = null;
    _selectedCol = null;
    _rowCount = _minGridRows;
    _colCount = _minGridCols;
    _colContentWidths = _computeContentWidths(values, _colCount);
    _sheetNames = ['Ringkasan', 'Detail Biaya'];
    _activeSheetName = 'Ringkasan';
    _charts = [];
    _columnWidths = [];
    _rowHeights = {};
    _merges = [];
    _cellStyles = {};
    _defaultRowHeight = 32;
    _showGridLines = true;
    _mergeColSpan = {};
    _mergeCovered = {};
  }

  /// 0-based column index → spreadsheet label (0→A, 25→Z, 26→AA, …).
  String _columnLabel(int col) {
    var n = col;
    var label = '';
    while (n >= 0) {
      label = String.fromCharCode(65 + (n % 26)) + label;
      n = (n ~/ 26) - 1;
    }
    return label;
  }

  /// Format a raw cell value for display so the grid matches GenOffice's
  /// `#,##0` rendering instead of leaking raw integers like `37500000`.
  /// Only pure numbers are touched (thousands separators); text, formulas and
  /// already-formatted strings pass through unchanged. The underlying
  /// `_values` map stays raw so edits round-trip through /sheet/write intact.
  String _formatCellValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(trimmed)) return raw;
    final parts = trimmed.split('.');
    final sign = parts[0].startsWith('-') ? '-' : '';
    final digits = parts[0].replaceFirst(RegExp(r'^-'), '');
    final buf = StringBuffer(sign);
    for (var i = 0; i < digits.length; i++) {
      buf.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    if (parts.length > 1) buf.write('.${parts[1]}');
    return buf.toString();
  }

  /// True when row 0 reads as a header row (text labels over numeric data),
  /// matching the tables the sheets AI generates (bold title row + number rows).
  bool get _hasHeaderRow {
    if (_rowCount < 2) return false;
    bool anyText = false;
    bool anyNumericBelow = false;
    for (var c = 0; c < _colCount; c++) {
      final top = (_values['0,$c'] ?? '').trim();
      if (top.isNotEmpty && !RegExp(r'^-?\d').hasMatch(top)) anyText = true;
      final below = (_values['1,$c'] ?? '').trim();
      if (below.isNotEmpty && RegExp(r'^-?\d').hasMatch(below)) anyNumericBelow = true;
    }
    return anyText && anyNumericBelow;
  }

  /// Tap a cell's edit (✎) icon → dialog → persist back via /sheet/write.
  Future<void> _editCell(int row, int col) async {
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
    });

    final key = '$row,$col';
    // A formula cell shows its raw formula in the editor (like Excel), not its
    // computed value, so the user can tweak `=SUM(...)` and re-commit it.
    final current = _formulas[key] ?? _values[key] ?? '';
    final controller = TextEditingController(text: current);
    final newValue = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit ${_columnLabel(col)}${row + 1}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono'),
          decoration: const InputDecoration(hintText: 'Nilai atau rumus (awali =)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Simpan')),
        ],
      ),
    );
    controller.dispose();

    if (newValue == null || newValue == current) return;
    if (!mounted) return;

    await _persistCellEdit(row, col, newValue);
  }

  /// Select a cell and surface its value/formula in the formula bar. This is the
  /// primary tap action (real-Excel model); value editing happens via the ✎ icon.
  void _selectCell(int row, int col) {
    final key = '$row,$col';
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _formulaController.text = _formulas[key] ?? _values[key] ?? '';
      _formulaController.selection = TextSelection.fromPosition(
        TextPosition(offset: _formulaController.text.length),
      );
    });
  }

  /// Commit the formula bar's content to the selected cell (value or `=` formula).
  Future<void> _commitFormulaBar(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (_selectedRow == null || _selectedCol == null) return;
    await _persistCellEdit(_selectedRow!, _selectedCol!, trimmed);
  }

  /// Write one cell edit to GenOffice and fold the computed result back into the
  /// grid. Formula cells (`=…`) get their IronCalc-computed value from the write
  /// response; literal values overwrite the cell and clear any stored formula.
  Future<void> _persistCellEdit(int row, int col, String newValue) async {
    final key = '$row,$col';

    // Optimistic update for instant feedback; corrected (or refetched) below.
    setState(() => _values[key] = newValue);

    if (_workspaceId == null) return;
    final result = await GenOfficeSheetsService.writeCells(
      _workspaceId!,
      _activeSheetName,
      [{'row': row, 'column': col, 'value': newValue}],
    );
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan sel: ${result.error ?? "unknown"}')),
      );
      await _fetchCellData(sheetName: _activeSheetName);
      return;
    }

    final isFormula = newValue.trim().startsWith('=');
    if (isFormula) {
      String computed = '';
      for (final r in result.results) {
        if (r.row == row && r.column == col) {
          computed = r.value?.toString() ?? '';
          break;
        }
      }
      setState(() {
        _formulas[key] = newValue;
        _values[key] = computed;
        _formulaController.text = newValue;
      });
    } else {
      setState(() {
        _formulas.remove(key);
        _formulaController.text = newValue;
      });
    }
  }

  @override
  void dispose() {
    _sheetStreamSub?.cancel();
    _sheetStream.dispose();
    _formulaController.dispose();
    _aiInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  /// Auto-scroll the chat thread to the newest bubble after a message is added.
  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Patch the trailing streaming assistant bubble with the latest accumulated
  /// AI text from GenOffice's WebSocket, or open a new one if none is streaming.
  void _onSheetAiDelta(SheetAiDelta delta) {
    if (!mounted || delta.workspaceId != _workspaceId) return;
    setState(() {
      if (_chatMessages.isNotEmpty &&
          !_chatMessages.last.isUser &&
          _chatMessages.last.streaming) {
        _chatMessages[_chatMessages.length - 1] = _ChatMessage(
          text: delta.text,
          isUser: false,
          streaming: true,
        );
      } else {
        _chatMessages.add(_ChatMessage(
          text: delta.text,
          isUser: false,
          streaming: true,
        ));
      }
    });
    _scrollChatToBottom();
  }

  /// GenOffice's AI reply arrives as Markdown (bold, links, tables). The chat
  /// bubble renders plain text, so strip the markup into clean readable prose
  /// instead of leaking raw `**`, `|`, and `[text](url)` glyphs into the UI.
  String _cleanMarkdown(String input) {
    var text = input;
    // Inline links/citations: [Sheet1](sheetnav://...) -> Sheet1
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1');
    // Bold / italic markers
    text = text.replaceAll('**', '');
    text = text.replaceAll('__', '');
    // Markdown table separator rows (e.g. |---|---|)
    text = text.replaceAll(RegExp(r'^\s*\|[\s:\-|]+\|\s*$', multiLine: true), '');
    // Headings: "## Title" -> "Title"
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Collapse 3+ blank lines into one
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  // ── AI Prompt (shared by formula bar & copilot) ──

  Future<void> _sendPrompt(String instruction) async {
    final trimmed = instruction.trim();
    if (_workspaceId == null || trimmed.isEmpty) return;

    setState(() {
      _aiProcessing = true;
      _chatMessages.add(_ChatMessage(text: trimmed, isUser: true));
      // Open a streaming assistant bubble; WebSocket deltas fill it in live.
      _chatMessages.add(_ChatMessage(text: '', isUser: false, streaming: true));
    });
    _scrollChatToBottom();

    try {
      final result = await GenOfficeSheetsService.prompt(_workspaceId!, trimmed);
      if (mounted) {
        // Give the workbook's auto-save a moment to flush the AI's edits, then
        // re-read the grid so the table reflects them.
        final cellsBefore = _values.length;
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) await _fetchCellData(sheetName: _activeSheetName);
        if (mounted) {
          final cellsAfter = _values.length;
          final tableChanged = cellsAfter != cellsBefore;
          setState(() {
            _aiProcessing = false;
            final replyText = result.reply?.trim().isNotEmpty == true
                ? result.reply!.trim()
                : (result.ok ? 'Selesai — sheet diproses oleh GenOffice AI.' : (result.error ?? 'Gagal memproses'));
            final finalText = result.ok && tableChanged
                ? '$replyText\n\n✅ Tabel sheet diperbarui ($cellsAfter sel).'
                : replyText;
            _finalizeAssistant(finalText, isError: !result.ok);
          });
          _scrollChatToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiProcessing = false;
          _finalizeAssistant('Error: $e', isError: true);
        });
      }
    }
  }

  /// Replace the trailing streaming assistant bubble with its final text. If no
  /// streaming bubble is present (e.g. the WS was never connected), append one.
  void _finalizeAssistant(String text, {required bool isError}) {
    if (_chatMessages.isNotEmpty &&
        !_chatMessages.last.isUser &&
        _chatMessages.last.streaming) {
      _chatMessages[_chatMessages.length - 1] = _ChatMessage(
        text: text,
        isUser: false,
        isError: isError,
      );
    } else {
      _chatMessages.add(_ChatMessage(
        text: text,
        isUser: false,
        isError: isError,
      ));
    }
  }

  // ── Export ──

  Future<void> _exportSheet() async {
    if (_workspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada workbook untuk diekspor')),
      );
      return;
    }
    final result = await GenOfficeSheetsService.export(_workspaceId!);
    if (!mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export gagal: ${result.error ?? "unknown"}')),
      );
      return;
    }

    // The sidecar already saved the workbook (data + charts) to a real .xlsx on
    // disk; `export` returns those bytes base64-encoded. Write them to a local
    // file so the user can open/save an actual Excel file, not just a path on
    // the GenOffice host (which the Flutter device can't reach).
    final bytes = result.fileBytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export gagal: file kosong')),
      );
      return;
    }

    final baseName = (widget.title ?? 'Laporan Keuangan')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');

    try {
      // Desktop: native "Save As" dialog. `share_plus` has no Windows/Linux
      // implementation, so the old Share.shareXFiles path threw here and the
      // user couldn't download anything — a real save dialog fixes that.
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        var outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan Excel',
          fileName: '$baseName.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
        if (outputPath == null) return; // user cancelled the dialog
        if (!outputPath.toLowerCase().endsWith('.xlsx')) outputPath = '$outputPath.xlsx';
        await File(outputPath).writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tersimpan: $outputPath')),
          );
        }
        return;
      }

      // Mobile: write to documents then open the share sheet.
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tersimpan: $path')),
        );
      }

      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: baseName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _buildHeader(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _greenAccent)))
          else ...[
            _buildFormulaBar(),
            if (_workspaceId != null) _buildConnectionBadge(),
            _buildSummaryCard(),
            if (_workspaceId != null && _values.isEmpty) _buildAiCtaBanner(),
            Expanded(child: _buildDataTable()),
            _buildSheetTabs(),
          ],
        ],
      ),
      floatingActionButton: _buildAiFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomSheet: _aiSheetOpen ? _buildAiBottomSheet() : null,
    );
  }

  // ── Connection Badge ──

  Widget _buildConnectionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: _greenLight,
      child: Row(
        children: [
          Icon(
            _genOfficeAvailable ? Icons.cloud_done : Icons.cloud_off,
            size: 12,
            color: _genOfficeAvailable ? _greenAccent : AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            _genOfficeAvailable ? 'Keqo connected' : 'Offline mode (mock data)',
            style: TextStyle(fontSize: 10, color: _genOfficeAvailable ? _greenDark : AppTheme.textMuted),
          ),
          if (_aiProcessing) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: _greenAccent)),
          ],
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 4,
        right: 12,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.outline.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            color: AppTheme.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          // File type badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.table_chart, size: 16, color: _greenAccent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.title ?? 'Laporan Keuangan',
                        maxLines: 1,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _greenContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('XLSX',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _greenAccent, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: _greenAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _workspaceId != null ? 'Tersimpan otomatis' : 'Offline',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _headerIcon(Icons.undo, () {}),
          _headerIcon(Icons.redo, () {}),
          _headerIcon(Icons.upload, _exportSheet),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _exportSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _greenAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share, size: 14, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Bagi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: AppTheme.textSecondary,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
    );
  }

  // ── Formula Bar ───────────────────────────────────────────────────

  Widget _buildFormulaBar() {
    final hasSelection = _selectedRow != null && _selectedCol != null;
    final ref = hasSelection ? '${_columnLabel(_selectedCol!)}${_selectedRow! + 1}' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: _greenLight,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _greenAccent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ref.isNotEmpty ? ref : 'fx',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _greenBorder),
              ),
              child: TextField(
                controller: _formulaController,
                style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono', color: AppTheme.textPrimary),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                onSubmitted: (value) => _commitFormulaBar(value),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _formulaController.clear(),
            child: const Icon(Icons.close, size: 18, color: AppTheme.error),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _commitFormulaBar(_formulaController.text),
            child: const Icon(Icons.check, size: 18, color: _greenAccent),
          ),
        ],
      ),
    );
  }

  // ── Summary Card (dynamic from real data) ──────────────────────────

  Widget _buildSummaryCard() {
    // Compute stats from actual grid data
    final connected = _workspaceId != null;
    final filledCells = _values.values.where((v) => v.isNotEmpty).length;
    final hasData = filledCells > 0;

    // Try to find numeric values in the grid for a summary
    String summaryLabel;
    String summaryValue;
    String summaryBadge;
    String summarySub;

    if (!connected) {
      summaryLabel = 'Mode offline — demo data';
      summaryValue = 'Keqo AI tidak terhubung';
      summaryBadge = 'OFFLINE';
      summarySub = 'Jalankan GenOffice';
    } else if (!hasData) {
      summaryLabel = 'Sheet kosong — siap diisi';
      summaryValue = 'Minta AI buatkan tabel';
      summaryBadge = '0 sel';
      summarySub = _activeSheetName;
    } else {
      summaryLabel = '$_rowCount baris × $_colCount kolom';
      summaryValue = _values['0,0'] ?? '-';
      summaryBadge = '$filledCells sel';
      summarySub = _activeSheetName;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _greenBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _greenAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_chart, size: 20, color: _greenAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summaryLabel,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(summaryValue,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _greenContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(summaryBadge,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _greenAccent)),
              ),
              const SizedBox(height: 2),
              Text(summarySub,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI CTA banner (empty connected sheet) ─────────────────────────

  Widget _buildAiCtaBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_greenLight, _greenContainer]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _greenBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_greenAccent, _greenDark]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sheet masih kosong. Ketik apa yang kamu mau — Keqo AI akan mengisinya.',
              style: TextStyle(fontSize: 12.5, color: _greenDark, height: 1.3),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _aiSheetOpen = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _greenAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Isi dengan AI',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Charts (floating overlays) ────────────────────────────────────

  static const double _emuPerPx = 9525.0; // 1px at 96dpi (EMU → px)
  static const double _rowNumWidth = 44.0;
  static const double _minChartW = 140.0;
  static const double _minChartH = 96.0;

  // The grid is a fixed, always-scrollable sheet (like Excel/GenOffice), not a
  // tight bounding box around the used range — otherwise it "shrinks" to fit
  // whatever few cells happen to hold content. Empty rows/columns stay rendered.
  static const int _minGridCols = 26;
  static const int _minGridRows = 100;
  static const double _defaultColWidth = 120.0;

  /// Pixel x of a column's left edge in grid content coordinates (excludes
  /// the row-number gutter).
  double _colX(int col) {
    var x = 0.0;
    for (var c = 0; c < col; c++) {
      x += _colWidth(c);
    }
    return x;
  }

  /// Pixel y of a row's top edge in grid content coordinates (excludes the
  /// column-header strip).
  double _rowY(int row) {
    var y = 0.0;
    for (var r = 0; r < row; r++) {
      y += _rowHeight(r);
    }
    return y;
  }

  /// On-grid box (content coordinates) a chart occupies, resolved from its
  /// anchor + the real column widths/row heights, so it floats over the same
  /// cells Excel anchored it to.
  Rect _chartBox(SheetChart chart) {
    final a = chart.anchor;
    final left = _colX(a.fromColumn) + a.fromColumnOffset / _emuPerPx;
    final top = _rowY(a.fromRow) + a.fromRowOffset / _emuPerPx;
    final right = _colX(a.toColumn) + a.toColumnOffset / _emuPerPx;
    final bottom = _rowY(a.toRow) + a.toRowOffset / _emuPerPx;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Positioned chart overlays; the Stack offsets them by the gutter + header
  /// strip so they line up with the data cells below.
  List<Widget> _chartOverlays() {
    final overlays = <Widget>[];
    for (final chart in _charts) {
      final box = _chartBox(chart);
      overlays.add(Positioned(
        left: _rowNumWidth + box.left,
        top: _defaultRowHeight + box.top,
        width: box.width.clamp(_minChartW, double.infinity),
        height: box.height.clamp(_minChartH, double.infinity),
        child: SheetChartOverlay(chart: chart),
      ));
    }
    return overlays;
  }

  // ── Data Table ────────────────────────────────────────────────────

  /// Column width in px: real GenOffice width when present, raised to a
  /// comfortable floor, then widened to fit its longest cell so generated
  /// content never gets cramped or truncated to "…". Columns beyond the
  /// sheet's used range (the fixed empty tail) share the same default.
  double _colWidth(int c) {
    final sidecar = (_columnWidths.isNotEmpty && c < _columnWidths.length)
        ? _columnWidths[c]
        : 0.0;
    final content = (c >= 0 && c < _colContentWidths.length) ? _colContentWidths[c] : 0.0;
    var w = sidecar < _defaultColWidth ? _defaultColWidth : sidecar;
    if (content > w) w = content;
    return w;
  }

  /// Estimated pixel width each column needs to show its longest formatted
  /// cell value without truncating, so the grid auto-fits its content instead
  /// of collapsing to a too-narrow default (the "shrunk / overlapping" bug).
  List<double> _computeContentWidths(Map<String, String> values, int colCount) {
    final widths = List<double>.filled(colCount, 0.0);
    for (final entry in values.entries) {
      final comma = entry.key.lastIndexOf(',');
      if (comma < 0) continue;
      final col = int.tryParse(entry.key.substring(comma + 1));
      if (col == null || col < 0 || col >= colCount) continue;
      final text = _formatCellValue(entry.value);
      // ~7px per char at fontSize 12.5 + cell padding + the edit affordance.
      final w = (text.length * 7.0 + 28.0).clamp(0.0, 360.0);
      if (w > widths[col]) widths[col] = w;
    }
    return widths;
  }

  double _rowHeight(int r) => _rowHeights[r] ?? _defaultRowHeight;

  BoxDecoration _cellBox(Color fill) {
    return BoxDecoration(
      color: fill,
      border: _showGridLines
          ? Border(
              right: BorderSide(color: AppTheme.outline.withValues(alpha: 0.35), width: 0.5),
              bottom: BorderSide(color: AppTheme.outline.withValues(alpha: 0.35), width: 0.5),
            )
          : null,
    );
  }

  Widget _buildDataTable() {
    const rowNumWidth = 44.0;
    final widths = <double>[rowNumWidth];
    for (var c = 0; c < _colCount; c++) {
      widths.add(_colWidth(c));
    }
    final totalWidth = widths.fold<double>(0.0, (a, b) => a + b);
    final headerHeight = _defaultRowHeight;

    return Scrollbar(
      // Nested scroll views give 2D scrolling: the outer scrolls vertically
      // (rows), the inner horizontally (columns). Without the vertical axis the
      // Column's many rows overflow the Expanded's bounded height (the
      // "BOTTOM OVERFLOWED BY N PIXELS" debug stripes).
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Column(
                  children: [
                // Column headers (A, B, C, …) — grey Univer-style strip
                Row(
                  children: [
                    _cornerHeader(widths[0], headerHeight),
                    for (var c = 0; c < _colCount; c++)
                      _colHeader(_columnLabel(c), widths[c + 1], headerHeight),
                  ],
                ),
                // Data rows — every cell tappable to edit in place
                ...List.generate(_rowCount, (r) {
                  final rowH = _rowHeight(r);
                  return Row(
                    children: [
                      _rowNumHeader('${r + 1}', widths[0], rowH),
                      for (var c = 0; c < _colCount; c++)
                        _buildDataCell(r, c, widths[c + 1], rowH),
                    ],
                  );
                }),
                if (_rowCount == 0)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada data', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                  ),
              ],
            ),
            ..._chartOverlays(),
            ],
          ),
        ),
      ),
    ),
    );
  }

  /// Render a data cell, expanding horizontally when it anchors a merged range
  /// and skipping cells covered by one.
  Widget _buildDataCell(int r, int c, double width, double rowH) {
    final key = '$r,$c';
    if (_mergeCovered.contains(key)) return const SizedBox.shrink();
    final spanEnd = _mergeColSpan[key];
    if (spanEnd != null) {
      var w = width;
      for (var cc = c + 1; cc <= spanEnd && cc < _colCount; cc++) {
        w += _colWidth(cc);
      }
      return _editableCell(r, c, w, isRight: c > 0, height: rowH);
    }
    return _editableCell(r, c, width, isRight: c > 0, height: rowH);
  }

  Widget _editableCell(int row, int col, double width, {bool isRight = false, double? height}) {
    final raw = _values['$row,$col'] ?? '';
    final value = _formatCellValue(raw);
    final style = _cellStyles['$row,$col'];
    final isSelected = _selectedRow == row && _selectedCol == col;
    final headerRow = _hasHeaderRow && row == 0;

    final bold = style?.bold ?? headerRow;
    final italic = style?.italic ?? false;
    final fill = _hexColor(style?.fill);
    final textColor = _hexColor(style?.color) ?? (headerRow ? _greenDark : AppTheme.textPrimary);
    final align = style?.align;

    final TextAlign textAlign = align == 'center'
        ? TextAlign.center
        : (align == 'right' || (align == null && isRight) ? TextAlign.right : TextAlign.left);
    final rightAlign = textAlign == TextAlign.right;

    return GestureDetector(
      onTap: () => _selectCell(row, col),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: _cellBox(isSelected ? _greenContainer.withValues(alpha: 0.7) : (fill ?? Colors.white)),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                textAlign: textAlign,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  fontFamily: rightAlign ? 'JetBrains Mono' : null,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () => _editCell(row, col),
              child: Icon(Icons.edit, size: 10, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerHeader(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: _cellBox(AppTheme.surfaceContainerHighest),
    );
  }

  Widget _colHeader(String text, double width, double height) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: _cellBox(AppTheme.surface3),
      child: Text(text,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.2)),
    );
  }

  Widget _rowNumHeader(String text, double width, double height) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: _cellBox(AppTheme.surface3),
      child: Text(text,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppTheme.textMuted)),
    );
  }

  // ── AI FAB Button ─────────────────────────────────────────────────

  Widget _buildAiFab() {
    return GestureDetector(
      onTap: () => setState(() => _aiSheetOpen = !_aiSheetOpen),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_greenAccent, _greenDark]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: _greenAccent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_aiProcessing ? Icons.hourglass_top : Icons.auto_awesome, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(_aiProcessing ? 'Processing...' : 'Keqo AI',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // ── AI Copilot Bottom Sheet ───────────────────────────────────────

  Widget _buildAiBottomSheet() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: MediaQuery.of(context).size.height * 0.52,
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_greenAccent, _greenDark]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Keqo AI Copilot',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: _greenContainer, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                _genOfficeAvailable ? 'EXCEL PRO' : 'MOCK',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _genOfficeAvailable ? _greenAccent : AppTheme.textMuted, letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: _genOfficeAvailable ? _greenAccent : AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _workspaceId != null ? 'Workspace: ${_workspaceId!.substring(0, 8)}...' : 'No workspace',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppTheme.textMuted,
                    onPressed: () => setState(() => _aiSheetOpen = false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Quick action chips — send a real prompt to GenOffice AI
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _aiChip(Icons.table_chart, 'Buatkan Tabel', true),
                  const SizedBox(width: 8),
                  _aiChip(Icons.functions, 'Tambahkan Rumus', false),
                ],
              ),
            ),
            // Chat message thread (user prompt ↔ GenOffice AI reply)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _chatMessages.isEmpty
                    ? _buildEmptyChatHint()
                    : ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.only(bottom: 4),
                        itemCount: _chatMessages.length,
                        itemBuilder: (_, i) => _buildChatBubble(_chatMessages[i]),
                      ),
              ),
            ),
            // Input bar
            Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, MediaQuery.of(context).padding.bottom + 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _greenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.smart_toy, size: 14, color: _greenAccent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _aiInputController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Minta AI buat / isi / edit tabel ini',
                          hintStyle: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _sendPrompt(value.trim());
                            _aiInputController.clear();
                          }
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final v = _aiInputController.text.trim();
                        if (v.isNotEmpty) {
                          _sendPrompt(v);
                          _aiInputController.clear();
                        }
                      },
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: _greenAccent, borderRadius: BorderRadius.circular(8)),
                        child: _aiProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.arrow_upward, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiChip(IconData icon, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        // Quick action: send a preset prompt to GenOffice AI
        if (label == 'Buatkan Tabel') {
          _sendPrompt('Buatkan tabel data contoh di sheet ini: beri header kolom yang jelas dan beberapa baris data.');
        } else {
          _sendPrompt('Tambahkan kolom total dan rumus SUM/AVERAGE otomatis untuk kolom angka di sheet ini.');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? _greenLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: _greenAccent) : Border.all(color: AppTheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? _greenAccent : AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w500,
              color: isActive ? _greenDark : AppTheme.textSecondary,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    final bubbleColor = isUser
        ? _greenAccent
        : (msg.isError ? const Color(0xFFFEE2E2) : _greenLight);
    final borderColor = isUser ? null : Border.all(color: msg.isError ? const Color(0xFFFECACA) : _greenBorder);
    final labelColor = isUser
        ? Colors.white.withValues(alpha: 0.92)
        : (msg.isError ? const Color(0xFFDC2626) : _greenDark);
    final iconColor = isUser ? Colors.white : (msg.isError ? const Color(0xFFDC2626) : _greenAccent);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: borderColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person : (msg.isError ? Icons.error_outline : Icons.auto_awesome),
                  size: 13,
                  color: iconColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isUser ? 'Kamu' : (msg.isError ? 'AI Error' : 'Keqo AI'),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: labelColor),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (msg.streaming && msg.text.isEmpty)
              _buildStreamingIndicator()
            else
              Text(
                msg.isUser ? msg.text : _cleanMarkdown(msg.text),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            if (msg.streaming && msg.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildStreamingIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  /// Small "writing…" affordance shown while the assistant bubble is still
  /// receiving streamed text from GenOffice.
  Widget _buildStreamingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: _greenAccent,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'menulis…',
          style: TextStyle(
            fontSize: 11,
            color: _greenDark.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChatHint() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_greenAccent, _greenDark]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_awesome, size: 26, color: Colors.white),
        ),
        const SizedBox(height: 14),
        const Text('Keqo AI siap membuat & mengedit tabel ini',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Ketik permintaanmu — misal "buatkan tabel laporan penjualan Januari–Desember" — AI akan mengisi sheet ini langsung di GenOffice.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _sendPrompt(
              'Buatkan tabel laporan penjualan bulanan dengan kolom Bulan, Produk, Jumlah, dan Pendapatan, lengkap dengan data contoh.'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _greenAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_fix_high, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text('Buat contoh tabel',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Sheet Tabs ────────────────────────────────────────────────────

  Widget _buildSheetTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.outline.withValues(alpha: 0.4))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _sheetNames.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _selectSheet(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _activeSheet == i ? _greenLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _activeSheet == i
                          ? Border.all(color: _greenAccent, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description, size: 14,
                            color: _activeSheet == i ? _greenAccent : AppTheme.textMuted),
                        const SizedBox(width: 5),
                        Text('Sheet ${i + 1}: ${_sheetNames[i]}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _activeSheet == i ? _greenDark : AppTheme.textSecondary)),
                        if (_activeSheet == i) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: _greenAccent, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _greenAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.grid_on, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
