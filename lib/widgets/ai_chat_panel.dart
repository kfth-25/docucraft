// DocuCraft — Panel Chat AI (AI Chat Panel)
// Panel chat utama yang terhubung ke LLM (9router) via AiGenerationService
// berbasis SVG. Bisa generate slide, redesign, dan buat presentasi lengkap.
// Mode ThinUI: mendengar event WebSocket GenOffice (outline → style → slide
// → done) lalu menerapkan hasilnya ke canvas + menyimpan chat ke storage.
// @see skills/workflows/ai-generation.md
// @see skills/SKILL.md

/// Connected to 9router LLM via AiGenerationService (SVG-based)
// Can generate slides, redesign, and create full presentations
// @see skills/workflows/ai-generation.md
// @see skills/SKILL.md

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../l10n/app_localizations.dart';
import '../config/endpoints.dart';
import '../models/slide.dart';
import '../models/template_suggestion.dart';
import '../providers/slide_provider.dart';
import '../services/ai_generation.dart';
import '../services/pptx_builder.dart';
import '../services/pptx_import.dart';
import '../services/quality_check.dart';
import '../services/svg_to_slide_elements.dart';
import '../services/storage_service.dart';
import '../themes/app_theme.dart';
import '../widgets/draw_canvas.dart';
// Sprint 12: DocuCraft mode (chat-to-PPT) panel + state machine.
import '../ai/run_state_machine.dart';
import '../providers/ai_run_provider.dart';
import '../services/skill_loader.dart';
// Sprint 14: live agent loop wiring.
import '../agent_core/agent_core.dart' as core;
import 'outline_preview.dart';
import 'slide_options_picker.dart';
import '../services/api_client.dart';
// Sprint 15: Thin UI mode for GenOffice integration
import 'thin_ui_outline_picker.dart';
import 'thin_ui_style_picker.dart';
import 'thin_ui_progress.dart';
import 'slide_options_picker.dart';

/// Mapping dari AiConfig ke UI model tiers
/// Mengambil modelId dari AiConfig agar selalu konsisten
enum AiModelTier {
  fast('Fast', AiConfig.fastModel),
  quality('Quality', AiConfig.qualityModel),
  powerful('Powerful', AiConfig.powerfulModel),
  reasoning('Reasoning', AiConfig.reasoningModel),
  claude('Claude', AiConfig.claudeModel),
  vision('Vision', AiConfig.visionModel);

  final String label;
  final String modelId;
  const AiModelTier(this.label, this.modelId);
}

class AiChatPanel extends StatefulWidget {
  static void show(
    BuildContext context, {
    String? initialPrompt,
    int? currentSlideIndex,
    GlobalKey<DrawCanvasState>? drawCanvasKey,
  }) {
    final isMobile = MediaQuery.of(context).size.height < 700;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: isMobile
          ? BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.95)
          : null,
      builder: (_) => AiChatPanel(
        initialPrompt: initialPrompt,
        currentSlideIndex: currentSlideIndex,
        drawCanvasKey: drawCanvasKey,
      ),
    );
  }

  final String? initialPrompt;
  final int? currentSlideIndex;
  final GlobalKey<DrawCanvasState>? drawCanvasKey;

  const AiChatPanel({
    super.key,
    this.initialPrompt,
    this.currentSlideIndex,
    this.drawCanvasKey,
  });

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final TextEditingController _inputCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _proMode = false; // Pro mode ON → Enter/send runs the normal generate-deck flow
  String _connectionStatus = 'offline';
  AiModelTier _selectedTier = AiModelTier.powerful;

  // Sprint 12: 0 = existing AI Assistant (chat/generate/redesign), 1 = DocuCraft mode
  int _panelModeIndex = 0;
  // Sprint 12: state machine provider for the DocuCraft mode. Created in
  // initState (via ChangeNotifierProvider above the panel) so it persists
  // across tab switches.
  final AiRunProvider _runProvider = AiRunProvider();
  // Sprint 14: cached handle to the slide provider, captured in initState
  // so async callbacks (coordinator hooks) can apply slides without
  // re-reading the BuildContext after it has been disposed.
  SlideProvider? _slideProvider;

  // GenOffice Workspace integration
  GenOfficeClient? _genOfficeClient;
  GenOfficeWebSocket? _genOfficeWs;
  String? _workspaceProjectId;
  String? _genOfficeWorkspaceId; // GenOffice workspace ID (from openWorkspace response)
  bool _workspaceConnected = false;
  bool _workspaceOpened = false; // Track if workspace tab already opened
  List<Map<String, dynamic>> _workspaceSlides = [];
  Map<String, dynamic>? _workspaceStyle;
  // Accumulate AI stream from GenOffice
  final Map<String, StringBuffer> _aiStreamBuffers = {};
  final Map<String, bool> _aiStreamDone = {};
  // Clarify: interactive questionnaire from GenOffice
  String? _activeClarifyRequestId;
  List<Map<String, dynamic>> _activeClarifyQuestions = [];
  final ScrollController _messagesScrollCtrl = ScrollController();

  // Sprint 15: Thin UI mode state
  ThinUiStateManager? _thinUiStateManager;
  ThinUiState _thinUiState = ThinUiState();
  bool _thinUiMode = false; // Enable thin UI when connected to GenOffice
  bool _thinUiSlidesFetched = false; // Guard: fetch slides only once per run

  @override
  void initState() {
    super.initState();
    _checkAiStatus();
    _slideProvider = context.read<SlideProvider>();
    _loadSavedChat();
    _initGenOfficeWorkspace().then((_) {
      // After workspace connection is ready, process initial prompt if any
      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _sendMessage(widget.initialPrompt!);
          }
        });
      }
    });
    // Listen to runProvider state changes for DocuCraft mode streaming output
    _runProvider.addListener(_syncRunStateToMessages);
  }

  /// Initialize thin UI state manager when workspace is connected
  void _initThinUiMode() {
    if (!_workspaceConnected || _genOfficeWs == null) return;

    // Stop previous listener if exists (cleanup before recreating)
    _thinUiStateManager?.stopListening();

    _thinUiStateManager = ThinUiStateManager(_genOfficeWs!);
    _thinUiStateManager!.onStateChange.listen((state) {
      if (mounted) {
        setState(() {
          _thinUiState = state;
          // Add message for stage transitions
          if (state.stage == ThinUiStage.outline && state.outlineOptions.isNotEmpty) {
            _messages.add(_ChatMessage(
              role: 'ai',
              text: '📋 Pilih outline yang kamu suka:',
              time: 'Sekarang',
            ));
          } else if (state.stage == ThinUiStage.style && state.styleOptions.isNotEmpty) {
            _messages.add(_ChatMessage(
              role: 'ai',
              text: '🎨 Pilih style untuk presentasi kamu:',
              time: 'Sekarang',
            ));
          } else if (state.stage == ThinUiStage.slide && state.slideOptions.isNotEmpty) {
            _messages.add(_ChatMessage(
              role: 'ai',
              text: '🖼️ Pilih desain untuk slide ${state.currentSlideIndex! + 1}/${state.totalSlides}:',
              time: 'Sekarang',
            ));
          } else if (state.stage == ThinUiStage.done && !_thinUiSlidesFetched) {
            // Two events can trigger ThinUiStage.done:
            //   1. deck-progress stage='done' — arrives FIRST, has NO slides
            //   2. deck-ready — arrives AFTER PNG export, HAS slides
            // We only act when slides are available (deck-ready).
            if (state.slides == null || state.slides!.isEmpty) {
              debugPrint('🖥️ [ThinUI] deck-progress done received (no slides yet) — waiting for deck-ready...');
            } else {
              _thinUiSlidesFetched = true;
              _messages.add(_ChatMessage(
                role: 'ai',
                text: '✅ Presentasi kamu sudah siap!',
                time: 'Sekarang',
              ));
              // Prefer editable JSON (flat absolute-positioned elements) → parse to
              // SlideElements. Fall back to PNG if no editable structure arrived.
              if (state.editableJson != null && state.editableJson!.isNotEmpty) {
                _applyEditableSlidesToCanvas(state.editableJson!);
              } else if (state.svgs != null && state.svgs!.isNotEmpty) {
                _applySvgSlidesToCanvas(state.svgs!, slideWidth: state.slideWidth, slideHeight: state.slideHeight);
              } else {
                _applyPngSlidesToCanvas(state.slides!, slideWidth: state.slideWidth, slideHeight: state.slideHeight);
              }
              // Dismiss the chat sheet so the user lands directly on the EDITOR canvas,
              // where the slides are applied as editable SlideElements (not the flat PNG
              // viewer). This mirrors GenOffice: the deck shows in the editable canvas,
              // fit-to-screen, not in a full-screen image viewer.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  debugPrint('🖥️ [ThinUI] Deck done — closing chat sheet to reveal editable slides in editor');
                  Navigator.of(context).pop();
                }
              });
              // Keep thin UI mode LISTENING for subsequent generation prompts.
              debugPrint('🖥️ [ThinUI] Deck done — WebSocket stays connected for next prompt');
            }
          } else if (state.stage == ThinUiStage.error) {
            _messages.add(_ChatMessage(
              role: 'ai',
              text: '❌ Error: ${state.error}',
              time: 'Sekarang',
            ));
          }
        });
        _scrollToBottom();
      }
    });
    _thinUiStateManager!.startListening();
    _thinUiMode = true;
    _thinUiSlidesFetched = false; // Reset for new run
    debugPrint('🖥️ [ThinUI] Thin UI mode initialized');
  }

  /// Initialize GenOffice workspace connection
  Future<void> _initGenOfficeWorkspace() async {
    _genOfficeClient = GenOfficeClient();
    try {
      final healthy = await _genOfficeClient!.healthCheck();
      if (healthy && mounted) {
        setState(() {
          _workspaceConnected = true;
          _connectionStatus = 'online';
        });
        debugPrint('🖥️ [Workspace] GenOffice connected');
        // Connect WebSocket for real-time AI stream sync
        _connectGenOfficeWebSocket();
      } else if (mounted) {
        setState(() {
          _workspaceConnected = false;
          _connectionStatus = 'offline';
        });
        debugPrint('🖥️ [Workspace] GenOffice not running - workspace features disabled');
        debugPrint('🖥️ [Workspace] Start GenOffice desktop app to enable workspace sync');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _workspaceConnected = false;
          _connectionStatus = 'offline';
        });
      }
      debugPrint('🖥️ [Workspace] GenOffice connection error: $e');
      debugPrint('🖥️ [Workspace] Make sure GenOffice is running on port 3001');
    }
  }

  /// Connect to GenOffice WebSocket for real-time AI stream sync
  void _connectGenOfficeWebSocket() {
    _genOfficeWs?.dispose();
    _genOfficeWs = GenOfficeWebSocket();
    _genOfficeWs!.onProgress.listen(
      (event) {
        try {
          // GenOffice broadcasts: { stream: 'ai', requestId, type: 'delta'|'done'|'error'|'tool-call', ... }
          if (event['stream'] == 'ai') {
            _handleAiStreamChunk(event);
          }
          // Clarify: interactive questionnaire from GenOffice
          if (event['stream'] == 'clarify' && event['type'] == 'clarify-questions') {
            _handleClarifyQuestions(event);
          }
          // Outline review: editable outline with Cancel/Generate buttons from GenOffice
          if (event['stream'] == 'outline' && event['type'] == 'outline-review') {
            _handleOutlineReview(event);
          }
        } catch (e) {
          debugPrint('🖥️ [Workspace] WebSocket event error: $e');
        }
      },
      onError: (e) {
        debugPrint('🖥️ [Workspace] WebSocket error: $e');
      },
    );
    _genOfficeWs!.connect().then((_) {
      // Initialize thin UI mode after WebSocket connects
      if (mounted) {
        _initThinUiMode();
      }
    }).catchError((e) {
      debugPrint('🖥️ [Workspace] WebSocket connect failed: $e');
    });
  }

  /// Handle clarify questions from GenOffice — show interactive card
  void _handleClarifyQuestions(Map<String, dynamic> event) {
    final requestId = event['requestId']?.toString() ?? '';
    final questionsRaw = event['questions'];
    if (requestId.isEmpty || questionsRaw == null) return;

    final questions = (questionsRaw as List).cast<Map<String, dynamic>>();
    if (questions.isEmpty) return;

    debugPrint('🖥️ [Workspace] Clarify questions received: ${questions.length}');
    setState(() {
      _activeClarifyRequestId = requestId;
      _activeClarifyQuestions = questions;
      _clarifySelections.clear();
      _messages.add(_ChatMessage(
        role: 'ai',
        text: '📋 Pertanyaan klarifikasi — silakan pilih:',
        time: 'Sekarang',
      ));
    });
    _scrollToBottom();
  }

  /// Submit clarify answer back to GenOffice
  void _submitClarifyAnswer({required String answers, bool cancelled = false}) {
    debugPrint('🖥️ [Clarify] Submit answer called: "$answers", cancelled: $cancelled');
    debugPrint('🖥️ [Clarify] _activeClarifyRequestId: $_activeClarifyRequestId');
    debugPrint('🖥️ [Clarify] _genOfficeClient: ${_genOfficeClient != null}');
    if (_activeClarifyRequestId == null || _genOfficeClient == null) {
      debugPrint('🖥️ [Clarify] ❌ Submit ABORTED - requestId or client is null');
      return;
    }
    final requestId = _activeClarifyRequestId!;
    debugPrint('🖥️ [Clarify] Sending answer to GenOffice: requestId=$requestId');
    _genOfficeClient!.sendClarifyAnswer(
      requestId: requestId,
      answers: answers,
      cancelled: cancelled,
    ).then((_) {
      debugPrint('🖥️ [Workspace] Clarify answer sent: "$answers"');
      if (!mounted) return;
      setState(() {
        if (cancelled) {
          _messages.add(_ChatMessage(
            role: 'user',
            text: '⏭️ Melewati pertanyaan',
            time: 'Sekarang',
          ));
        } else {
          _messages.add(_ChatMessage(
            role: 'user',
            text: '✅ $answers',
            time: 'Sekarang',
          ));
        }
        _activeClarifyRequestId = null;
        _activeClarifyQuestions = [];
      });
    }).catchError((e) {
      debugPrint('🖥️ [Workspace] Failed to send clarify answer: $e');
      // Keep card visible on error so user can retry
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim jawaban: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  /// Handle outline review from GenOffice — show editable OutlinePreview with Cancel/Generate
  void _handleOutlineReview(Map<String, dynamic> event) {
    final requestId = event['requestId']?.toString() ?? '';
    final topic = event['topic']?.toString() ?? '';
    final pagesRaw = event['pages'];
    if (requestId.isEmpty || pagesRaw == null || topic.isEmpty) return;

    final pages = (pagesRaw as List)
        .map((e) => OutlinePage.fromJson(e as Map<String, dynamic>))
        .toList();
    if (pages.isEmpty) return;

    debugPrint('🖥️ [Workspace] Outline review received: ${pages.length} pages');
    setState(() {
      _messages.add(_ChatMessage(
        role: 'ai',
        text: '',
        time: 'Sekarang',
        outlinePages: pages,
        outlineTopic: topic,
        outlineRequestId: requestId,
      ));
    });
    _scrollToBottom();
  }

  /// Submit outline review answer back to GenOffice (confirm with edited pages / cancel)
  void _submitOutlineReview(String requestId, List<OutlinePage> pages, bool cancelled) {
    debugPrint('🖥️ [Outline] Submit review: requestId=$requestId, cancelled=$cancelled');
    if (_genOfficeClient == null) {
      debugPrint('🖥️ [Outline] ❌ Submit ABORTED - client is null');
      return;
    }
    final pagesJson = pages.map((p) => p.toJson()).toList();
    _genOfficeClient!.resolveOutlineReview(
      requestId: requestId,
      pages: pagesJson,
      cancelled: cancelled,
    ).then((_) {
      debugPrint('🖥️ [Workspace] Outline review answer sent: $requestId');
      if (!mounted) return;
      setState(() {
        if (cancelled) {
          _messages.add(_ChatMessage(
            role: 'user',
            text: '⏭️ Outline dibatalkan',
            time: 'Sekarang',
          ));
        } else {
          _messages.add(_ChatMessage(
            role: 'user',
            text: '✅ Outline dikonfirmasi (${pages.length} halaman)',
            time: 'Sekarang',
          ));
        }
      });
    }).catchError((e) {
      debugPrint('🖥️ [Workspace] Failed to send outline review answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim jawaban: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  /// Handle AI stream chunk from GenOffice WebSocket
  /// Event shape: { stream: 'ai', requestId, type: 'delta'|'done'|'error'|'tool-call', text?, error?, toolCall? }
  void _handleAiStreamChunk(Map<String, dynamic> event) {
    final requestId = event['requestId']?.toString() ?? '';
    final chunkType = event['type']?.toString() ?? '';
    final text = event['text']?.toString() ?? '';

    if (requestId.isEmpty) return;

    // Initialize buffer for this request
    _aiStreamBuffers.putIfAbsent(requestId, () => StringBuffer());

    if (chunkType == 'error' || event['error'] != null) {
      // Error from GenOffice AI
      final errorMsg = event['error']?.toString() ?? 'Unknown error';
      debugPrint('🖥️ [Workspace] AI error: $errorMsg');
      _aiStreamDone[requestId] = true;
      _flushAiStreamMessage(requestId, '❌ Error: $errorMsg');
    } else if (chunkType == 'delta' && text.isNotEmpty) {
      // Text chunk — accumulate
      _aiStreamBuffers[requestId]!.write(text);
    } else if (chunkType == 'tool-call') {
      // Tool call from GenOffice AI (e.g. generate-slide, outline tools)
      final toolName = event['toolCall']?['name']?.toString() ?? '';
      debugPrint('🖥️ [Workspace] AI tool call: $toolName');
      if (toolName.isNotEmpty) {
        _aiStreamBuffers[requestId]!.write('\n🔧 [$toolName]\n');
      }
    } else if (chunkType == 'done') {
      // Stream complete — flush to chat
      _aiStreamDone[requestId] = true;
      _flushAiStreamMessage(requestId);
    }
    // Ignore 'reasoning', 'ping', and other chunk types
  }

  /// Flush accumulated AI stream text to chat
  void _flushAiStreamMessage(String requestId, [String? overrideText]) {
    final buffer = _aiStreamBuffers.remove(requestId);
    _aiStreamDone.remove(requestId);
    final text = overrideText ?? buffer?.toString() ?? '';

    if (text.isEmpty || !mounted) return;

    setState(() {
      // Replace the "AI sedang memproses" message with actual response
      final processingIdx = _messages.lastIndexWhere(
        (m) => m.role == 'ai' && m.text.contains('AI sedang'),
      );
      if (processingIdx >= 0) {
        _messages[processingIdx] = _ChatMessage(
          role: 'ai',
          text: text,
          time: 'Sekarang',
        );
      } else {
        _messages.add(_ChatMessage(role: 'ai', text: text, time: 'Sekarang'));
      }
    });

    // Cleanup old buffers (keep max 10)
    if (_aiStreamBuffers.length > 10) {
      final oldest = _aiStreamBuffers.keys.first;
      _aiStreamBuffers.remove(oldest);
      _aiStreamDone.remove(oldest);
    }
  }

  /// Retry connecting to GenOffice workspace
  Future<void> _retryWorkspaceConnection() async {
    setState(() {
      _connectionStatus = 'connecting';
    });
    await _initGenOfficeWorkspace();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _workspaceConnected
                ? '✅ Terhubung! Fitur workspace aktif.'
                : '❌ Aplikasi desktop tidak ditemukan. Jalankan dulu.',
          ),
          backgroundColor: _workspaceConnected ? AppTheme.success : AppTheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Create workspace project and open GenOffice slides tab when run starts
  Future<void> _initWorkspaceProject(String topic) async {
    if (!_workspaceConnected || _genOfficeClient == null) return;
    if (_workspaceOpened) return; // Already opened, skip

    _workspaceProjectId = 'docucraft-${DateTime.now().millisecondsSinceEpoch}';
    try {
      // Initialize project context on GenOffice server
      await _genOfficeClient!.initProject(
        projectId: _workspaceProjectId!,
        topic: topic,
      );
      debugPrint('🖥️ [Workspace] Project created: $_workspaceProjectId');

      // Open a new slides workspace tab in GenOffice Electron
      final wsResult = await _genOfficeClient!.openWorkspace(
        projectId: _workspaceProjectId,
      );
      _genOfficeWorkspaceId = wsResult['workspaceId'] as String?;
      final genOfficeTabId = wsResult['tabId'] as String?;
      _workspaceOpened = true;
      debugPrint('🖥️ [Workspace] GenOffice tab opened: $genOfficeTabId (workspace: $_genOfficeWorkspaceId)');

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('🖥️ [Workspace] Failed to init/open workspace: $e');
    }
  }

  /// Forward user prompt to GenOffice workspace AI panel (fire-and-forget)
  void _forwardPromptToGenOffice(String prompt) {
    if (!_workspaceConnected || _genOfficeWorkspaceId == null || _genOfficeClient == null) return;
    // Fire-and-forget: don't block Flutter UI, GenOffice processes independently
    // Pass the currently selected model so GenOffice uses the same AI
    _genOfficeClient!.sendPromptToWorkspace(
      workspaceId: _genOfficeWorkspaceId!,
      prompt: prompt,
      model: _selectedTier.modelId,
      pro: _proMode,
    ).then((_) {
      debugPrint('🖥️ [Workspace] Prompt forwarded to GenOffice: "${prompt.length > 50 ? prompt.substring(0, 50) + '...' : prompt}" (model: ${_selectedTier.modelId})');
    }).catchError((e) {
      debugPrint('🖥️ [Workspace] Failed to forward prompt: $e');
    });
  }

  /// Sync outline to workspace
  Future<void> _syncOutlineToWorkspace(List<OutlinePage> pages) async {
    if (!_workspaceConnected || _workspaceProjectId == null || _genOfficeClient == null) return;

    try {
      final outline = pages.map((p) => {
        'index': p.index,
        'title': p.title,
        'brief': p.brief,
      }).toList();

      await _genOfficeClient!.updateProject(
        projectId: _workspaceProjectId!,
        outline: outline,
      );
      debugPrint('🖥️ [Workspace] Outline synced: ${pages.length} pages');
    } catch (e) {
      debugPrint('🖥️ [Workspace] Failed to sync outline: $e');
    }
  }

  /// Convert Slide to simple SVG representation for workspace sync
  String _slideToSvg(Slide slide) {
    final buffer = StringBuffer();
    buffer.writeln('<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">');

    // Background
    buffer.writeln('<rect width="1920" height="1080" fill="#f8f9fa"/>');

    // Title
    buffer.writeln('<text x="100" y="100" font-size="48" font-weight="bold" fill="#1a1a1a">${_escapeXml(slide.title)}</text>');

    // Subtitle
    if (slide.subtitle.isNotEmpty) {
      buffer.writeln('<text x="100" y="160" font-size="24" fill="#666666">${_escapeXml(slide.subtitle)}</text>');
    }

    // Elements (simplified rendering)
    for (final element in slide.elements) {
      switch (element.type) {
        case ElementType.text:
          final text = element.content ?? '';
          final fontSize = element.textStyle?.fontSize ?? 16;
          final color = element.color ?? '#333333';
          buffer.writeln('<text x="${element.x}" y="${element.y + fontSize}" font-size="$fontSize" fill="$color">${_escapeXml(text)}</text>');
          break;
        case ElementType.shape:
          final fillColor = element.shapeStyle != null
              ? '#${element.shapeStyle!.fillColorValue.toRadixString(16).padLeft(6, '0').substring(2)}'
              : '#6366F1';
          buffer.writeln('<rect x="${element.x}" y="${element.y}" width="${element.width}" height="${element.height}" fill="$fillColor" rx="8"/>');
          break;
        case ElementType.image:
          buffer.writeln('<rect x="${element.x}" y="${element.y}" width="${element.width}" height="${element.height}" fill="#e0e0e0" rx="8"/>');
          buffer.writeln('<text x="${element.x + element.width / 2}" y="${element.y + element.height / 2}" text-anchor="middle" font-size="14" fill="#999">Image</text>');
          break;
        default:
          break;
      }
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Escape XML special characters
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ── Thin UI Selection Handlers ──

  void _handleThinUiOutlineSelected(ThinUiOutlineOption outline) {
    if (_genOfficeClient == null || _thinUiState.workspaceId == null) return;

    debugPrint('🖥️ [ThinUI] Outline selected: ${outline.title}');
    _genOfficeClient!.selectOutline(
      workspaceId: _thinUiState.workspaceId!,
      outlineId: outline.id,
    ).then((_) {
      setState(() {
        _messages.add(_ChatMessage(
          role: 'user',
          text: 'Outline: ${outline.title} (${outline.slides} slides)',
          time: 'Sekarang',
        ));
      });
      _scrollToBottom();
    }).catchError((e) {
      debugPrint('🖥️ [ThinUI] Failed to select outline: $e');
    });
  }

  void _handleThinUiStyleSelected(ThinUiStyleOption style) {
    if (_genOfficeClient == null || _thinUiState.workspaceId == null) return;

    debugPrint('🖥️ [ThinUI] Style selected: ${style.name}');
    _genOfficeClient!.selectStyle(
      workspaceId: _thinUiState.workspaceId!,
      styleId: style.id,
    ).then((_) {
      setState(() {
        _messages.add(_ChatMessage(
          role: 'user',
          text: 'Style: ${style.name}',
          time: 'Sekarang',
        ));
      });
      _scrollToBottom();
    }).catchError((e) {
      debugPrint('🖥️ [ThinUI] Failed to select style: $e');
    });
  }

  void _handleThinUiSlideSelected(ThinUiSlideOption option) {
    if (_genOfficeClient == null || _thinUiState.workspaceId == null) return;
    if (_thinUiState.currentSlideIndex == null) return;

    debugPrint('🖥️ [ThinUI] Slide option selected: ${option.style}');
    _genOfficeClient!.selectSlideOption(
      workspaceId: _thinUiState.workspaceId!,
      slideIndex: _thinUiState.currentSlideIndex!,
      optionId: option.id,
    ).then((_) {
      setState(() {
        _messages.add(_ChatMessage(
          role: 'user',
          text: 'Slide ${_thinUiState.currentSlideIndex! + 1}: ${option.style}',
          time: 'Sekarang',
        ));
      });
      _scrollToBottom();
    }).catchError((e) {
      debugPrint('🖥️ [ThinUI] Failed to select slide option: $e');
    });
  }

  void _startThinUiRun(String topic) {
    if (_genOfficeClient == null) return;

    _initWorkspaceProject(topic).then((_) {
      if (_genOfficeWorkspaceId == null) {
        if (mounted) {
          setState(() {
            _messages.add(_ChatMessage(
              role: 'ai',
              text: '❌ Gagal membuka workspace. Pastikan aplikasi desktop sedang berjalan.',
              time: 'Sekarang',
            ));
          });
          _scrollToBottom();
        }
        return;
      }

      _genOfficeClient!.startThinUiRun(
        workspaceId: _genOfficeWorkspaceId!,
        topic: topic,
        slideCount: 5,
        styleHint: 'modern, clean',
        model: _selectedTier.modelId,
      ).then((_) {
        debugPrint('🖥️ [ThinUI] Run started for topic: $topic (model: ${_selectedTier.modelId})');
        // Re-initialize Thin UI mode to listen for new run's events
        if (mounted) {
          _initThinUiMode();
        }
      }).catchError((e) {
        debugPrint('🖥️ [ThinUI] Failed to start run: $e');
        if (mounted) {
          setState(() {
            _messages.add(_ChatMessage(
              role: 'ai',
              text: '❌ Gagal memulai generasi: $e',
              time: 'Sekarang',
            ));
          });
          _scrollToBottom();
        }
      });
    });
  }

  /// Apply PNG base64 slides (from deck-ready WebSocket) to the Flutter canvas.
  /// The Flutter canvas is a fixed 1920×1080 design space, so each PNG (16:9)
  /// becomes a full-bleed image element covering the entire canvas.
  void _applyPngSlidesToCanvas(List<String> pngBase64Slides, {int? slideWidth, int? slideHeight}) {
    if (pngBase64Slides.isEmpty) return;
    if (_slideProvider == null) {
      debugPrint('⚠️ [ThinUI] _slideProvider is null — cannot apply PNG slides');
      return;
    }

    final slides = <Slide>[];
    for (int i = 0; i < pngBase64Slides.length; i++) {
      final b64 = pngBase64Slides[i];
      final dataUri = b64.contains(',') ? b64 : 'data:image/png;base64,$b64';

      final imageElement = SlideElement(
        id: 'png_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: ElementType.image,
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
        imageStyle: ImageStyleData(src: dataUri),
      );

      slides.add(Slide(
        id: 'ws_slide_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: 'Slide ${i + 1}',
        layoutId: 'blank',
        backgroundGradient: 'clean-white',
        elements: [imageElement],
      ));
    }

    _slideProvider!.applyAiResult(slides, replaceAll: true);
    debugPrint('✅ [ThinUI] Applied ${slides.length} PNG slides to canvas (1920×1080 full-bleed)');
  }

  /// Apply SVG slides (editable structure from GenOffice) to the Flutter canvas.
  /// Each SVG is parsed into editable SlideElements (text/shapes/images), so the
  /// user can edit it manually like a native slide — not a flat PNG image.
  void _applySvgSlidesToCanvas(List<String> svgSlides, {int? slideWidth, int? slideHeight}) {
    if (svgSlides.isEmpty) return;
    if (_slideProvider == null) {
      debugPrint('⚠️ [ThinUI] _slideProvider is null — cannot apply SVG slides');
      return;
    }

    final srcW = slideWidth ?? _thinUiState.slideWidth ?? 1280;
    final srcH = slideHeight ?? _thinUiState.slideHeight ?? 720;

    final slides = <Slide>[];
    int parsedCount = 0;
    for (int i = 0; i < svgSlides.length; i++) {
      final svg = svgSlides[i];
      if (svg.isEmpty) continue;

      final elements = SvgToSlideElements.parse(
        svg,
        sourceCanvasWidth: srcW,
        sourceCanvasHeight: srcH,
        targetCanvasWidth: 1920,
        targetCanvasHeight: 1080,
      );

      if (elements.isEmpty) continue;

      slides.add(Slide(
        id: 'ws_slide_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: 'Slide ${i + 1}',
        layoutId: 'blank',
        backgroundGradient: 'clean-white',
        elements: elements,
      ));
      parsedCount++;
    }

    if (slides.isEmpty) {
      debugPrint('⚠️ [ThinUI] No SVG slides parsed — falling back to PNG');
      if (_thinUiState.slides != null && _thinUiState.slides!.isNotEmpty) {
        _applyPngSlidesToCanvas(_thinUiState.slides!, slideWidth: slideWidth, slideHeight: slideHeight);
      }
      return;
    }

    _slideProvider!.applyAiResult(slides, replaceAll: true);
    debugPrint('✅ [ThinUI] Applied $parsedCount editable SVG slides to canvas (parsed to SlideElements)');
  }

  /// Apply GenOffice's editable-structure JSON to the Flutter canvas.
  /// Each JSON string is a flat list of absolute-positioned text/shape/image
  /// elements with its own source dimensions — parsed 1:1 into editable
  /// SlideElements (no nested SVG transform groups, no flat PNG fallback).
  void _applyEditableSlidesToCanvas(List<String> editableJsonSlides) {
    if (editableJsonSlides.isEmpty) return;
    if (_slideProvider == null) {
      debugPrint('⚠️ [ThinUI] _slideProvider is null — cannot apply editable slides');
      return;
    }

    final slides = <Slide>[];
    int parsedCount = 0;
    for (int i = 0; i < editableJsonSlides.length; i++) {
      final json = editableJsonSlides[i];
      if (json.isEmpty) continue;

      final elements = SvgToSlideElements.parseEditableJson(json);
      if (elements.isEmpty) continue;

      // Preserve GenOffice's actual background (solid/gradient) instead of a
      // hardcoded white — otherwise dark decks render on a white canvas.
      final backgroundGradient =
          SvgToSlideElements.parseBackgroundGradient(json) ?? 'clean-white';

      slides.add(Slide(
        id: 'ws_slide_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: 'Slide ${i + 1}',
        layoutId: 'blank',
        backgroundGradient: backgroundGradient,
        elements: elements,
      ));
      parsedCount++;
    }

    if (slides.isEmpty) {
      debugPrint('⚠️ [ThinUI] No editable JSON parsed — falling back to PNG');
      if (_thinUiState.slides != null && _thinUiState.slides!.isNotEmpty) {
        _applyPngSlidesToCanvas(_thinUiState.slides!, slideWidth: _thinUiState.slideWidth, slideHeight: _thinUiState.slideHeight);
      }
      return;
    }

    _slideProvider!.applyAiResult(slides, replaceAll: true);
    _persistChat();
    debugPrint('✅ [ThinUI] Applied $parsedCount editable JSON slides to canvas (flat SlideElements)');
  }

  void _handleThinUiDownload() async {
    if (_thinUiState.pptxUrl == null) return;
    final pptxUrl = _thinUiState.pptxUrl!;
    final fullUrl = '${Endpoints.backend}$pptxUrl';
    debugPrint('🖥️ [ThinUI] Download PPTX: $fullUrl');

    try {
      // Show downloading status
      setState(() {
        _messages.add(_ChatMessage(
          role: 'ai',
          text: '⬇️ Downloading PPTX...',
          time: 'Sekarang',
        ));
      });

      // Download PPTX bytes from GenOffice server
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      // Save to app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final filename = pptxUrl.split('/').last;
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      debugPrint('🖥️ [ThinUI] PPTX saved: ${file.path} (${response.bodyBytes.length} bytes)');

      // Import PPTX into whiteboard (replaceAll: true — new presentation replaces existing slides)
      final importResult = PptxImporter.fromBytes(response.bodyBytes);
      if (importResult != null && importResult.slides.isNotEmpty && _slideProvider != null) {
        _slideProvider!.applyAiResult(importResult.slides, replaceAll: true);
        debugPrint('🖥️ [ThinUI] Imported ${importResult.slides.length} slides into whiteboard');
      }

      // Show success message with file path
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: '✅ PPTX downloaded & imported!\n📁 ${file.path}\n📊 Size: ${(response.bodyBytes.length / 1024).toStringAsFixed(1)} KB\n🎨 ${importResult?.slides.length ?? 0} slides added to whiteboard',
            time: 'Sekarang',
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('🖥️ [ThinUI] Download error: $e');
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: '❌ Download failed: $e',
            time: 'Sekarang',
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _handleThinUiNewChat() {
    _thinUiStateManager?.reset();
    setState(() {
      _thinUiState = ThinUiState();
      _messages.clear();
    });
  }

  /// Sync slide to workspace when it lands
  Future<void> _syncSlideToWorkspace(int index, String title, String svg, String style) async {
    if (!_workspaceConnected || _workspaceProjectId == null || _genOfficeClient == null) return;

    try {
      await _genOfficeClient!.addSlideToProject(
        projectId: _workspaceProjectId!,
        slide: {
          'index': index,
          'title': title,
          'svg': svg,
          'style': style,
        },
      );
      // Update local cache: replace existing or add new
      final existingIdx = _workspaceSlides.indexWhere((s) => s['index'] == index);
      if (existingIdx >= 0) {
        _workspaceSlides[existingIdx] = {'index': index, 'title': title, 'svg': svg, 'style': style};
      } else {
        _workspaceSlides.add({'index': index, 'title': title, 'svg': svg, 'style': style});
      }
      debugPrint('🖥️ [Workspace] Slide synced: $index - $title');
    } catch (e) {
      debugPrint('🖥️ [Workspace] Failed to sync slide: $e');
    }
  }

  /// Refine slide with user feedback via workspace
  Future<String?> _refineSlideViaWorkspace(int slideIndex, String currentSvg, String feedback) async {
    if (!_workspaceConnected || _workspaceProjectId == null || _genOfficeClient == null) return null;

    try {
      final refinedSvg = await _genOfficeClient!.refineSlide(
        projectId: _workspaceProjectId!,
        slideIndex: slideIndex,
        svg: currentSvg,
        feedback: feedback,
      );
      debugPrint('🖥️ [Workspace] Slide refined: $slideIndex');
      return refinedSvg;
    } catch (e) {
      debugPrint('🖥️ [Workspace] Failed to refine slide: $e');
      return null;
    }
  }

  /// Regenerate slide via workspace
  Future<String?> _regenerateSlideViaWorkspace(int slideIndex) async {
    if (!_workspaceConnected || _workspaceProjectId == null || _genOfficeClient == null) return null;

    try {
      final newSvg = await _genOfficeClient!.regenerateSlide(
        projectId: _workspaceProjectId!,
        slideIndex: slideIndex,
      );
      debugPrint('🖥️ [Workspace] Slide regenerated: $slideIndex');
      return newSvg;
    } catch (e) {
      debugPrint('🖥️ [Workspace] Failed to regenerate slide: $e');
      return null;
    }
  }

  /// Persist the current chat history to local storage, keyed by the active
  /// project/workspace ID, so the conversation survives the modal sheet closing.
  void _persistChat() {
    final projectId = _slideProvider?.currentProjectId;
    if (projectId == null || _messages.isEmpty) return;
    StorageService.saveChatSession(
      projectId,
      _messages.map((m) => m.toJson()).toList(),
    );
  }

  /// Restore a previously persisted chat history for the active project.
  void _loadSavedChat() {
    final projectId = _slideProvider?.currentProjectId;
    if (projectId == null) return;
    final saved = StorageService.loadChatSession(projectId);
    if (saved.isEmpty) return;
    _messages
      ..clear()
      ..addAll(saved.map(_ChatMessage.fromJson));
  }

  @override
  void dispose() {
    _persistChat();
    _genOfficeWs?.dispose();
    _thinUiStateManager?.dispose();
    _clarifySelections.clear();
    _messagesScrollCtrl.dispose();
    _inputCtrl.dispose();
    _runProvider.removeListener(_syncRunStateToMessages);
    _runProvider.dispose();
    super.dispose();
  }

  /// Sync runProvider state to chat messages for streaming AI output
  /// (mirrors GenOffice's patchLastAssistant + patchProgressInLastAssistant)
  void _syncRunStateToMessages() {
    if (_panelModeIndex != 1) return; // Only in DocuCraft mode

    final state = _runProvider.state;
    final snapshot = _runProvider.snapshot;
    final isBusy = _runProvider.isBusy;

    // Don't process if not in a relevant state
    if (state is! RunStreaming && state is! RunStarting && state is! RunError && state is! RunDone && state is! RunIdle && state is! RunAwaitingOutlineReview) {
      return;
    }

    setState(() {
      // Ensure we have an AI message slot for streaming
      int aiMsgIndex = -1;
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == 'ai' && (_messages[i].streaming || _messages[i].tools.any((t) => t.running))) {
          aiMsgIndex = i;
          break;
        }
      }

      // Build tool activities from snapshot (with full output like GenOffice)
      final tools = snapshot.runTools.map((t) => _ToolActivity(
        name: t.name,
        summary: t.summary.isNotEmpty ? t.summary : t.name.replaceAll('_', ' '),
        running: t.running,
        isError: t.isError,
        output: t.output,
      )).toList();

      // Build deck progress from snapshot.docucraftMeta
      _DeckProgress? deckProgress;
      final meta = snapshot.docucraftMeta;
      if (meta != null) {
        final style = meta.style;
        final plan = meta.plan;
        final pages = meta.pages;
        final isAllDone = meta.isDone || state is RunDone;

        deckProgress = _DeckProgress(
          styleLabel: style?.label,
          styleStatus: style?.status ?? (isAllDone ? 'done' : 'running'),
          planLabel: plan?.summary ?? plan?.label,
          planDone: plan?.done ?? 0,
          planTotal: plan?.total ?? 1,
          planStatus: plan?.status ?? (isAllDone ? 'done' : 'running'),
          pagesLabel: pages?.label,
          pagesDone: pages?.done ?? 0,
          pagesTotal: pages?.total ?? meta.pageCount ?? 0,
          pagesStatus: pages?.status ?? (isAllDone ? 'done' : 'running'),
          pages: pages?.items?.map((p) => _PageProgress(
            title: p.title,
            status: _ProgressStatus.values.byName(p.status.name),
            error: p.error,
          )).toList(),
          isDone: isAllDone,
        );
      }

      // Create or update the streaming AI message
      if (state is RunStarting) {
        // Add a new streaming message — empty, AI output fills it in.
        // If tools are already present (AI called tool without text first),
        // update immediately so the UI shows tool activity instead of just spinning.
        if (aiMsgIndex == -1) {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: snapshot.streamedText,
            time: 'Sekarang',
            streaming: true,
            tools: tools,
            deckProgress: deckProgress,
          ));
        } else if (tools.isNotEmpty) {
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            text: snapshot.streamedText,
            tools: tools,
            deckProgress: deckProgress,
          );
        }
      } else if (state is RunStreaming) {
        if (aiMsgIndex >= 0 && aiMsgIndex < _messages.length) {
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            text: snapshot.streamedText,
            streaming: true,
            tools: tools,
            deckProgress: deckProgress,
            error: null,
          );
        } else {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: snapshot.streamedText,
            time: 'Sekarang',
            streaming: true,
            tools: tools,
            deckProgress: deckProgress,
          ));
        }
      } else if (state is RunError) {
        // Replace the last streaming message with error
        if (aiMsgIndex >= 0 && aiMsgIndex < _messages.length) {
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            text: snapshot.streamedText.isNotEmpty ? snapshot.streamedText : '',
            streaming: false,
            error: state.message,
            tools: _messages[aiMsgIndex].tools.map((t) => t.copyWith(running: false)).toList(),
          );
        } else {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: '',
            time: 'Sekarang',
            streaming: false,
            error: state.message,
          ));
        }
      } else if (state is RunDone) {
        // Run finished — finalize the streaming message
        if (aiMsgIndex >= 0 && aiMsgIndex < _messages.length) {
          final finalizedTools = _messages[aiMsgIndex].tools.map((t) => t.copyWith(running: false)).toList();
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            text: snapshot.streamedText,
            streaming: false,
            tools: finalizedTools,
            deckProgress: deckProgress,
          );
        } else if (snapshot.streamedText.isNotEmpty || tools.isNotEmpty) {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: snapshot.streamedText,
            time: 'Sekarang',
            streaming: false,
            tools: tools,
            deckProgress: deckProgress,
          ));
        }
      } else if (state is RunAwaitingOutlineReview) {
        // Outline is ready for user review — add an editable outline preview message
        // Check if we already have an outline review message
        final existingOutlineIdx = _messages.indexWhere(
          (m) => m.role == 'ai' && m.outlinePages != null,
        );
        if (existingOutlineIdx == -1) {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: snapshot.streamedText.isNotEmpty ? snapshot.streamedText : '',
            time: 'Sekarang',
            streaming: false,
            outlinePages: state.pages,
            outlineTopic: state.topic,
            planSummary: state.planSummary,
          ));
        }
      } else if (state is RunIdle && (_runProvider.snapshot.lastInstruction?.isNotEmpty ?? false) && !isBusy) {
        // Run completed — finalize the last message if it was streaming
        if (aiMsgIndex >= 0 && aiMsgIndex < _messages.length) {
          final finalizedTools = _messages[aiMsgIndex].tools.map((t) => t.copyWith(running: false)).toList();
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            text: snapshot.streamedText.isNotEmpty ? snapshot.streamedText : _messages[aiMsgIndex].text,
            streaming: false,
            tools: finalizedTools,
            deckProgress: deckProgress,
          );
        }
      }
    });
  }

  Future<void> _checkAiStatus() async {
    if (mounted) {
      setState(() {
        _connectionStatus = 'online';
      });
      final l = AppLocalizations.of(context);
      _messages.add(_ChatMessage(
        role: 'ai',
        text: l.aiChatGreeting,
        time: 'Baru saja',
      ));
      return;
    }
  }

  Future<String> _convertSketch(String userPrompt, SlideProvider provider) async {
    final l = AppLocalizations.of(context);
    final key = widget.drawCanvasKey;
    if (key == null) {
      return l.aiSketchNoCanvas;
    }
    final state = key.currentState;
    if (state == null || state.strokes.isEmpty) {
      return l.aiSketchCanvasEmpty;
    }

    // Analisis bounds coretan
    double minX = double.infinity, minY = double.infinity;
    double maxX = 0, maxY = 0;
    for (final stroke in state.strokes) {
      for (final point in stroke.points) {
        if (point[0] < minX) minX = point[0];
        if (point[1] < minY) minY = point[1];
        if (point[0] > maxX) maxX = point[0];
        if (point[1] > maxY) maxY = point[1];
      }
    }
    if (minX == double.infinity) minX = 0;
    if (minY == double.infinity) minY = 0;

    final sketchBounds = {
      'minX': minX,
      'minY': minY,
      'maxX': maxX,
      'maxY': maxY,
      'width': maxX - minX,
      'height': maxY - minY,
      'centerX': (minX + maxX) / 2,
      'centerY': (minY + maxY) / 2,
      'strokeCount': state.strokes.length,
    };

    setState(() {
      _isGenerating = true;
      _messages.add(_ChatMessage(
        role: 'ai',
        text: l.aiSketchAnalyzing,
        time: 'Sekarang',
      ));
    });

    const canvasWidth = 1920;
    const canvasHeight = 1080;

    try {
      // Primary: vision AI (lihat gambar coretan) → SVG
      final pngBytes = await state.captureToImage();
      if (pngBytes != null && pngBytes.isNotEmpty) {
        final currentSlide = provider.currentSlide;
        final result = await AiGenerationService.sketchToDesignSvg(
          pngBytes,
          userPrompt,
          currentSlide: currentSlide,
          model: _selectedTier.modelId,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          sketchBounds: sketchBounds,
        );

        // Cek apakah AI balas dengan pertanyaan
        if (!result.success && result.error != null && result.error!.contains('PERTANYAAN:')) {
          return result.error!.replaceAll('PERTANYAAN:', '').trim();
        }

        if (result.success && result.svg != null && result.svg!.isNotEmpty) {
          final elements = SvgToSlideElements.parse(
            result.svg!,
            sourceCanvasWidth: canvasWidth,
            sourceCanvasHeight: canvasHeight,
          );
          if (elements.isNotEmpty) {
            final currentSlide = provider.currentSlide;
            if (currentSlide != null) {
              currentSlide.elements.addAll(elements);
              provider.notify();
            }
            state.clearAll();
            final textCount = elements.where((e) => e.type == ElementType.text).length;
            final shapeCount = elements.where((e) => e.type == ElementType.shape).length;
            final imageCount = elements.where((e) => e.type == ElementType.image).length;
            return l.aiDesignSuccess(elements.length, textCount, shapeCount, imageCount);
          }
        }
      }

      // Fallback: data stroke → SVG
      final sketchData = state.getStrokesAsJson();
      final fallbackResult = await AiGenerationService.generateFromSketchSvg(
        sketchData,
        userPrompt,
        currentSlide: provider.currentSlide,
        model: _selectedTier.modelId,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );

      if (fallbackResult.success && fallbackResult.svg != null && fallbackResult.svg!.isNotEmpty) {
        final elements = SvgToSlideElements.parse(
          fallbackResult.svg!,
          sourceCanvasWidth: canvasWidth,
          sourceCanvasHeight: canvasHeight,
        );
        if (elements.isNotEmpty) {
          final currentSlide = provider.currentSlide;
          if (currentSlide != null) {
            currentSlide.elements.addAll(elements);
            provider.notify();
          }
          state.clearAll();
          return '${l.aiSketchConvertSuccessFallback}${elements.length} elemen ditambahkan.';
        }
      }

      return l.aiSketchConvertFailed(fallbackResult.error ?? l.aiNoResult);
    } catch (e) {
      return l.aiGenericError(e.toString());
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  /// Build conversation history untuk konteks AI
  String _buildConversationContext() {
    if (_messages.isEmpty) return '';

    final sb = StringBuffer();
    sb.writeln('RIWAYAT PERCAKAPAN:');
    sb.writeln('');

    // Ambil 10 pesan terakhir untuk konteks
    final recentMessages = _messages.length > 10 ? _messages.sublist(_messages.length - 10) : _messages;

    for (final msg in recentMessages) {
      if (msg.role == 'user') {
        sb.writeln('User: ${msg.text}');
      } else {
        // Truncate response AI yang panjang (SVG/error)
        String aiText = msg.text;
        if (aiText.length > 200) {
          aiText = '${aiText.substring(0, 200)}...';
        }
        sb.writeln('AI: $aiText');
      }
    }

    sb.writeln('');
    sb.writeln('INSTRUKSI TERBARU DARI USER:');
    return sb.toString();
  }

  /// Proses prompt user - interaktif seperti Claude Code
  /// AI yang tentukan apakah prompt ambigu atau tidak
  Future<String> _processPrompt(String prompt) async {
    final l = AppLocalizations.of(context);
    final provider = context.read<SlideProvider>();
    final lower = prompt.toLowerCase();

    // 1. Jika ada coret - gunakan AI Coret
    if (lower.contains('coret') || lower.contains('sketch') || lower.contains('sketsa') || lower.contains('convert')) {
      return await _convertSketch(prompt, provider);
    }

    // 2. Generate slide options if user requests multiple designs
    if (lower.contains('options') || lower.contains('variations') || lower.contains('pilihan') || lower.contains(' variasi')) {
      // Extract title from prompt (look for quotes or after "for/about/tentang")
      String? title;
      String? topic;

      // Try to extract quoted text
      final quoteMatch = RegExp(r'"([^"]+)"').firstMatch(prompt);
      if (quoteMatch != null) {
        title = quoteMatch.group(1);
        topic = prompt.replaceAll(quoteMatch.group(0)!, '').trim();
      } else {
        // Try to extract after keywords
        final forMatch = RegExp(r'(?:for|about|tentang|judul)\s+(.+?)(?:\s*$)', caseSensitive: false).firstMatch(prompt);
        if (forMatch != null) {
          title = forMatch.group(1)?.trim();
          topic = prompt.replaceAll(forMatch.group(0)!, '').trim();
        } else {
          // Use the whole prompt as topic and generate a title
          topic = prompt;
          title = prompt;
        }
      }

      if (title != null && topic != null) {
        // Generate options asynchronously and add to messages
        _generateSlideOptions(topic, title);
        return ''; // Return empty since _generateSlideOptions handles messages
      }
    }

    // 3. Template suggestions (hanya di pesan pertama)
    if (_messages.isEmpty) {
      final suggestions = TemplateSuggestions.suggest(prompt);
      if (suggestions.isNotEmpty) {
        final suggestionText = suggestions.take(3).map((s) =>
          '• **${s.name}** - ${s.description}'
        ).join('\n');

        return 'Berdasarkan prompt Anda, template yang cocok:\n'
            '$suggestionText\n\n'
            'Pilih template atau berikan detail lebih lanjut '
            '(mis: "Tech Modern warna biru").';
      }
    }

    // 3. Lightweight Gate - Ringkasan pemahaman AI (hanya di pesan pertama)
    if (_messages.isEmpty && prompt.length > 10) {
      final lower = prompt.toLowerCase();
      final hasColor = ['warna', 'biru', 'merah', 'hijau', 'kuning', 'ungu', 'pink', 'orange', 'hitam', 'putih', 'indigo'].any((c) => lower.contains(c));
      final hasStyle = ['style', 'modern', 'minimalis', 'corporate', 'friendly', 'elegan', 'casual', 'romantis', 'clean', 'futuristik'].any((s) => lower.contains(s));

      // Jika prompt sudah detail (ada warna + style), skip gate
      if (!hasColor || !hasStyle) {
        return l.aiDesignGateIntro(
          prompt.length > 50 ? '${prompt.substring(0, 50)}...' : prompt,
          hasColor ? 'sesuai permintaan' : 'default (indigo, pink, putih)',
          hasStyle ? 'sesuai permintaan' : 'modern profesional',
        );
      }
    }

    // 5. Build conversation context
    final conversationContext = _buildConversationContext();

    // 6. Kirim ke AI dengan konteks percakapan
    final result = await AiGenerationService.generateFromPrompt(
      '$conversationContext$prompt',
      currentSlide: provider.currentSlide,
      model: _selectedTier.modelId,
    );

    // 7. Cek apakah AI balas dengan pertanyaan (prompt ambigu)
    if (!result.success && result.question != null && result.question!.isNotEmpty) {
      return result.question!;
    }

    // 8. Cek apakah AI berhasil generate SVG
    if (result.success && result.svg != null && result.svg!.isNotEmpty) {
      var elements = SvgToSlideElements.parse(result.svg!);

      // Quality check + auto-fix
      final qc = QualityChecker.check(elements);
      if (!qc.passed) {
        elements = QualityChecker.autoFix(elements, qc);
      }

      if (elements.isNotEmpty) {
        final currentSlide = provider.currentSlide;
        if (currentSlide != null) {
          currentSlide.elements.addAll(elements);
          provider.notify();
        }
        final textCount = elements.where((e) => e.type == ElementType.text).length;
        final shapeCount = elements.where((e) => e.type == ElementType.shape).length;
        final imageCount = elements.where((e) => e.type == ElementType.image).length;
        return l.aiDesignSuccess(elements.length, textCount, shapeCount, imageCount);
      }
    }

    // 7. Fallback: tampilkan error dari AI
    return result.error ?? l.aiGenerateFailed;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AiRunProvider>.value(
      value: _runProvider,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                _handleBar(),
                _header(),
                Expanded(
                  child: _panelModeIndex == 0
                      ? _messagesList(scrollCtrl)
                      : _docucraftBody(scrollCtrl),
                ),
                if (_panelModeIndex == 0)
                  _inputBar()
                else
                  _docucraftInputBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _handleBar() {
    return Center(
      child: Container(
        width: 40, height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _header() {
    final modelLabel = _selectedTier.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withAlpha(12)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Assistant', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connectionStatus == 'online'
                              ? AppTheme.success
                              : _connectionStatus == 'connecting'
                                  ? AppTheme.warning
                                  : AppTheme.error,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (_connectionStatus == 'connecting')
                        const SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      else
                        Text(
                          _connectionStatus == 'online' ? 'Keqo Aktif' : 'Keqo Nonaktif',
                          style: TextStyle(
                            fontSize: 10,
                            color: _connectionStatus == 'online' ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      if (_connectionStatus == 'offline') ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _retryWorkspaceConnection,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: 8, color: AppTheme.primary),
                                const SizedBox(width: 2),
                                Text(
                                  'Retry',
                                  style: TextStyle(fontSize: 8, color: AppTheme.primary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_workspaceProjectId != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspaces, size: 8, color: AppTheme.success),
                              const SizedBox(width: 3),
                              Text(
                                'Workspace Active',
                                style: TextStyle(fontSize: 8, color: AppTheme.success, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Sprint 12: AI Assistant / DocuCraft mode toggle
              _ModeToggle(
                modeIndex: _panelModeIndex,
                onChanged: (i) => setState(() => _panelModeIndex = i),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showModelPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(modelLabel, style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more, size: 12, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Workspace status bar (when project is active)
          if (_workspaceProjectId != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surface3,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspaces, size: 12, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Project: ${_workspaceProjectId!.substring(0, 12)}...',
                      style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withAlpha(30),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${_workspaceSlides.length} slides',
                      style: TextStyle(fontSize: 8, color: AppTheme.success, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _messagesList(ScrollController scrollCtrl) {
    final hasClarify = _activeClarifyQuestions.isNotEmpty && _activeClarifyRequestId != null;
    final itemCount = _messages.length + (hasClarify ? 1 : 0);
    return ListView.builder(
      controller: _messagesScrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        if (i < _messages.length) return _chatBubble(_messages[i]);
        // Last item: clarify card
        return _clarifyCard();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messagesScrollCtrl.hasClients) {
        _messagesScrollCtrl.animateTo(
          _messagesScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Interactive clarify card — shows questionnaire options from GenOffice
  Widget _clarifyCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withAlpha(60), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Pilih Jawaban',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...(_activeClarifyQuestions.asMap().entries.map((entry) {
            final qIdx = entry.key;
            final q = entry.value;
            final label = q['label']?.toString() ?? '';
            final options = (q['options'] as List?)?.cast<String>() ?? [];
            final description = q['description']?.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${qIdx + 1}. $label',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (description != null && description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text(
                        description,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withAlpha(150)),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ...options.map((opt) => _clarifyOptionButton(qIdx, opt)),
                      _clarifyOptionButton(qIdx, 'Decide for me', isDecide: true),
                    ],
                  ),
                ],
              ),
            );
          })),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _submitClarifyAnswer(answers: '', cancelled: true),
              child: Text(
                'Lewati Semua',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha(120)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clarifyOptionButton(int questionIndex, String option, {bool isDecide = false}) {
    return Material(
      color: isDecide ? AppTheme.primary.withAlpha(20) : AppTheme.surface3,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _onClarifyOption(questionIndex, option),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            option,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isDecide ? FontWeight.w600 : FontWeight.w500,
              color: isDecide ? AppTheme.primary : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  /// Handle clarify option selection — for now, submit single answer per question
  final Map<int, String> _clarifySelections = {};

  void _onClarifyOption(int questionIndex, String option) {
    debugPrint('🖥️ [Clarify] Option selected: Q$questionIndex = $option');
    debugPrint('🖥️ [Clarify] _activeClarifyRequestId: $_activeClarifyRequestId');
    debugPrint('🖥️ [Clarify] _genOfficeClient: ${_genOfficeClient != null}');
    debugPrint('🖥️ [Clarify] _activeClarifyQuestions.length: ${_activeClarifyQuestions.length}');
    debugPrint('🖥️ [Clarify] _clarifySelections.length: ${_clarifySelections.length}');
    setState(() {
      _clarifySelections[questionIndex] = option;
    });
    // If all questions answered, submit
    if (_clarifySelections.length == _activeClarifyQuestions.length) {
      final answer = _clarifySelections.entries
          .map((e) => 'Q${e.key + 1}: ${e.value}')
          .join('\n');
      _clarifySelections.clear();
      _submitClarifyAnswer(answers: answer);
    }
  }

  /// Strip SVG/HTML code blocks from AI text for clean chat display.
  /// Shows a placeholder instead of raw markup.
  static String _cleanDisplayText(String raw) {
    if (raw.isEmpty) return raw;
    // Remove <svg>...</svg> blocks
    var cleaned = raw.replaceAll(RegExp(r'<svg[\s\S]*?</svg>', multiLine: true), '').trim();
    // Remove ```svg code blocks
    cleaned = cleaned.replaceAll(RegExp(r'```svg[\s\S]*?```', multiLine: true), '').trim();
    // Remove leftover HTML-like tags (but keep plain text)
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    // If nothing meaningful remains, show a compact indicator
    if (cleaned.isEmpty) return '';
    return cleaned;
  }

  /// Render an AI message body as Markdown (bold/italic/lists/checkboxes/links/code),
  /// styled to match the chat bubble instead of showing raw `**`, `***`, `[ ]`, `- `
  /// markers as plain text.
  Widget _buildMarkdownBody(String text) {
    final base = TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.45);
    return MarkdownBody(
      data: text,
      fitContent: true,
      softLineBreak: true, // single \n renders as a line break (matches chat, not a space)
      styleSheet: MarkdownStyleSheet(
        p: base,
        pPadding: EdgeInsets.zero,
        strong: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.45),
        em: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary, height: 1.45),
        del: TextStyle(fontSize: 12, color: AppTheme.textMuted, decoration: TextDecoration.lineThrough),
        code: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: AppTheme.textPrimary,
          backgroundColor: AppTheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        blockquote: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
        blockquoteDecoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
        ),
        listBullet: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        listIndent: 14,
        blockSpacing: 6,
        h1: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        h2: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        h3: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        h4: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        a: TextStyle(fontSize: 12, color: AppTheme.primary, decoration: TextDecoration.underline),
        textAlign: WrapAlignment.start,
      ),
    );
  }

  Widget _chatBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.surface3,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streaming indicator — show "Thinking deeper…" when silent (GenOffice-style)
            if (msg.streaming && msg.text.isEmpty) ...[
              Consumer<AiRunProvider>(
                builder: (context, run, _) {
                  final isSilent = run.isSilent;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                      if (isSilent) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Thinking deeper…',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],

            // Main text content — strip SVG/HTML, then render Markdown for AI
            if (msg.text.isNotEmpty) ...[
              () {
                final displayText = isUser ? msg.text : _cleanDisplayText(msg.text);
                if (displayText.isEmpty) return const SizedBox.shrink();
                if (isUser) {
                  return Text(displayText, style: const TextStyle(fontSize: 12, color: Colors.white));
                }
                return _buildMarkdownBody(displayText);
              }(),
            ],

            // Error display
            if (msg.error != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  msg.error!,
                  style: TextStyle(fontSize: 12, color: colorScheme.onErrorContainer, height: 1.4),
                ),
              ),
            ],

            // Deck progress card (style → plan → images → pages)
            if (msg.deckProgress != null) ...[
              const SizedBox(height: 6),
              _buildDeckProgressCard(msg.deckProgress!),
            ],

            // Outline preview (editable, shown when awaiting review)
            if (msg.outlinePages != null && msg.outlineTopic != null) ...[
              const SizedBox(height: 8),
              OutlinePreview(
                initialPages: msg.outlinePages!,
                topic: msg.outlineTopic!,
                planSummary: msg.planSummary,
                onConfirmed: (result) {
                  if (msg.outlineRequestId != null) {
                    // Remote outline review from GenOffice — resolve back over HTTP
                    _submitOutlineReview(
                      msg.outlineRequestId!,
                      result.pages,
                      result.cancelled,
                    );
                  } else if (result.cancelled) {
                    _runProvider.resolveOutlineReview(cancelled: true);
                  } else {
                    _runProvider.resolveOutlineReview(pages: result.pages);
                  }
                },
                onCancelled: () {
                  if (msg.outlineRequestId != null) {
                    _submitOutlineReview(msg.outlineRequestId!, msg.outlinePages!, true);
                  } else {
                    _runProvider.resolveOutlineReview(cancelled: true);
                  }
                },
              ),
            ],

            // Slide options (multiple design variations)
            if (msg.slideOptions != null && msg.slideOptions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSlideOptionsInline(msg),
            ],

            // Tool badges (running + completed with output like GenOffice)
            if (msg.tools.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...msg.tools.map((tool) => _buildToolBadge(tool)),
            ],

            // Workspace actions row (for messages with slides)
            if (!isUser && msg.slideOptions != null && msg.slideOptions!.isNotEmpty && _workspaceConnected) ...[
              const SizedBox(height: 8),
              _buildWorkspaceActionsRow(msg),
            ],

            const SizedBox(height: 2),
            Text(msg.time, style: TextStyle(fontSize: 8, color: isUser ? Colors.white54 : AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  /// Build workspace actions row for slide messages
  Widget _buildWorkspaceActionsRow(_ChatMessage msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primary.withAlpha(20)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspaces, size: 12, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            'Workspace Actions',
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          // Refine all slides button
          if (msg.slideOptions!.isNotEmpty)
            _buildActionChip(
              icon: Icons.edit,
              label: 'Refine',
              onTap: () => _onRefineSlide(
                msg.slideOptions!.first.index,
                msg.slideOptions!.first.svg,
              ),
            ),
          const SizedBox(width: 6),
          // Regenerate button
          _buildActionChip(
            icon: Icons.refresh,
            label: 'Regenerate',
            onTap: () => _onRegenerateSlide(msg.slideOptions!.first.index),
          ),
        ],
      ),
    );
  }

  /// Build a small action chip button
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: AppTheme.primary),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a single tool badge with output display (like GenOffice's tool chips)
  Widget _buildToolBadge(_ToolActivity tool) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRunning = tool.running;
    final isError = tool.isError;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer.withAlpha(50)
              : isRunning
                  ? colorScheme.primary.withAlpha(30)
                  : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: isRunning
              ? Border.all(color: colorScheme.primary.withAlpha(80))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tool name row with status icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRunning)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary),
                  )
                else
                  Icon(
                    isError ? Icons.error : Icons.check_circle,
                    size: 12,
                    color: isError ? colorScheme.error : colorScheme.primary,
                  ),
                const SizedBox(width: 6),
                Text(
                  tool.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isError
                        ? colorScheme.error
                        : isRunning
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // Tool summary
            if (tool.summary.isNotEmpty && tool.summary != tool.name) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  tool.summary,
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ),
            ],
            // Tool output (truncated to 500 chars for UI, like GenOffice's TOOL_OUTPUT_MAX_CHARS = 2000)
            if (tool.output != null && !isRunning) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      tool.output!.length > 500
                          ? '${tool.output!.substring(0, 500)}…'
                          : tool.output!,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build deck progress card — all labels come from progress events (no hardcoded text)
  Widget _buildDeckProgressCard(_DeckProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = <_ProgressStage>[];

    if (progress.styleLabel != null) {
      steps.add(_ProgressStage(
        label: progress.styleLabel!,
        status: progress.styleStatus ?? 'running',
      ));
    }
    if (progress.planStatus != null) {
      steps.add(_ProgressStage(
        label: progress.planLabel ?? '',
        status: progress.planStatus ?? 'running',
        done: progress.planDone,
        total: progress.planTotal,
      ));
    }
    steps.add(_ProgressStage(
      label: progress.pagesLabel ?? '',
      status: progress.pagesStatus ?? 'running',
      done: progress.pagesDone,
      total: progress.pagesTotal,
    ));

    final hasError = steps.any((s) => s.status == 'error');
    final isDone = progress.isDone;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(
            children: [
              if (!isDone && !hasError)
                const SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary),
                )
              else
                Icon(
                  hasError ? Icons.error : Icons.check_circle,
                  size: 12,
                  color: hasError ? AppTheme.error : AppTheme.success,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasError ? 'Error' : isDone ? 'Done' : 'Working...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasError ? AppTheme.error : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Steps
          ...steps.map((step) => _buildProgressStep(step)),
          // Per-page items (GenOffice-style ✓/✗/⋯)
          if (progress.pages != null && progress.pages!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...progress.pages!.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final icon = p.status == _ProgressStatus.done
                  ? '✓'
                  : p.status == _ProgressStatus.error
                      ? '✗'
                      : p.status == _ProgressStatus.running
                          ? '⋯'
                          : '·';
              final color = p.status == _ProgressStatus.done
                  ? AppTheme.success
                  : p.status == _ProgressStatus.error
                      ? AppTheme.error
                      : p.status == _ProgressStatus.running
                          ? AppTheme.primary
                          : AppTheme.textMuted;
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    SizedBox(width: 14, child: Text(icon, style: TextStyle(fontSize: 10, color: color))),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Page ${i + 1}${p.title.isNotEmpty ? '· ${p.title}' : ''}',
                        style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Show error message for failed pages (GenOffice-style)
                    if (p.status == _ProgressStatus.error && p.error != null && p.error!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 0,
                        child: Text(
                          p.error!,
                          style: TextStyle(fontSize: 8, color: AppTheme.error, fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressStep(_ProgressStage step) {
    final isDone = step.status == 'done';
    final isError = step.status == 'error';
    final isRunning = step.status == 'running';

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: isDone
                ? const Icon(Icons.check, size: 10, color: AppTheme.success)
                : isError
                    ? const Icon(Icons.close, size: 10, color: AppTheme.error)
                    : isRunning
                        ? const SizedBox(
                            width: 8, height: 8,
                            child: CircularProgressIndicator(strokeWidth: 1, color: AppTheme.primary),
                          )
                        : Icon(Icons.circle_outlined, size: 10, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 10,
                color: isError
                    ? AppTheme.error
                    : isDone || isRunning
                        ? AppTheme.textSecondary
                        : AppTheme.textMuted,
              ),
            ),
          ),
          if (step.total > 0)
            Text(
              '${step.done}/${step.total}',
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }

  /// Build inline slide options display in chat bubble
  Widget _buildSlideOptionsInline(_ChatMessage msg) {
    final isThinMode = _thinUiState.stage == ThinUiStage.slide && _thinUiState.slideOptions.isNotEmpty;

    if (isThinMode) {
      // Thin UI mode: use ThinUiSlideOption (has optionId for backend sync)
      final options = _thinUiState.slideOptions;
      final selectedIndex = 0; // Thin mode: all selected via backend API call

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Design Options (${options.length} variations)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Options grid
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final option = options[index] as ThinUiSlideOption;
                  final isSelected = index == selectedIndex;

                  return GestureDetector(
                    // Call backend selectSlideOption with real optionId
                    onTap: () => _handleThinUiSlideSelected(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.white.withAlpha(20),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withAlpha(40),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // SVG Preview
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7),
                              ),
                              child: Container(
                                color: AppTheme.surfaceContainerHighest,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: SvgPicture.string(
                                    option.svg,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Style label
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withAlpha(30)
                                  : null,
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(7),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getStyleColor(option.style),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    option.style.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: AppTheme.primary,
                                  ),
                              ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    }

    // Non-thin mode: use SlideOption (from refine/regenerate messages)
    return _buildSlideOptionsForRefine(msg);
  }

  Widget _buildSlideOptionsForRefine(_ChatMessage msg) {
    final options = msg.slideOptions ?? [];
    final selectedIndex = msg.selectedSlideOptionIndex ?? 0;

    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Design Options (${options.length} variations)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Options grid
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = index == selectedIndex;

                return GestureDetector(
                  onTap: () => _selectSlideOption(msg, index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 180,
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.white.withAlpha(20),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withAlpha(40),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // SVG Preview
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                            child: Container(
                              color: AppTheme.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: SvgPicture.string(
                                  option.svg,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Style label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withAlpha(30)
                                : null,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getStyleColor(option.style),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  option.style.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: AppTheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Use button
          if (selectedIndex >= 0 && selectedIndex < options.length) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Apply button
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _applySlideOption(msg, options[selectedIndex]),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary.withAlpha(30),
                      foregroundColor: AppTheme.primary,
                    ),
                    child: const Text(
                      'Apply This Design',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                // Workspace actions (if connected)
                if (_workspaceConnected) ...[
                  const SizedBox(width: 8),
                  // Refine button
                  IconButton(
                    onPressed: () => _onRefineSlide(
                      options[selectedIndex].index,
                      options[selectedIndex].svg,
                    ),
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: 'Refine with feedback',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.warning.withAlpha(30),
                      foregroundColor: AppTheme.warning,
                    ),
                  ),
                  // Regenerate button
                  IconButton(
                    onPressed: () => _onRegenerateSlide(options[selectedIndex].index),
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Regenerate',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.success.withAlpha(30),
                      foregroundColor: AppTheme.success,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Get color for style name
  Color _getStyleColor(String style) {
    switch (style) {
      case 'modern':
        return Colors.blue;
      case 'minimal':
        return Colors.grey;
      case 'bold':
        return Colors.orange;
      case 'elegant':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  /// Handle slide option selection
  void _selectSlideOption(_ChatMessage msg, int index) {
    setState(() {
      // Find the message and update selected index
      final msgIndex = _messages.indexOf(msg);
      if (msgIndex != -1) {
        _messages[msgIndex] = _messages[msgIndex].copyWith(
          selectedSlideOptionIndex: index,
        );
      }
    });
  }

  /// Apply selected slide option to presentation
  void _applySlideOption(_ChatMessage msg, SlideOption option) {
    final provider = context.read<SlideProvider>();
    final currentSlide = provider.currentSlide;

    if (currentSlide != null) {
      // Parse SVG and add elements to current slide
      final elements = SvgToSlideElements.parse(option.svg);
      if (elements.isNotEmpty) {
        currentSlide.elements.addAll(elements);
        provider.notify();

        // Add confirmation message
        setState(() {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: 'Applied ${option.style} design to current slide.',
            time: 'Sekarang',
          ));
        });
      }
    }
  }

  /// Refine slide with user feedback via workspace
  Future<void> _onRefineSlide(int slideIndex, String currentSvg) async {
    final feedbackController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refine Slide'),
        content: TextField(
          controller: feedbackController,
          decoration: const InputDecoration(
            hintText: 'What should change? (e.g., "Make title bigger")',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, feedbackController.text),
            child: const Text('Refine'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _isGenerating = true;
        _messages.add(_ChatMessage(
          role: 'ai',
          text: 'Refining slide with feedback: "$result"',
          time: 'Sekarang',
          streaming: true,
        ));
      });

      final refinedSvg = await _refineSlideViaWorkspace(slideIndex, currentSvg, result);

      setState(() {
        _isGenerating = false;
        if (refinedSvg != null) {
          // Replace last streaming message with refined SVG preview
          final lastIndex = _messages.length - 1;
          _messages[lastIndex] = _ChatMessage(
            role: 'ai',
            text: 'Refined slide with feedback: "$result"',
            time: 'Sekarang',
            slideOptions: [SlideOption(index: slideIndex, style: 'refined', svg: refinedSvg)],
            selectedSlideOptionIndex: 0,
          );
        } else {
          final lastIndex = _messages.length - 1;
          _messages[lastIndex] = _ChatMessage(
            role: 'ai',
            text: 'Failed to refine slide. Please try again.',
            time: 'Sekarang',
            error: 'Refinement failed',
          );
        }
      });
    }
  }

  /// Regenerate slide via workspace
  Future<void> _onRegenerateSlide(int slideIndex) async {
    setState(() {
      _isGenerating = true;
      _messages.add(_ChatMessage(
        role: 'ai',
        text: 'Regenerating slide...',
        time: 'Sekarang',
        streaming: true,
      ));
    });

    final newSvg = await _regenerateSlideViaWorkspace(slideIndex);

    setState(() {
      _isGenerating = false;
      if (newSvg != null) {
        final lastIndex = _messages.length - 1;
        _messages[lastIndex] = _ChatMessage(
          role: 'ai',
          text: 'Regenerated slide',
          time: 'Sekarang',
          slideOptions: [SlideOption(index: slideIndex, style: 'regenerated', svg: newSvg)],
          selectedSlideOptionIndex: 0,
        );
      } else {
        final lastIndex = _messages.length - 1;
        _messages[lastIndex] = _ChatMessage(
          role: 'ai',
          text: 'Failed to regenerate slide. Please try again.',
          time: 'Sekarang',
          error: 'Regeneration failed',
        );
      }
    });
  }

  /// Generate slide options for a topic/title
  Future<void> _generateSlideOptions(String topic, String title) async {
    setState(() {
      _isGenerating = true;
      _messages.add(_ChatMessage(
        role: 'ai',
        text: 'Generating design options for "$title"...',
        time: 'Sekarang',
        streaming: true,
      ));
    });

    try {
      final client = GenOfficeClient();
      final response = await client.generateSlideMulti(
        topic: topic,
        title: title,
        optionCount: 3,
      );

      setState(() {
        // Replace streaming message with options
        final lastIndex = _messages.length - 1;
        _messages[lastIndex] = _ChatMessage(
          role: 'ai',
          text: 'Here are 3 design variations for "$title":',
          time: 'Sekarang',
          streaming: false,
          slideOptions: response.options,
          slideOptionsTopic: topic,
          slideOptionsTitle: title,
          selectedSlideOptionIndex: 0,
        );
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        final lastIndex = _messages.length - 1;
        _messages[lastIndex] = _ChatMessage(
          role: 'ai',
          text: 'Failed to generate options: $e',
          time: 'Sekarang',
          streaming: false,
          error: e.toString(),
        );
        _isGenerating = false;
      });
    }
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withAlpha(12))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              decoration: InputDecoration(
                hintText: 'Ketik prompt (mis: "Buat 5 slide...")',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppTheme.surface3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty && !_isGenerating) {
                  _sendMessage(text);
                  _inputCtrl.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // "Pro" mode toggle — when ON, Enter/send runs the normal generate-deck flow
          // (outline review → Generate/Cancel → deck), same as GenOffice Pro mode.
          GestureDetector(
            onTap: _toggleProMode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _proMode ? AppTheme.primary : AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _proMode ? AppTheme.primary : AppTheme.primary.withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  'Pro',
                  style: TextStyle(
                    fontSize: 12,
                    color: _proMode ? Colors.white : AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final text = _inputCtrl.text;
              if (text.trim().isNotEmpty && !_isGenerating) {
                _sendMessage(text);
                _inputCtrl.clear();
              }
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Toggle Pro mode — when ON, Enter/send routes through the normal GenOffice
  /// generation flow (outline review → Generate/Cancel → deck).
  void _toggleProMode() {
    setState(() => _proMode = !_proMode);
  }

  /// Detect if a prompt is a presentation generation request
  bool _isGenerationPrompt(String text) {
    final lower = text.toLowerCase();
    // Keywords that indicate the user wants to generate a full presentation
    return lower.contains('buat ppt') || lower.contains('buat presentasi') ||
        lower.contains('generate ppt') || lower.contains('generate presentasi') ||
        lower.contains('bikin ppt') || lower.contains('bikin presentasi') ||
        lower.contains('create ppt') || lower.contains('create presentation') ||
        lower.contains('slide tentang') || lower.contains('slide about') ||
        (lower.contains('ppt') && (lower.contains('tentang') || lower.contains('about'))) ||
        (lower.contains('presentasi') && (lower.contains('tentang') || lower.contains('about')));
  }

  /// Send message: add user chat to list, then process
  Future<void> _sendMessage(String text) async {
    final l = AppLocalizations.of(context);

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text, time: 'Sekarang'));
      _isGenerating = true;
    });
    _scrollToBottom();

    // Open GenOffice workspace on first message (if connected)
    await _initWorkspaceProject(text);

    // If connected to GenOffice, forward ALL prompts to GenOffice AI panel
    if (_workspaceConnected && _genOfficeWorkspaceId != null) {
      // Always forward prompt to GenOffice AI panel so it appears in the UI
      _forwardPromptToGenOffice(text);

      if (_proMode) {
        // Pro mode: normal GenOffice flow (agent → outline review → Generate/Cancel → deck).
        // The deck reaches the Flutter canvas via the `deck-ready` WebSocket broadcast.
        // Do NOT start the thin-UI run here — its `runStates` entry would stay stuck at
        // `outline` and cause a 409 "Run already in progress" on the next send.
        // Reset the "slides fetched" guard so a Pro deck-ready after a prior (non-Pro or Pro)
        // run still applies to the canvas instead of being skipped.
        _thinUiSlidesFetched = false;
        setState(() {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: '✅ AI sedang menyiapkan outline untuk direview...',
            time: 'Sekarang',
          ));
          _isGenerating = false;
        });
      } else if (_isGenerationPrompt(text)) {
        // Generation prompts (non-Pro): start the Thin UI flow (outline → style → slides → PPTX → whiteboard).
        _startThinUiRun(text);
        setState(() {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: '🎨 Memulai generasi presentasi... Silakan pilih outline, style, dan desain slide.',
            time: 'Sekarang',
          ));
          _isGenerating = false;
        });
      } else {
        // Non-generation prompts: just forward to GenOffice AI panel
        setState(() {
          _messages.add(_ChatMessage(
            role: 'ai',
            text: '✅ AI sedang memproses permintaanmu...',
            time: 'Sekarang',
          ));
          _isGenerating = false;
        });
      }
      return;
    }

    // Fallback: local AI processing (when GenOffice not connected)
    try {
      final result = await _processPrompt(text);
      setState(() {
        _messages.add(_ChatMessage(role: 'ai', text: result, time: 'Sekarang'));
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(role: 'ai', text: l.aiGenericError(e.toString()), time: 'Sekarang'));
        _isGenerating = false;
      });
    }
  }

  /// Form edit detail desain

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Model AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            _modelOption(AiModelTier.fast),
            _modelOption(AiModelTier.quality),
            _modelOption(AiModelTier.powerful),
            _modelOption(AiModelTier.reasoning),
            _modelOption(AiModelTier.claude),
            _modelOption(AiModelTier.vision),
          ],
        ),
      ),
    );
  }

  Widget _modelOption(AiModelTier tier) {
    return ListTile(
      leading: Icon(Icons.smart_toy, color: _selectedTier == tier ? AppTheme.primary : AppTheme.textMuted),
      title: Text(tier.label, style: TextStyle(fontSize: 12, color: _selectedTier == tier ? AppTheme.primary : AppTheme.textPrimary)),
      subtitle: Text(tier.modelId, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      onTap: () {
        setState(() => _selectedTier = tier);
        Navigator.pop(context);
      },
    );
  }

  // ── Sprint 12: DocuCraft mode body + input bar ────────────────────
// Now uses unified chat messages (like GenOffice) — AI output streams
// directly in the chat, no separate DeckProgressCard/OutlinePreview.

  Widget _docucraftBody(ScrollController scrollCtrl) {
    return _messagesList(scrollCtrl);
  }

  Widget _docucraftInputBar() {
    return Consumer<AiRunProvider>(
      builder: (context, run, _) {
        final isBusy = run.isBusy;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withAlpha(12))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  enabled: !isBusy,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isBusy
                        ? ''
                        : 'Describe the deck you want to create…',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.surface3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isBusy)
                IconButton(
                  onPressed: () => _runProvider.cancel(),
                  icon: const Icon(Icons.stop_circle_outlined, color: AppTheme.error),
                  tooltip: 'Stop',
                )
              else
                IconButton(
                  onPressed: _startDocucraftRun,
                  icon: const Icon(Icons.rocket_launch, color: AppTheme.primary),
                  tooltip: 'Generate',
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startDocucraftRun() async {
    final topic = _inputCtrl.text.trim();
    if (topic.isEmpty) return;
    _inputCtrl.clear();

    // Add user message to chat so it's visible
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: topic, time: 'Sekarang'));
    });

    _runProvider.start(instruction: topic, displayText: topic);

    // Initialize workspace project for this run
    await _initWorkspaceProject(topic);

    // Sprint 21: capture the AppLocalizations before the async boundary
    // so the error fallback strings resolve in the user's locale even
    // when the BuildContext is no longer mounted.
    final l = AppLocalizations.of(context);

    // Sprint 14: try the real AgentLoop first; fall back to a synthetic
    // outline when the backend is unavailable so the chat panel still
    // demonstrates the flow offline.
    final transport = core.HttpChatTransport(
      config: core.HttpChatTransportConfig(
        baseUrl: AiConfig.baseUrl, // Auto-detect: proxy for web, direct for mobile
        apiKey: AiConfig.apiKey,
        defaultModel: _selectedTier.modelId, // Use selected model tier
      ),
    );
    final systemPrompt = await SkillLoader.buildSystemPrompt(route: 'generate-pptx');

    final coord = core.DocuCraftRunCoordinator(
      transport: transport,
      systemPrompt: systemPrompt,
      onOutlineReady: (t, initial, {String? planSummary}) async {
        if (!mounted) return initial;
        // Sync outline to GenOffice workspace
        await _syncOutlineToWorkspace(initial);
        return _runProvider.enterOutlineReview(topic: t, pages: initial, planSummary: planSummary);
      },
      onSlideLanded: (slide, {required replaceAll}) {
        if (!mounted) return;
        debugPrint('🖼️ [onSlideLanded] slide=${slide.id}, elements=${slide.elements.length}, replaceAll=$replaceAll, provider=${_slideProvider != null ? "OK" : "NULL"}');
        if (_slideProvider == null) {
          debugPrint('⚠️ [onSlideLanded] _slideProvider is null — slide NOT applied to canvas!');
          return;
        }
        _slideProvider!.applyAiResult([slide], replaceAll: replaceAll);
        debugPrint('✅ [onSlideLanded] Applied slide to canvas. Total slides: ${_slideProvider!.slides.length}');
        // Sync slide to GenOffice workspace
        if (replaceAll) {
          _workspaceSlides.clear(); // Clear old slides when replacing all
        }
        // Convert slide to simple SVG representation for workspace sync
        final svg = _slideToSvg(slide);
        final slideIndex = _workspaceSlides.length;
        _syncSlideToWorkspace(
          slideIndex,
          slide.title,
          svg,
          'generated',
        );
      },
      onProgress: ({required stage, required label, required done, required total, required status, summary, pages}) {
        if (!mounted) return;
        // Update progress in runProvider for UI display
        // (mirrors GenOffice's onProgress callback with granular stages)
        _runProvider.onProgress(
          stage: stage,
          label: label,
          done: done,
          total: total,
          status: status,
          summary: summary,
          pages: pages,
        );
      },
      // GenOffice-style: Save real .pptx file after all pages land
      onDeckSaved: ({required slides, required deckName, required replaceAll}) async {
        if (!mounted) return const LandResult(ok: false, error: 'Context not mounted');
        return await PptxBuilder.build(
          slides: slides,
          deckName: deckName,
          replaceAll: replaceAll,
        );
      },
    );

    try {
      // Stage 1: Plan the outline (AI generates structure)
      // Emit initial plan stage - no hardcoded label, AI output will fill it
      _runProvider.onProgress(
        stage: 'plan',
        label: '',
        done: 0,
        total: 1,
        status: 'running',
      );

      final pages = await coord.planOutline(topic: topic, runProvider: _runProvider);

      if (pages.isEmpty) {
        // User cancelled or outline was empty - show demo outline for fallback
        if (!mounted) return;
        _runProvider.onError(l.aiErrorPlanningEmpty);
        await _runProvider.enterOutlineReview(topic: topic, pages: _planDemoOutline(topic));
        return;
      }

      // Stage 2: Generate the deck slides (user confirmed outline)
      if (!mounted) return;

      // No hardcoded user message - AI output already shows the reasoning
      // Update progress: planning done, now generating
      _runProvider.onToolStart('generate_deck');

      final deckResult = await coord.generateDeck(
        topic: topic,
        pages: pages,
        styleSkill: null, // Let the AI decide the style
        runProvider: _runProvider,
      );

      // Signal tool completion so the UI updates
      _runProvider.onToolExecuted(
        'generate_deck',
        result: {
          'success': deckResult.success,
          'slideCount': deckResult.slides.length,
          'pptxPath': deckResult.pptxPath,
        },
        isError: !deckResult.success,
        summary: deckResult.success
            ? 'Generated ${deckResult.slides.length} slides'
            : deckResult.error ?? 'Generation failed',
      );

    } catch (e) {
      // Backend offline / model error → fall back to demo outline so the
      // user can still see the flow.
      if (!mounted) return;
      _runProvider.onError(l.aiErrorBackendOffline(e.toString()));
      await _runProvider.enterOutlineReview(topic: topic, pages: _planDemoOutline(topic));
    }
  }

  List<OutlinePage> _planDemoOutline(String topic) {
    return [
      OutlinePage(index: 1, title: 'Introduction', brief: 'Overview of $topic'),
      OutlinePage(index: 2, title: 'Why it matters', brief: 'Context and motivation'),
      OutlinePage(index: 3, title: 'How it works', brief: 'Core mechanism of $topic'),
      OutlinePage(index: 4, title: 'Key takeaways', brief: 'Summary of $topic'),
    ];
  }
}

/// Sprint 12: Segmented toggle for AI Assistant / DocuCraft mode.
class _ModeToggle extends StatelessWidget {
  final int modeIndex;
  final ValueChanged<int> onChanged;
  const _ModeToggle({required this.modeIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(0, 'AI', Icons.chat_bubble_outline),
          _seg(1, 'DocuCraft', Icons.auto_awesome),
        ],
      ),
    );
  }

  Widget _seg(int i, String label, IconData icon) {
    final selected = modeIndex == i;
    return GestureDetector(
      onTap: () => onChanged(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? Colors.white : AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tool activity info for streaming display (mirrors GenOffice's ToolActivity)
class _ToolActivity {
  final String name;
  final String summary;
  final bool running;
  final bool isError;
  final String? output; // Full tool output (truncated to 2000 chars in UI)

  const _ToolActivity({
    required this.name,
    required this.summary,
    this.running = false,
    this.isError = false,
    this.output,
  });

  _ToolActivity copyWith({
    String? name,
    String? summary,
    bool? running,
    bool? isError,
    String? output,
  }) {
    return _ToolActivity(
      name: name ?? this.name,
      summary: summary ?? this.summary,
      running: running ?? this.running,
      isError: isError ?? this.isError,
      output: output ?? this.output,
    );
  }
}

/// Chat message supporting streaming, tools, errors, deck progress, and slide options.
class _ChatMessage {
  final String role; // 'user' | 'ai'
  final String text;
  final String time;
  final bool streaming;
  final String? error;
  final List<_ToolActivity> tools;
  final _DeckProgress? deckProgress;
  final int? snapshotId;
  // Outline review fields (when RunAwaitingOutlineReview)
  final List<OutlinePage>? outlinePages;
  final String? outlineTopic;
  final String? planSummary;
  // Set when the outline review came from GenOffice (remote) and must be
  // resolved back over HTTP (vs local DocuCraft mode which uses _runProvider).
  final String? outlineRequestId;
  // Slide options fields (multiple design variations)
  final List<SlideOption>? slideOptions;
  final String? slideOptionsTopic;
  final String? slideOptionsTitle;
  final int? selectedSlideOptionIndex;

  const _ChatMessage({
    required this.role,
    required this.text,
    required this.time,
    this.streaming = false,
    this.error,
    this.tools = const [],
    this.deckProgress,
    this.snapshotId,
    this.outlinePages,
    this.outlineTopic,
    this.planSummary,
    this.outlineRequestId,
    this.slideOptions,
    this.slideOptionsTopic,
    this.slideOptionsTitle,
    this.selectedSlideOptionIndex,
  });

  _ChatMessage copyWith({
    String? role,
    String? text,
    String? time,
    bool? streaming,
    String? error,
    List<_ToolActivity>? tools,
    _DeckProgress? deckProgress,
    int? snapshotId,
    List<OutlinePage>? outlinePages,
    String? outlineTopic,
    String? planSummary,
    String? outlineRequestId,
    List<SlideOption>? slideOptions,
    String? slideOptionsTopic,
    String? slideOptionsTitle,
    int? selectedSlideOptionIndex,
  }) {
    return _ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      time: time ?? this.time,
      streaming: streaming ?? this.streaming,
      error: error ?? this.error,
      tools: tools ?? this.tools,
      deckProgress: deckProgress ?? this.deckProgress,
      snapshotId: snapshotId ?? this.snapshotId,
      outlinePages: outlinePages ?? this.outlinePages,
      outlineTopic: outlineTopic ?? this.outlineTopic,
      planSummary: planSummary ?? this.planSummary,
      outlineRequestId: outlineRequestId ?? this.outlineRequestId,
      slideOptions: slideOptions ?? this.slideOptions,
      slideOptionsTopic: slideOptionsTopic ?? this.slideOptionsTopic,
      slideOptionsTitle: slideOptionsTitle ?? this.slideOptionsTitle,
      selectedSlideOptionIndex: selectedSlideOptionIndex ?? this.selectedSlideOptionIndex,
    );
  }

  /// Serialize the essential conversational content (role/text/time/error) for
  /// cross-session persistence. Transient interactive state (streaming flags,
  /// tool activity, outline review, slide options, deck progress) is intentionally
  /// omitted — those are re-derived live and would go stale on reload.
  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'time': time,
    if (error != null) 'error': error,
  };

  static _ChatMessage fromJson(Map<String, dynamic> j) => _ChatMessage(
    role: j['role']?.toString() ?? 'ai',
    text: j['text']?.toString() ?? '',
    time: j['time']?.toString() ?? 'Sekarang',
    error: j['error']?.toString(),
  );
}

// ── Deck progress (minimal, driven by SlidesSkill events) ──────────────

enum _ProgressStatus { pending, running, done, error }

class _PageProgress {
  final String title;
  final _ProgressStatus status;
  final String? error;
  const _PageProgress({required this.title, required this.status, this.error});
}

class _DeckProgress {
  final String? styleLabel;
  final String? styleStatus;
  final String? planLabel;
  final int planDone;
  final int planTotal;
  final String? planStatus;
  final String? pagesLabel;
  final int pagesDone;
  final int pagesTotal;
  final String? pagesStatus;
  final List<_PageProgress>? pages;
  final bool isDone;

  const _DeckProgress({
    this.styleLabel,
    this.styleStatus,
    this.planLabel,
    this.planDone = 0,
    this.planTotal = 0,
    this.planStatus,
    this.pagesLabel,
    this.pagesDone = 0,
    this.pagesTotal = 0,
    this.pagesStatus,
    this.pages,
    this.isDone = false,
  });

  bool get isRunning =>
      styleStatus == 'running' || planStatus == 'running' || pagesStatus == 'running';
}

/// Helper class for progress stage rendering
class _ProgressStage {
  final String label;
  final String status; // 'running' | 'done' | 'error'
  final int done;
  final int total;

  const _ProgressStage({
    required this.label,
    required this.status,
    this.done = 0,
    this.total = 0,
  });
}
