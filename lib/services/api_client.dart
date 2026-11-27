// DocuCraft — ApiClient
// HTTP client terpusat untuk semua panggilan API.

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/endpoints.dart';

/// Standard API response envelope
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? code;
  final Map<String, dynamic>? meta;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.code,
    this.meta,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['error'] == null,
      data: json['data'] as T?,
      error: json['error'] as String?,
      code: json['code'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

/// API Client — singleton Dio-based HTTP client
class ApiClient {
  static Dio? _dio;
  static String? _authToken;

  // ── Configuration ──
  // URL backend dev terpusat di Endpoints (lib/config/endpoints.dart).
  static String get _devBaseUrl => Endpoints.api;
  static const String _prodBaseUrl = 'https://api.docucraft.app/api';
  static const int _connectTimeoutMs = 10000;
  static const int _receiveTimeoutMs = 30000;
  static const int _maxRetries = 3;

  static bool _useProduction = false;

  static void useProduction() => _useProduction = true;

  static Dio get dio {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final baseUrl = _useProduction ? _prodBaseUrl : _devBaseUrl;
    final d = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: _connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: _receiveTimeoutMs),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.type != DioExceptionType.badResponse &&
            error.type != DioExceptionType.cancel) {
          handler.next(error);
          return;
        }
        handler.next(error);
      },
    ));

    if (kDebugMode) {
      d.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        // responseBody OFF — respons bisa ratusan KB, jangan dicetak tiap request.
        responseBody: false,
        error: true,
        logPrint: (obj) => debugPrint('🌐 [API] $obj'),
      ));
    }

    return d;
  }

  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static String? get authToken => _authToken;

  static String get baseUrl => _devBaseUrl;

  static Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      return _parseResponse<T>(response);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  static Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.post(path, data: body);
      return _parseResponse<T>(response);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  static Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.put(path, data: body);
      return _parseResponse<T>(response);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  static Future<ApiResponse<T>> delete<T>(String path) async {
    try {
      final response = await dio.delete(path);
      return _parseResponse<T>(response);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  static ApiResponse<T> _parseResponse<T>(Response response) {
    if (response.statusCode == null || response.statusCode! >= 400) {
      final data = response.data;
      final errorMsg = data is Map ? data['error']?.toString() : 'Unknown error';
      final errorCode = data is Map ? data['code']?.toString() : 'HTTP_${response.statusCode}';
      return ApiResponse(success: false, error: errorMsg, code: errorCode);
    }

    if (response.data is Map) {
      final map = response.data as Map<String, dynamic>;
      return ApiResponse(
        success: true,
        data: map['data'] as T?,
        meta: map['meta'] as Map<String, dynamic>?,
      );
    }

    return ApiResponse(success: true, data: response.data as T?);
  }

  static ApiResponse<T> _handleError<T>(DioException e) {
    final statusCode = e.response?.statusCode;
    final errorMsg = e.response?.data is Map
        ? (e.response?.data as Map)['error']?.toString()
        : e.message;

    String code;
    if (statusCode == 401) {
      code = 'UNAUTHORIZED';
    } else if (statusCode == 403) {
      code = 'FORBIDDEN';
    } else if (statusCode == 404) {
      code = 'NOT_FOUND';
    } else if (statusCode == 409) {
      code = 'CONFLICT';
    } else if (statusCode == 429) {
      code = 'RATE_LIMITED';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      code = 'CONNECT_TIMEOUT';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      code = 'RECEIVE_TIMEOUT';
    } else if (e.type == DioExceptionType.connectionError) {
      code = 'CONNECTION_ERROR';
    } else {
      code = 'UNKNOWN_ERROR';
    }

    debugPrint('❌ [API] $code: $errorMsg');
    return ApiResponse(success: false, error: errorMsg ?? code, code: code);
  }

  static void reset() {
    _dio = null;
    _authToken = null;
  }
}

// ═══════════════════════════════════════════════════════════════
// GENOFFICE HTTP SERVER API MODELS
// ═══════════════════════════════════════════════════════════════

class SlideOption {
  final int index;
  final String style;
  final String svg;

  SlideOption({
    required this.index,
    required this.style,
    required this.svg,
  });

  factory SlideOption.fromJson(Map<String, dynamic> json) {
    return SlideOption(
      index: json['index'] as int,
      style: json['style'] as String,
      svg: json['svg'] as String,
    );
  }
}

class SlideMultiResponse {
  final bool ok;
  final String topic;
  final String title;
  final int index;
  final int total;
  final List<SlideOption> options;
  final int selected;

  SlideMultiResponse({
    required this.ok,
    required this.topic,
    required this.title,
    required this.index,
    required this.total,
    required this.options,
    required this.selected,
  });

  factory SlideMultiResponse.fromJson(Map<String, dynamic> json) {
    return SlideMultiResponse(
      ok: json['ok'] as bool,
      topic: json['topic'] as String,
      title: json['title'] as String,
      index: json['index'] as int,
      total: json['total'] as int,
      options: (json['options'] as List)
          .map((e) => SlideOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      selected: json['selected'] as int,
    );
  }
}

class OutlineItem {
  final int index;
  final String title;
  final String brief;

  OutlineItem({
    required this.index,
    required this.title,
    required this.brief,
  });

  factory OutlineItem.fromJson(Map<String, dynamic> json) {
    return OutlineItem(
      index: json['index'] as int,
      title: json['title'] as String,
      brief: json['brief'] as String,
    );
  }
}

class OutlineResponse {
  final List<OutlineItem> outline;

  OutlineResponse({required this.outline});

  factory OutlineResponse.fromJson(Map<String, dynamic> json) {
    return OutlineResponse(
      outline: (json['outline'] as List)
          .map((e) => OutlineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StyleSkill {
  final Map<String, dynamic> colors;
  final Map<String, dynamic> fonts;
  final Map<String, dynamic> layoutVariants;
  final String overallStyle;

  StyleSkill({
    required this.colors,
    required this.fonts,
    required this.layoutVariants,
    required this.overallStyle,
  });

  factory StyleSkill.fromJson(Map<String, dynamic> json) {
    return StyleSkill(
      colors: json['colors'] as Map<String, dynamic>,
      fonts: json['fonts'] as Map<String, dynamic>,
      layoutVariants: json['layoutVariants'] as Map<String, dynamic>,
      overallStyle: json['overallStyle'] as String,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GENOFFICE CLIENT
// ═══════════════════════════════════════════════════════════════

class GenOfficeClient {
  final String baseUrl;
  final Dio _dio;

  GenOfficeClient({String? baseUrl})
      : baseUrl = baseUrl ?? Endpoints.backend,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? Endpoints.backend,
          connectTimeout: const Duration(seconds: 10),
          // generate-slide-multi runs 3-4 options sequentially (~2 min each)
          // and Gamma generation takes minutes — 60s cut both off.
          // 540s: worst case optionCount=4 × ~135s with headroom.
          receiveTimeout: const Duration(seconds: 540),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestBody: true,
        // responseBody OFF: generate-slide membalas SVG puluhan KB —
        // mencetaknya ke console tiap request bikin debug run berat.
        responseBody: false,
        error: true,
        logPrint: (obj) => debugPrint('🖥️ [GenOffice] $obj'),
      ));
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/api/v1/health');
      return response.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<OutlineResponse> generateOutline({
    required String topic,
    int slideCount = 5,
  }) async {
    final response = await _dio.post('/api/v1/generate-outline', data: {
      'topic': topic,
      'slideCount': slideCount,
    });
    return OutlineResponse.fromJson(response.data);
  }

  Future<String> generateSlide({
    required String topic,
    required String title,
    String style = 'modern',
    String color = 'indigo',
    int index = 0,
    int total = 1,
    String? previousTitle,
    String? nextTitle,
  }) async {
    final response = await _dio.post('/api/v1/generate-slide', data: {
      'topic': topic,
      'title': title,
      'style': style,
      'color': color,
      'index': index,
      'total': total,
      if (previousTitle != null) 'previousTitle': previousTitle,
      if (nextTitle != null) 'nextTitle': nextTitle,
    });
    return response.data['svg'] as String;
  }

  Future<SlideMultiResponse> generateSlideMulti({
    required String topic,
    required String title,
    String style = 'modern',
    String color = 'indigo',
    int index = 0,
    int total = 1,
    int optionCount = 3,
  }) async {
    final response = await _dio.post('/api/v1/generate-slide-multi', data: {
      'topic': topic,
      'title': title,
      'style': style,
      'color': color,
      'index': index,
      'total': total,
      'optionCount': optionCount,
    });
    return SlideMultiResponse.fromJson(response.data);
  }

  Future<StyleSkill> generateStyle({
    required String topic,
    String styleHint = 'modern, clean',
    String questionnaire = '',
  }) async {
    final response = await _dio.post('/api/v1/generate-style', data: {
      'topic': topic,
      'styleHint': styleHint,
      if (questionnaire.isNotEmpty) 'questionnaire': questionnaire,
    });
    return StyleSkill.fromJson(response.data['styleSkill']);
  }

  Future<Map<String, dynamic>> generateDeck({
    required String topic,
    int approxPages = 5,
    Map<String, dynamic>? styleSkill,
    String context = '',
  }) async {
    final response = await _dio.post('/api/v1/generate-deck', data: {
      'topic': topic,
      'approxPages': approxPages,
      if (styleSkill != null) 'styleSkill': styleSkill,
      if (context.isNotEmpty) 'context': context,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<String> chatCompletions({
    required List<Map<String, String>> messages,
    String? model,
    int maxTokens = 4096,
    double temperature = 0.7,
    bool stream = false,
  }) async {
    final response = await _dio.post('/api/v1/chat/completions', data: {
      'messages': messages,
      if (model != null) 'model': model,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': stream,
    });
    return response.data['choices'][0]['message']['content'] as String;
  }

  /// Document AI chat — sends a document-specific prompt to GenOffice AI.
  /// [action] can be: 'chat', 'ringkas', 'grammar', 'lanjutkan', 'ubah-nada'.
  Future<Map<String, dynamic>> documentAiChat({
    required String prompt,
    required String documentContent,
    String action = 'chat',
    String? model,
  }) async {
    final systemPrompts = <String, String>{
      'chat': 'You are Keqo AI, a professional document writing assistant. Help the user write, edit, and improve their documents. Respond in the same language as the user. Be concise and helpful.',
      'ringkas': 'You are a document editor. Ringkas (summarize) the following text to be more concise while preserving key meaning. Return ONLY the summarized text, no explanation.',
      'grammar': 'You are a grammar checker. Perbaiki tata bahasa (fix grammar) of the following text in Indonesian. Return ONLY the corrected text, no explanation.',
      'lanjutkan': 'You are a creative writer. Lanjutkan (continue) writing the following document naturally. Return ONLY the continuation text, no explanation.',
      'ubah-nada': 'You are a tone editor. Ubah nada bicara (change the tone) of the following text to be more formal and professional. Return ONLY the rewritten text, no explanation.',
    };
    final system = systemPrompts[action] ?? systemPrompts['chat']!;
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': documentContent.isNotEmpty ? 'Dokumen saat ini:\n$documentContent\n\nInstruksi: $prompt' : prompt},
    ];
    try {
      final content = await chatCompletions(messages: messages, model: model, maxTokens: 2048, temperature: 0.7);
      return {'ok': true, 'content': content};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Open a document workspace in GenOffice — opens a docs tab in the UI.
  /// Returns { ok, workspaceId, tabId, webContentsId } on success.
  Future<Map<String, dynamic>> openDocumentWorkspace() async {
    final response = await _dio.post('/api/v1/document/open', data: {});
    return response.data as Map<String, dynamic>;
  }

  /// Send a prompt to an open document workspace in GenOffice.
  /// Requires the [workspaceId] returned by [openDocumentWorkspace].
  Future<Map<String, dynamic>> sendDocumentPrompt({
    required String workspaceId,
    required String prompt,
    String? model,
  }) async {
    final response = await _dio.post('/api/v1/document/prompt', data: {
      'workspaceId': workspaceId,
      'prompt': prompt,
      if (model != null) 'model': model,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listTemplates() async {
    final response = await _dio.get('/api/v1/templates');
    return (response.data['templates'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> saveTemplate({
    required String name,
    required Map<String, dynamic> styleSkill,
  }) async {
    final response = await _dio.post('/api/v1/templates', data: {
      'name': name,
      'styleSkill': styleSkill,
    });
    return response.data['template'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listBlueprints() async {
    final response = await _dio.get('/api/v1/blueprints');
    return (response.data['blueprints'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> saveBlueprint({
    required String name,
    required List<Map<String, dynamic>> slides,
  }) async {
    final response = await _dio.post('/api/v1/blueprints', data: {
      'name': name,
      'slides': slides,
    });
    return response.data['blueprint'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forkBlueprint({
    required String id,
    required String newName,
  }) async {
    final response = await _dio.post('/api/v1/blueprints/$id/fork', data: {
      'name': newName,
    });
    return response.data['blueprint'] as Map<String, dynamic>;
  }

  // ── Workspace Management (opens GenOffice slides tab) ──

  Future<Map<String, dynamic>> openWorkspace({String? projectId}) async {
    final response = await _dio.post('/api/v1/workspace/open', data: {
      if (projectId != null) 'projectId': projectId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> switchWorkspace({
    required String workspaceId,
  }) async {
    final response = await _dio.post('/api/v1/workspace/switch', data: {
      'workspaceId': workspaceId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeWorkspace({
    required String workspaceId,
  }) async {
    final response = await _dio.post('/api/v1/workspace/close', data: {
      'workspaceId': workspaceId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Send a prompt to the workspace AI panel (GenOffice processes it)
  Future<void> sendPromptToWorkspace({
    required String workspaceId,
    required String prompt,
    String? model, // AI model override from Flutter (e.g. 'kc/nvidia/nemotron-3-ultra-550b-a55b:free')
    bool pro = false, // Pro mode: deck generation routed to Gamma after outline review
  }) async {
    await _dio.post('/api/v1/workspace/prompt', data: {
      'workspaceId': workspaceId,
      'prompt': prompt,
      if (model != null) 'model': model,
      if (pro) 'pro': true,
    });
  }

  /// Submit clarify answer back to GenOffice (interactive questionnaire response)
  Future<void> sendClarifyAnswer({
    required String requestId,
    required String answers,
    bool cancelled = false,
  }) async {
    await _dio.post('/api/v1/workspace/clarify-answer', data: {
      'requestId': requestId,
      'answers': answers,
      'cancelled': cancelled,
    });
  }

  /// Submit outline review answer back to GenOffice (confirm with edited pages / cancel)
  Future<void> resolveOutlineReview({
    required String requestId,
    required List<Map<String, dynamic>> pages,
    bool cancelled = false,
  }) async {
    await _dio.post('/api/v1/workspace/resolve-outline', data: {
      'requestId': requestId,
      'pages': pages,
      'cancelled': cancelled,
    });
  }

  /// Generate a presentation via the "Pro" (Gamma TA) service, handled by GenOffice.
  /// Returns { ok: bool, result: { gammaUrl, exportUrl, ... } }.
  ///
  /// Frontend hanya memanggil **backend** (Endpoints.gammaGeneratePath);
  /// backend GenOffice-lah yang memanggil Gamma TA API
  /// (https://public-api.gamma.app/v1.0, header X-API-KEY) dengan
  /// `gammaApiKey` dari ai-settings.json server. Lihat docs/BACKEND_DAN_GAMMA.md.
  Future<Map<String, dynamic>> gammaGenerate({required String inputText}) async {
    final response = await _dio.post(Endpoints.gammaGeneratePath, data: {
      'inputText': inputText,
      'exportAs': 'pptx',
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listWorkspaces() async {
    final response = await _dio.get('/api/v1/workspace/list');
    return (response.data['workspaces'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Get selected slides SVG data from a workspace (for Flutter canvas rendering)
  Future<Map<String, dynamic>> getWorkspaceSlides({
    required String workspaceId,
  }) async {
    final response = await _dio.get(
      '/api/v1/workspace/slides',
      queryParameters: {'workspaceId': workspaceId},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Thin UI Run Management ──

  /// Start a thin UI generation run (all processing happens in GenOffice)
  Future<Map<String, dynamic>> startThinUiRun({
    required String workspaceId,
    required String topic,
    int slideCount = 5,
    String styleHint = 'modern, clean',
    String? model,
  }) async {
    final response = await _dio.post('/api/v1/workspace/run', data: {
      'workspaceId': workspaceId,
      'topic': topic,
      'slideCount': slideCount,
      'styleHint': styleHint,
      if (model != null) 'model': model,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Select an outline option
  Future<Map<String, dynamic>> selectOutline({
    required String workspaceId,
    required String outlineId,
  }) async {
    final response = await _dio.post('/api/v1/workspace/select-outline', data: {
      'workspaceId': workspaceId,
      'outlineId': outlineId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Select a style option
  Future<Map<String, dynamic>> selectStyle({
    required String workspaceId,
    required String styleId,
  }) async {
    final response = await _dio.post('/api/v1/workspace/select-style', data: {
      'workspaceId': workspaceId,
      'styleId': styleId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Select a slide design option
  Future<Map<String, dynamic>> selectSlideOption({
    required String workspaceId,
    required int slideIndex,
    required String optionId,
  }) async {
    final response = await _dio.post('/api/v1/workspace/select-slide', data: {
      'workspaceId': workspaceId,
      'slideIndex': slideIndex,
      'optionId': optionId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get combined presentation JSON (SVG + metadata) from GenOffice workspace
  Future<Map<String, dynamic>> getWorkspacePresentation({
    required String workspaceId,
  }) async {
    final response = await _dio.get(
      '/api/v1/workspace/presentation',
      queryParameters: {'workspaceId': workspaceId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Import PPTX bytes into a GenOffice workspace (base64-encoded)
  Future<Map<String, dynamic>> importPptx({
    required String workspaceId,
    required List<int> pptxBytes,
  }) async {
    final sizeKb = (pptxBytes.length / 1024).toStringAsFixed(1);
    debugPrint('📤 [DocuCraft → GenOffice] Upload PPTX to workspace $workspaceId: ${pptxBytes.length} bytes ($sizeKb KB)');
    final base64Pptx = base64Encode(pptxBytes);
    final response = await _dio.post(
      '/api/v1/workspace/import-pptx',
      data: {
        'workspaceId': workspaceId,
        'pptx': base64Pptx,
      },
    );
    debugPrint('📤 [DocuCraft → GenOffice] Upload response: ${response.statusCode} - ${response.data}');
    return response.data as Map<String, dynamic>;
  }

  /// Get current run status
  Future<Map<String, dynamic>> getRunStatus(String workspaceId) async {
    final response = await _dio.get('/api/v1/workspace/run/status',
        queryParameters: {'workspaceId': workspaceId});
    return response.data as Map<String, dynamic>;
  }

  // ── Project Context Management ──

  Future<Map<String, dynamic>> initProject({
    required String projectId,
    required String topic,
  }) async {
    final response = await _dio.post('/api/v1/project/init', data: {
      'projectId': projectId,
      'topic': topic,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProject({
    required String projectId,
    Map<String, dynamic>? styleSkill,
    List<Map<String, dynamic>>? outline,
    int? currentSlideIndex,
  }) async {
    final response = await _dio.post('/api/v1/project/update', data: {
      'projectId': projectId,
      if (styleSkill != null) 'styleSkill': styleSkill,
      if (outline != null) 'outline': outline,
      if (currentSlideIndex != null) 'currentSlideIndex': currentSlideIndex,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addSlideToProject({
    required String projectId,
    required Map<String, dynamic> slide,
  }) async {
    final response = await _dio.post('/api/v1/project/add-slide', data: {
      'projectId': projectId,
      'slide': slide,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProject(String projectId) async {
    final response = await _dio.post('/api/v1/project/get', data: {
      'projectId': projectId,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── AI Feedback Loop ──

  Future<String> refineSlide({
    required String projectId,
    required int slideIndex,
    required String svg,
    required String feedback,
  }) async {
    final response = await _dio.post('/api/v1/ai/refine-slide', data: {
      'projectId': projectId,
      'slideIndex': slideIndex,
      'svg': svg,
      'feedback': feedback,
    });
    return response.data['svg'] as String;
  }

  Future<String> regenerateSlide({
    required String projectId,
    required int slideIndex,
  }) async {
    final response = await _dio.post('/api/v1/ai/regenerate-slide', data: {
      'projectId': projectId,
      'slideIndex': slideIndex,
    });
    return response.data['svg'] as String;
  }
}

// ═══════════════════════════════════════════════════════════════
// WEBSOCKET FOR REAL-TIME PROGRESS
// ═══════════════════════════════════════════════════════════════

class GenOfficeWebSocket {
  final String baseUrl;
  WebSocketChannel? _channel;
  bool _disposed = false;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  GenOfficeWebSocket({String? baseUrl})
      : baseUrl = baseUrl ?? Endpoints.backend;

  Stream<Map<String, dynamic>> get onProgress => _controller.stream;

  Future<void> connect() async {
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws'));

    _channel!.stream.listen(
      (data) {
        final event = jsonDecode(data.toString()) as Map<String, dynamic>;
        _controller.add(event);
      },
      onDone: () {
        if (!_disposed && !_controller.isClosed) _controller.close();
      },
      onError: (error) {
        _controller.addError(error);
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    if (!_controller.isClosed) _controller.close();
  }
}

// ═══════════════════════════════════════════════════════════════
// THIN UI EVENT MODELS
// ═══════════════════════════════════════════════════════════════

class ThinUiOutlineOption {
  final String id;
  final String title;
  final int slides;

  ThinUiOutlineOption({required this.id, required this.title, required this.slides});

  factory ThinUiOutlineOption.fromJson(Map<String, dynamic> json) {
    return ThinUiOutlineOption(
      id: json['id'] as String,
      title: json['title'] as String,
      slides: json['slides'] as int,
    );
  }
}

class ThinUiStyleOption {
  final String id;
  final String name;
  final String primaryColor;
  final String overallStyle;

  ThinUiStyleOption({required this.id, required this.name, required this.primaryColor, required this.overallStyle});

  factory ThinUiStyleOption.fromJson(Map<String, dynamic> json) {
    final preview = json['preview'] as Map<String, dynamic>? ?? {};
    return ThinUiStyleOption(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryColor: preview['primaryColor'] as String? ?? '#6366F1',
      overallStyle: preview['overallStyle'] as String? ?? 'Modern',
    );
  }
}

class ThinUiSlideOption {
  final String id;
  final String svg;
  final String style;

  ThinUiSlideOption({required this.id, required this.svg, required this.style});

  factory ThinUiSlideOption.fromJson(Map<String, dynamic> json) {
    return ThinUiSlideOption(
      id: json['id'] as String,
      svg: json['svg'] as String,
      style: json['style'] as String,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// THIN UI STATE (events from GenOffice WebSocket)
// ═══════════════════════════════════════════════════════════════

enum ThinUiStage { idle, outline, style, slide, progress, done, error }

class ThinUiState {
  final ThinUiStage stage;
  final String? workspaceId;
  final String? topic;
  final List<ThinUiOutlineOption> outlineOptions;
  final List<ThinUiStyleOption> styleOptions;
  final List<ThinUiSlideOption> slideOptions;
  final int? currentSlideIndex;
  final int? totalSlides;
  final String? pptxUrl;
  final String? error;
  final String? message;
  final int? done;
  final int? total;
  final String? stageName;
  final List<String>? slides; // PNG base64 per page (when available from deck-ready)
  final List<String>? svgs; // SVG structure per page (legacy — Konva toSVG, unreliable)
  final List<String>? editableJson; // flat editable structure per page (primary — parsed to SlideElements)
  final int? slideWidth; // Original slide canvas width in px (e.g., 1280)
  final int? slideHeight; // Original slide canvas height in px (e.g., 720)

  ThinUiState({
    this.stage = ThinUiStage.idle,
    this.workspaceId,
    this.topic,
    this.outlineOptions = const [],
    this.styleOptions = const [],
    this.slideOptions = const [],
    this.currentSlideIndex,
    this.totalSlides,
    this.pptxUrl,
    this.error,
    this.message,
    this.done,
    this.total,
    this.stageName,
    this.slides,
    this.svgs,
    this.editableJson,
    this.slideWidth,
    this.slideHeight,
  });

  ThinUiState copyWith({
    ThinUiStage? stage,
    String? workspaceId,
    String? topic,
    List<ThinUiOutlineOption>? outlineOptions,
    List<ThinUiStyleOption>? styleOptions,
    List<ThinUiSlideOption>? slideOptions,
    int? currentSlideIndex,
    int? totalSlides,
    String? pptxUrl,
    String? error,
    String? message,
    int? done,
    int? total,
    String? stageName,
    List<String>? slides,
    List<String>? svgs,
    List<String>? editableJson,
    int? slideWidth,
    int? slideHeight,
  }) {
    return ThinUiState(
      stage: stage ?? this.stage,
      workspaceId: workspaceId ?? this.workspaceId,
      topic: topic ?? this.topic,
      outlineOptions: outlineOptions ?? this.outlineOptions,
      styleOptions: styleOptions ?? this.styleOptions,
      slideOptions: slideOptions ?? this.slideOptions,
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      totalSlides: totalSlides ?? this.totalSlides,
      pptxUrl: pptxUrl ?? this.pptxUrl,
      error: error ?? this.error,
      message: message ?? this.message,
      done: done ?? this.done,
      total: total ?? this.total,
      stageName: stageName ?? this.stageName,
      slides: slides ?? this.slides,
      svgs: svgs ?? this.svgs,
      editableJson: editableJson ?? this.editableJson,
      slideWidth: slideWidth ?? this.slideWidth,
      slideHeight: slideHeight ?? this.slideHeight,
    );
  }

  /// Parse a WebSocket event into ThinUiState changes
  static ThinUiState? fromEvent(Map<String, dynamic> event, ThinUiState current) {
    final type = event['type'] as String?;
    final data = event['data'] as Map<String, dynamic>? ?? {};
    final workspaceId = event['workspaceId'] as String?;

    switch (type) {
      case 'outline-options':
        final outlines = (data['outlines'] as List?)
                ?.map((e) => ThinUiOutlineOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return current.copyWith(
          stage: ThinUiStage.outline,
          workspaceId: workspaceId,
          topic: data['topic'] as String?,
          outlineOptions: outlines,
        );

      case 'style-options':
        final styles = (data['styles'] as List?)
                ?.map((e) => ThinUiStyleOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return current.copyWith(
          stage: ThinUiStage.style,
          workspaceId: workspaceId,
          styleOptions: styles,
        );

      case 'slide-options':
        final options = (data['options'] as List?)
                ?.map((e) => ThinUiSlideOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return current.copyWith(
          stage: ThinUiStage.slide,
          workspaceId: workspaceId,
          slideOptions: options,
          currentSlideIndex: data['slideIndex'] as int?,
          totalSlides: data['totalSlides'] as int?,
          message: data['title'] as String?,
        );

      case 'deck-progress':
        // Map GenOffice deck progress stage to Flutter ThinUiStage
        final progressStage = data['stage'] as String?;
        ThinUiStage? mappedStage;
        switch (progressStage) {
          case 'plan':
            mappedStage = ThinUiStage.outline;
            break;
          case 'style':
            mappedStage = ThinUiStage.style;
            break;
          case 'images':
            mappedStage = ThinUiStage.progress;
            break;
          case 'pages':
            mappedStage = ThinUiStage.slide;
            break;
          case 'done':
            mappedStage = ThinUiStage.done;
            break;
        }
        return current.copyWith(
          stage: mappedStage,
          workspaceId: workspaceId,
          done: data['done'] as int?,
          total: data['total'] as int?,
          stageName: data['stageName'] as String?,
        );

      case 'deck-ready':
        return current.copyWith(
          stage: ThinUiStage.done,
          workspaceId: workspaceId,
          pptxUrl: data['pptxUrl'] as String?,
          message: data['message'] as String?,
          slides: (data['slides'] as List?)?.cast<String>(),
          svgs: (data['svgs'] as List?)?.cast<String>(),
          editableJson: (data['editableJson'] as List?)?.cast<String>(),
          slideWidth: (data['slideWidth'] as num?)?.round(),
          slideHeight: (data['slideHeight'] as num?)?.round(),
        );

      case 'deck-error':
        return current.copyWith(
          stage: ThinUiStage.error,
          workspaceId: workspaceId,
          error: event['error'] as String? ?? data['error'] as String?,
        );

      default:
        return null;
    }
  }
}

/// Manager for Thin UI state from WebSocket events
class ThinUiStateManager {
  final GenOfficeWebSocket _ws;
  ThinUiState _state = ThinUiState();
  StreamSubscription? _subscription;
  final StreamController<ThinUiState> _stateController = StreamController<ThinUiState>.broadcast();

  ThinUiStateManager(this._ws);

  Stream<ThinUiState> get onStateChange => _stateController.stream;
  ThinUiState get currentState => _state;

  void startListening() {
    _subscription?.cancel();
    _subscription = _ws.onProgress.listen((event) {
      final newState = ThinUiState.fromEvent(event, _state);
      if (newState != null) {
        _state = newState;
        _stateController.add(_state);
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void reset() {
    _state = ThinUiState();
    _stateController.add(_state);
  }

  void dispose() {
    stopListening();
    _stateController.close();
  }
}
