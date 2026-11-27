// DocuCraft — Document Editor Screen
// Mengikuti desain stitch_keko: emulasi kertas A4, bottom sheet asisten AI,
// toolbar format ber-tab (Teks/Paragraf/Sisipkan).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/endpoints.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../services/api_client.dart';
import '../themes/app_theme.dart';

/// A single message in the document AI chat room.
class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  const _ChatMessage({required this.role, required this.text});
}

class DocumentEditorScreen extends StatefulWidget {
  final String? documentId;
  final String? initialPrompt;
  final String? workspaceId;

  const DocumentEditorScreen({super.key, this.documentId, this.initialPrompt, this.workspaceId});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _editingBlockIndex;
  bool _initialized = false;
  int _activeToolbarTab = 0; // 0=Teks, 1=Paragraf, 2=Sisipkan
  bool _aiSheetOpen = false;
  bool _aiLoading = false;
  final TextEditingController _aiInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<_ChatMessage> _chatMessages = [];
  String? _workspaceId;
  bool _listeningWorkspace = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDocument());
  }

  Future<void> _initDocument() async {
    if (_initialized) return;
    _initialized = true;
    final docProvider = context.read<DocumentProvider>();
    if (widget.documentId != null) {
      await docProvider.openDocument(widget.documentId!);
    } else {
      await docProvider.createDocument(title: 'Dokumen Tanpa Judul');
    }
    docProvider.startAutoSave();

    // Use workspaceId passed from dashboard, or open a new one
    if (widget.workspaceId != null) {
      _workspaceId = widget.workspaceId;
      _listenWorkspaceResponses();
    } else {
      try {
        final api = GenOfficeClient();
        final result = await api.openDocumentWorkspace();
        if (result['ok'] == true) {
          _workspaceId = result['workspaceId'] as String?;
          _listenWorkspaceResponses();
        }
      } catch (_) {
        // GenOffice may not be running; standalone Flutter mode still works
      }
    }
  }

  /// Listen for AI responses from GenOffice docs workspace via WebSocket.
  void _listenWorkspaceResponses() {
    if (_listeningWorkspace || _workspaceId == null) return;
    _listeningWorkspace = true;
    final wsUrl = Endpoints.ws;
    try {
      final ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      ws.stream.listen((message) {
        try {
          final event = jsonDecode(message as String) as Map<String, dynamic>;
          if (event['workspaceId'] != _workspaceId || !mounted) return;
          final type = event['type'] as String?;
          final data = event['data'] as Map<String, dynamic>? ?? {};

          // AI turn finished: stop the spinner, show the reply, apply the final snapshot
          if (type == 'document-ai-response') {
            final documentBlocks = data['documentBlocks'] as List?;
            final text = data['text'] as String? ?? '';
            final error = data['error'] as String?;
            setState(() {
              _aiLoading = false;
              if (error != null && error.isNotEmpty) {
                _chatMessages.add(_ChatMessage(role: 'assistant', text: '⚠️ $error'));
              } else if (text.isNotEmpty) {
                _chatMessages.add(_ChatMessage(role: 'assistant', text: text));
              }
            });
            _scrollChatToBottom();
            if (documentBlocks != null && documentBlocks.isNotEmpty) {
              context.read<DocumentProvider>().replaceFromGenOffice(documentBlocks);
            }
          }
          // Real-time content push: follow GenOffice edits live
          else if (type == 'document-content') {
            final documentBlocks = data['documentBlocks'] as List?;
            if (documentBlocks != null && documentBlocks.isNotEmpty) {
              context.read<DocumentProvider>().replaceFromGenOffice(documentBlocks);
            }
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _aiInputController.dispose();
    _chatScrollController.dispose();
    context.read<DocumentProvider>().stopAutoSave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildSubHeader(),
          Expanded(child: _buildDocumentBody()),
        ],
      ),
      // Bottom formatting toolbar (tabbed: Teks/Paragraf/Sisipkan)
      bottomNavigationBar: _buildBottomToolbar(),
      // FAB Keqo AI
      floatingActionButton: _buildAiFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      // AI Bottom Sheet overlay
      bottomSheet: _aiSheetOpen ? _buildAiBottomSheet() : null,
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
          Flexible(
            child: Text('Document Editor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            color: AppTheme.textSecondary,
            onPressed: () {},
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Icon(Icons.person, color: Colors.white, size: 16)),
          ),
        ],
      ),
    );
  }

  // ── Sub-header meta bar ───────────────────────────────────────────

  Widget _buildSubHeader() {
    return Consumer<DocumentProvider>(
      builder: (_, docProvider, _) {
        final doc = docProvider.currentDocument;
        final title = doc?.title ?? 'Dokumen Tanpa Judul';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.surface3,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.description, size: 16, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        Row(
                          children: [
                            SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.success),
                            ),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text('Menyimpan otomatis',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 9, color: AppTheme.success)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _headerAction(Icons.undo, () {}),
                        _headerAction(Icons.redo, () {}),
                        _headerAction(Icons.person_add, () {}),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text('Selesai',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Collaborator pill + page count
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text('3 orang sedang mengedit',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text('Hal 1 dari 1',
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: AppTheme.textSecondary,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
    );
  }

  // ── Document Body (A4 paper emulation) ────────────────────────────

  Widget _buildDocumentBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Consumer<DocumentProvider>(
            builder: (_, docProvider, _) {
              final doc = docProvider.currentDocument;
              if (doc == null) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('Memuat dokumen...', style: TextStyle(color: AppTheme.textMuted))),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface2,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand marker
                    Row(
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
                          child: const Center(
                            child: Text('K', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('KEQO STUDIO',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 1)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Title
                    _buildTitleField(doc),
                    const SizedBox(height: 4),
                    Container(width: 48, height: 3, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 12),
                    // Meta info bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface3,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user, size: 14, color: AppTheme.primary),
                          SizedBox(width: 6),
                          Text('Kategori: Draft Dokumen', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Spacer(),
                          Text('Revisi v1.0', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Blocks
                    ...doc.blocks.asMap().entries.map((entry) =>
                      _buildBlock(entry.key, entry.value, docProvider)),
                    const SizedBox(height: 8),
                    _buildAddBlockButton(docProvider),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(Document doc) {
    return Consumer<DocumentProvider>(
      builder: (_, docProvider, _) {
        return TextFormField(
          initialValue: doc.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.2),
          decoration: const InputDecoration(
            border: InputBorder.none, hintText: 'Judul dokumen...',
            hintStyle: TextStyle(color: AppTheme.textMuted), isDense: true, contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) => docProvider.updateTitle(v),
        );
      },
    );
  }

  Widget _buildBlock(int index, DocumentBlock block, DocumentProvider docProvider) {
    final isEditing = _editingBlockIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _editingBlockIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: isEditing
            ? BoxDecoration(border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(4))
            : null,
        child: _buildBlockContent(index, block, docProvider),
      ),
    );
  }

  Widget _buildBlockContent(int index, DocumentBlock block, DocumentProvider docProvider) {
    final isEditing = _editingBlockIndex == index;
    switch (block.type) {
      case BlockType.heading1:
        return _blockText(index, block, docProvider, isEditing,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.3),
            placeholder: 'Heading 1');
      case BlockType.heading2:
        return _blockText(index, block, docProvider, isEditing,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3),
            placeholder: 'Heading 2');
      case BlockType.bulletList:
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 7, right: 8), child: Icon(Icons.circle, size: 5, color: AppTheme.textPrimary)),
          Expanded(child: _blockText(index, block, docProvider, isEditing,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5), placeholder: 'List item')),
        ]);
      case BlockType.numberedList:
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 20, height: 20, margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white))),
          ),
          Expanded(child: _blockText(index, block, docProvider, isEditing,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5), placeholder: 'List item')),
        ]);
      case BlockType.divider:
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Container(height: 1, color: AppTheme.outline));
      case BlockType.table:
        return _buildTable(block);
      case BlockType.paragraph:
      default:
        return _blockText(index, block, docProvider, isEditing,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.6),
            placeholder: 'Ketik atau minta AI untuk menulis...');
    }
  }

  /// Renders a block as rich text (per-run bold/italic/underline) when not editing,
  /// or as an editable field when tapped.
  Widget _blockText(int index, DocumentBlock block, DocumentProvider docProvider, bool isEditing,
      {required TextStyle style, required String placeholder}) {
    if (isEditing) return _editableBlock(index, block, docProvider, style: style, placeholder: placeholder);
    return _richBlockText(block, style);
  }

  /// Rich-text rendering of a block's runs (preserves bold/italic/underline).
  Widget _richBlockText(DocumentBlock block, TextStyle style) {
    if (block.runs.isEmpty) {
      return Text(block.text, style: style);
    }
    final spans = block.runs.map((r) {
      return TextSpan(
        text: r.text,
        style: style.copyWith(
          fontWeight: r.bold ? FontWeight.bold : style.fontWeight,
          fontStyle: r.italic ? FontStyle.italic : style.fontStyle,
          decoration: r.underline ? TextDecoration.underline : style.decoration,
          color: r.color != null ? _parseHexColor(r.color!) : style.color,
          fontFamily: r.fontFamily,
          fontSize: r.fontSize,
        ),
      );
    }).toList();
    return Text.rich(TextSpan(children: spans), style: style);
  }

  /// Table renderer from `block.tableData`, honoring GenOffice's cell styles —
  /// proportional column widths, header shading, per-cell alignment/fill/color.
  Widget _buildTable(DocumentBlock block) {
    final data = block.tableData ?? [];
    if (data.isEmpty) return const SizedBox.shrink();
    final colWidths = block.tableColWidthsPct;
    final hasHeader = block.tableHasHeader;
    final cells = block.tableCells;

    final colCount = data.fold<int>(0, (a, row) => row.length > a ? row.length : a);
    if (colCount == 0) return const SizedBox.shrink();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        columnWidths: {
          for (var c = 0; c < colCount; c++)
            c: FlexColumnWidth(
              colWidths != null && c < colWidths.length && colWidths[c] > 0 ? colWidths[c] : 1.0,
            ),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: AppTheme.outline, width: 0.5),
          verticalInside: BorderSide(color: AppTheme.outline, width: 0.5),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var r = 0; r < data.length; r++)
            TableRow(
              children: [
                for (var c = 0; c < colCount; c++)
                  _buildTableCell(
                    c < data[r].length ? data[r][c] : '',
                    style: (cells != null && r < cells.length && c < cells[r].length)
                        ? cells[r][c]
                        : null,
                    isHeader: hasHeader && r == 0,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {TableBlockCell? style, bool isHeader = false}) {
    final bold = isHeader || (style?.bold ?? false);
    final fill = style?.fill;
    final color = style?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: fill != null ? _parseHexColorOrNull(fill) : null,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color != null
              ? _parseHexColorOrNull(color) ?? AppTheme.textPrimary
              : AppTheme.textPrimary,
          height: 1.4,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: _tableAlign(style?.align),
      ),
    );
  }

  Color _parseHexColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return AppTheme.textPrimary;
    final value = int.tryParse(h, radix: 16);
    return value == null ? AppTheme.textPrimary : Color(value);
  }

  /// Nullable hex parser (hex without '#', e.g. 'F2F2F2'); null on invalid so a
  /// cell can opt out of a fill/color rather than fall back to the text color.
  Color? _parseHexColorOrNull(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(value);
  }

  TextAlign _tableAlign(String? align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  Widget _editableBlock(int index, DocumentBlock block, DocumentProvider docProvider,
      {required TextStyle style, required String placeholder}) {
    return TextFormField(
      initialValue: block.text,
      style: style, maxLines: null, keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        border: InputBorder.none, hintText: placeholder,
        hintStyle: style.copyWith(color: AppTheme.textMuted.withValues(alpha: 0.5)),
        isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 2),
      ),
      onChanged: (v) {
        docProvider.updateBlock(index, DocumentBlock(
          id: block.id, type: block.type,
          runs: [TextRun(text: v, bold: block.runs.isNotEmpty && block.runs[0].bold)],
          align: block.align,
        ));
      },
    );
  }

  Widget _buildAddBlockButton(DocumentProvider docProvider) {
    return GestureDetector(
      onTap: () {
        docProvider.insertBlock(null, DocumentBlock.paragraph(''));
        setState(() => _editingBlockIndex = docProvider.currentDocument!.blocks.length - 1);
      },
      child: Row(children: [
        Icon(Icons.add, size: 14, color: AppTheme.textMuted.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text('Tambah blok', style: TextStyle(fontSize: 11, color: AppTheme.textMuted.withValues(alpha: 0.5))),
      ]),
    );
  }

  // ── Bottom Formatting Toolbar (tabbed) ────────────────────────────

  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tab bar
            Container(
              color: AppTheme.surface3,
              child: Row(
                children: [
                  _tabButton('Teks', 0),
                  _tabButton('Paragraf', 1),
                  _tabButton('Sisipkan', 2),
                ],
              ),
            ),
            // Panel content
            if (_activeToolbarTab == 0) _panelTeks(),
            if (_activeToolbarTab == 1) _panelParagraf(),
            if (_activeToolbarTab == 2) _panelSisipkan(),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isActive = _activeToolbarTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeToolbarTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? AppTheme.primary : Colors.transparent, width: 2)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? AppTheme.primary : AppTheme.textMuted)),
          ),
        ),
      ),
    );
  }

  // Panel 1: Teks formatting
  Widget _panelTeks() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              _formatBtn(Icons.format_bold, true),
              _formatBtn(Icons.format_italic, false),
              _formatBtn(Icons.format_underlined, false),
              _formatBtn(Icons.strikethrough_s, false),
              const SizedBox(width: 8),
              _formatBtn(Icons.format_color_text, false),
              _formatBtn(Icons.highlight, false),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.font_download, size: 12, color: AppTheme.textMuted),
                  SizedBox(width: 4),
                  Text('Inter Sans', style: TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('−', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('16 pt', style: TextStyle(fontSize: 11, color: AppTheme.textPrimary))),
                  Text('+', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Panel 2: Paragraf formatting
  Widget _panelParagraf() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _formatBtn(Icons.format_align_left, true),
          _formatBtn(Icons.format_align_center, false),
          _formatBtn(Icons.format_align_right, false),
          const SizedBox(width: 12),
          _formatBtn(Icons.format_list_bulleted, false),
          _formatBtn(Icons.format_list_numbered, false),
        ],
      ),
    );
  }

  // Panel 3: Insert objects
  Widget _panelSisipkan() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _insertOption(Icons.image, 'Gambar', AppTheme.primary),
          _insertOption(Icons.table_chart, 'Tabel', AppTheme.success),
          _insertOption(Icons.link, 'Tautan', AppTheme.tertiary),
          _insertOption(Icons.add_comment, 'Komentar', AppTheme.textMuted),
        ],
      ),
    );
  }

  Widget _formatBtn(IconData icon, bool isActive) {
    return Container(
      width: 36, height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: isActive ? AppTheme.primary : AppTheme.textSecondary),
    );
  }

  Widget _insertOption(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // ── AI FAB Button ─────────────────────────────────────────────────

  Widget _buildAiFab() {
    return GestureDetector(
      onTap: () => setState(() => _aiSheetOpen = !_aiSheetOpen),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text('Keqo AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // ── AI Bottom Sheet ───────────────────────────────────────────────

  Widget _buildAiBottomSheet() {
    return GestureDetector(
      onTap: () {}, // prevent close on tap inside
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
                      gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
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
                            const Text('Keqo AI Assistant',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Word', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: AppTheme.success),
                            SizedBox(width: 4),
                            Text('Siap membantu tulisan Anda', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
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
            // Quick prompt chips
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PROMPT CEPAT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _promptChip('✨', 'Ringkas Teks', () => _sendAiPrompt('Ringkas teks ini', 'ringkas')),
                        const SizedBox(width: 8),
                        _promptChip('📝', 'Perbaiki Tata Bahasa', () => _sendAiPrompt('Perbaiki tata bahasa', 'grammar')),
                        const SizedBox(width: 8),
                        _promptChip('⚡', 'Lanjutkan Tulisan', () => _sendAiPrompt('Lanjutkan tulisan', 'lanjutkan')),
                        const SizedBox(width: 8),
                        _promptChip('🎭', 'Ubah Nada Bicara', () => _sendAiPrompt('Ubah nada bicara', 'ubah-nada')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Chat room: mirror GenOffice's AI replies (user + assistant bubbles)
            Expanded(
              child: _chatMessages.isEmpty && !_aiLoading
                  ? _buildEmptyAiState()
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      itemCount: _chatMessages.length + (_aiLoading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _chatMessages.length) return _buildTypingIndicator();
                        return _buildChatBubble(_chatMessages[i]);
                      },
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
                    IconButton(icon: const Icon(Icons.attach_file, size: 18), color: AppTheme.textMuted, onPressed: () {}),
                    Expanded(
                      child: TextField(
                        controller: _aiInputController,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          border: InputBorder.none, hintText: 'Ketik instruksi atau prompt AI...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted), isDense: true,
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.mic, size: 18), color: AppTheme.textMuted, onPressed: () {}),
                    GestureDetector(
                      onTap: () => _sendAiPrompt(_aiInputController.text.trim(), 'chat'),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.send, size: 16, color: Colors.white),
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

  Widget _promptChip(String emoji, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── AI Document Methods ────────────────────────────────────────────

  /// Send a prompt to GenOffice — GenOffice writes the document, and the
  /// result arrives via the live `document-content` / `document-ai-response` sync.
  Future<void> _sendAiPrompt(String prompt, String action) async {
    if (prompt.isEmpty && action == 'chat') return;
    setState(() {
      _aiLoading = true;
      _chatMessages.add(_ChatMessage(role: 'user', text: prompt));
    });
    _aiInputController.clear();
    _scrollChatToBottom();

    if (_workspaceId != null) {
      try {
        final api = GenOfficeClient();
        api.sendDocumentPrompt(workspaceId: _workspaceId!, prompt: prompt);
      } catch (_) {
        setState(() => _aiLoading = false);
      }
    } else {
      // GenOffice not running — nothing to write to
      setState(() => _aiLoading = false);
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Empty state when the AI sheet has nothing to show.
  Widget _buildEmptyAiState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 32, color: AppTheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          const Text('Ketik instruksi, AI akan menulis dokumen',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  /// A single chat bubble — user messages on the right, assistant on the left.
  Widget _buildChatBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.surface3,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 12),
          ),
          border: isUser ? null : Border.all(color: AppTheme.outline.withValues(alpha: 0.4)),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: isUser ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Typing indicator shown while GenOffice is writing.
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            Text('AI sedang menulis...',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
