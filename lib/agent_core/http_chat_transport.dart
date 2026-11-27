// DocuCraft Flutter — HttpChatTransport (Sprint 13)
//
// Transport `/chat/completions` kompatibel OpenAI dengan streaming SSE.
// Memakai ulang baseUrl + apiKey yang sama dengan `AiGenerationService`
// sehingga transport interoperabel dengan proxy lokal 9router / LiteLLM
// yang sudah ada.
//
// Mencerminkan *bentuk* `electron-transport.ts` GenOffice:
//   - Body request JSON yang sama (`model`, `messages`, `tools`, `stream`).
//   - Callback yang sama: `onDelta` per chunk, `onToolCall` sekali per tool
//     call yang selesai, `onDone` di akhir stream, `onError` saat gagal.
//   - Mentolerir dua format wire untuk tool call:
//       (a) OpenAI native: array `choices[0].delta.tool_calls` (string
//           `function.arguments` per-chunk di-concatenate lalu di-JSON-parse
//           saat selesai).
//       (b) XML inline: blok teks `<tool_call>{...}</tool_call>` (beberapa
//           proxy lokal menormalisasi ke format ini). Di-parse via [XmlToolParser].

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'types.dart';

class HttpChatTransportConfig {
  final String baseUrl;
  final String apiKey;
  final String? defaultModel;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  const HttpChatTransportConfig({
    required this.baseUrl,
    required this.apiKey,
    this.defaultModel,
    this.maxTokens = 8192,
    this.temperature = 0.7,
    this.timeout = const Duration(minutes: 5),
  });
}

class HttpChatTransport implements AgentTransport {
  final HttpChatTransportConfig config;
  final http.Client _client;

  HttpChatTransport({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  void close() => _client.close();

  @override
  AgentStreamHandle stream(AgentStreamRequest request, AgentStreamCallbacks cb) {
    final handle = _SseStreamHandle();
    handle._run(config, request, cb, _client);
    return handle;
  }

  /// Build the JSON body for `/chat/completions`. Exposed for tests.
  Map<String, dynamic> buildBody(AgentStreamRequest request) {
    final model = config.defaultModel ?? 'kc/nvidia/nemotron-3-super-120b-a12b:free';
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': request.system},
      ...request.messages.map(_encodeMessage),
    ];
    return {
      'model': model,
      'messages': messages,
      if (request.tools.isNotEmpty) 'tools': request.tools.map(_encodeTool).toList(),
      if (request.tools.isNotEmpty) 'tool_choice': 'auto',
      'max_tokens': config.maxTokens,
      'temperature': config.temperature,
      'stream': true,
    };
  }

  Map<String, dynamic> _encodeMessage(AgentMessage m) {
    if (m is AgentUserMessage) {
      return {'role': 'user', 'content': m.text};
    }
    if (m is AgentAssistantMessage) {
      return {
        'role': 'assistant',
        'content': m.text,
        if (m.toolCalls != null && m.toolCalls!.isNotEmpty)
          'tool_calls': m.toolCalls!.map(_encodeToolCall).toList(),
      };
    }
    if (m is AgentToolMessage) {
      return {
        'role': 'tool',
        'content': m.results.map((r) => {
              'tool_call_id': r.id,
              'name': r.name,
              'content': r.output,
            }).toList(),
      };
    }
    return {'role': 'user', 'content': ''};
  }

  Map<String, dynamic> _encodeTool(AgentToolDef t) => {
        'type': 'function',
        'function': {
          'name': t.name,
          'description': t.description,
          'parameters': t.inputSchema,
        },
      };

  Map<String, dynamic> _encodeToolCall(AgentToolCall c) => {
        'id': c.id,
        'type': 'function',
        'function': {
          'name': c.name,
          'arguments': jsonEncode(c.input),
        },
      };
}

/// Internal handle that owns the in-flight HTTP request and a
/// `_ToolCallAccumulator` for the OpenAI-style `tool_calls` array.
class _SseStreamHandle implements AgentStreamHandle {
  bool _cancelled = false;
  http.Client? _activeClient;

  void _run(
    HttpChatTransportConfig config,
    AgentStreamRequest request,
    AgentStreamCallbacks cb,
    http.Client client,
  ) {
    final transport = HttpChatTransport(config: config);
    final body = transport.buildBody(request);

    _activeClient = client;
    final uri = Uri.parse('${config.baseUrl}/chat/completions');

    _activeClient!
        .post(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
          'Accept': 'text/event-stream',
        }, body: jsonEncode(body))
        .timeout(config.timeout)
        .then((response) {
      if (response.statusCode != 200) {
        // Parse error response for user-friendly messages
        String errorDetail = response.body;
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          if (json['error'] is Map) {
            errorDetail = json['error']['message'] ?? errorDetail;
          }
        } catch (_) {}

        String userMessage;
        switch (response.statusCode) {
          case 429:
            userMessage = 'Rate Limited (429): Too many requests. '
                'Tunggu sebentar dan coba lagi.';
            break;
          case 401:
          case 403:
            userMessage = 'Auth Error (${response.statusCode}): API key tidak valid atau expired.';
            break;
          case 404:
            userMessage = 'Not Found (404): Endpoint tidak tersedia. '
                'Cek konfigurasi baseUrl.';
            break;
          case 500:
          case 502:
          case 503:
            userMessage = 'Server Error (${response.statusCode}): '
                'Backend AI bermasalah. Coba beberapa saat lagi.';
            break;
          default:
            userMessage = 'HTTP ${response.statusCode}: $errorDetail';
        }
        cb.onError(userMessage);
        return;
      }
      _consumeSse(response.body, cb);
      cb.onDone();
    }).catchError((e) {
      if (!_cancelled) {
        // Provide user-friendly error messages for common issues
        final errorMsg = e.toString().toLowerCase();
        String userMessage;

        if (errorMsg.contains('cors') || errorMsg.contains('access-control') || errorMsg.contains('blocked')) {
          userMessage = 'CORS Error: Server tidak mengizinkan request dari browser. '
              'Pastikan 9Router sudah jalan atau gunakan proxy.';
        } else if (errorMsg.contains('connection') || errorMsg.contains('refused') || errorMsg.contains('timeout')) {
          userMessage = 'Connection Error: Tidak dapat terhubung ke server AI. '
              'Pastikan 9Router sudah berjalan di port 20128.';
        } else if (errorMsg.contains('network')) {
          userMessage = 'Network Error: Masalah koneksi. '
              'Cek koneksi internet dan status server.';
        } else {
          userMessage = 'Stream Error: $e';
        }

        cb.onError(userMessage);
      } else {
        cb.onDone();
      }
    });
  }

  /// Consume the full SSE body (the local proxy returns the whole body in
  /// one shot; we still parse line-by-line for forward compatibility with
  /// true chunked streams).
  void _consumeSse(String body, AgentStreamCallbacks cb) {
    final accumulator = _ToolCallAccumulator();
    final xmlParser = XmlToolParser();
    final lines = const LineSplitter().convert(body);
    for (final line in lines) {
      if (_cancelled) return;
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(payload) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('⚠️ HttpChatTransport: bad SSE line: $e');
        continue;
      }
      final choice = (json['choices'] as List?)?.firstOrNull;
      if (choice is! Map) continue;
      final delta = choice['delta'] as Map?;
      if (delta == null) continue;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        cb.onDelta(content);
        // Some proxies also emit tool calls as inline XML; scrape those too.
        for (final c in xmlParser.feed(content)) {
          cb.onToolCall(c);
        }
      }
      // Reasoning models (o1/o3/nemotron) emit thinking text in 'reasoning'
      // field while 'content' stays empty. Surface it as regular text deltas
      // so the UI shows the AI's reasoning process in real-time.
      final reasoning = delta['reasoning'];
      if (reasoning is String && reasoning.isNotEmpty) {
        cb.onDelta(reasoning);
      }
      if (delta['tool_calls'] is List) {
        for (final call in accumulator.feed(delta['tool_calls'] as List)) {
          cb.onToolCall(call);
        }
      }
      final stop = choice['finish_reason'];
      if (stop is String) cb.onStopReason?.call(stop);
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    // Do NOT close _activeClient here — it may be shared across
    // multiple AgentLoop runs (planOutline → generateDeck). The
    // client lifecycle is managed by the caller (HttpChatTransport).
  }
}

/// Stateful accumulator for OpenAI `tool_calls` deltas. Each chunk adds
/// a partial function.arguments string keyed by tool-call index. When the
/// arguments string is well-formed JSON, the call is yielded and removed
/// from the buffer.
class _ToolCallAccumulator {
  final Map<int, _PartialCall> _partials = {};

  List<AgentToolCall> feed(List<dynamic> rawCalls) {
    final completed = <AgentToolCall>[];
    for (final raw in rawCalls) {
      if (raw is! Map) continue;
      final i = (raw['index'] as num?)?.toInt() ?? 0;
      final id = raw['id'] as String?;
      final fn = raw['function'] as Map?;
      final name = fn?['name'] as String?;
      final argsDelta = fn?['arguments'] as String? ?? '';
      final p = _partials.putIfAbsent(i, () => _PartialCall(id: id, name: name));
      if (id != null) p.id = id;
      if (name != null) p.name = name;
      if (argsDelta.isNotEmpty) p.args.write(argsDelta);
      if (p.name != null) {
        final argsStr = p.args.toString();
        if (_looksComplete(argsStr)) {
          final call = _tryComplete(p, argsStr);
          if (call != null) completed.add(call);
          _partials.remove(i);
        }
      }
    }
    return completed;
  }

  bool _looksComplete(String args) {
    if (args.isEmpty) return false;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = 0; i < args.length; i++) {
      final c = args[i];
      if (escaped) { escaped = false; continue; }
      if (c == r'\\') { escaped = true; continue; }
      if (c == '"') { inString = !inString; continue; }
      if (inString) continue;
      if (c == '{') depth++;
      if (c == '}') depth--;
    }
    return depth == 0;
  }

  AgentToolCall? _tryComplete(_PartialCall p, String args) {
    try {
      final json = jsonDecode(args) as Map<String, dynamic>;
      return AgentToolCall(
        id: p.id ?? 'call-${DateTime.now().microsecondsSinceEpoch}',
        name: p.name!,
        input: json,
      );
    } catch (e) {
      debugPrint('⚠️ _ToolCallAccumulator: bad args: $e');
      return null;
    }
  }
}

class _PartialCall {
  String? id;
  String? name;
  final StringBuffer args = StringBuffer();
  _PartialCall({this.id, this.name});
}

/// Streaming `<tool_call>{...}</tool_call>` XML parser. Accumulates raw
/// text across deltas; when a closing tag is reached, the enclosed JSON
/// is parsed and the tool call is yielded. Whitespace and surrounding
/// prose are tolerated.
class XmlToolParser {
  final StringBuffer _buffer = StringBuffer();
  int _searchFrom = 0;

  /// Feed a text delta; returns any tool calls whose closing tag has
  /// already arrived.
  List<AgentToolCall> feed(String delta) {
    _buffer.write(delta);
    final completed = <AgentToolCall>[];
    while (true) {
      final haystack = _buffer.toString();
      final idx = haystack.indexOf('</tool_call>', _searchFrom);
      if (idx < 0) break;
      final openIdx = haystack.lastIndexOf('<tool_call>', idx);
      if (openIdx < 0) {
        _searchFrom = idx + '</tool_call>'.length;
        continue;
      }
      final inner = haystack.substring(openIdx + '<tool_call>'.length, idx).trim();
      _searchFrom = idx + '</tool_call>'.length;
      final call = _tryParseCall(inner);
      if (call != null) completed.add(call);
    }
    return completed;
  }

  AgentToolCall? _tryParseCall(String inner) {
    try {
      final json = jsonDecode(inner) as Map<String, dynamic>;
      final name = json['name'] as String?;
      final args = json['arguments'] ?? json['input'] ?? json;
      final id = (json['id'] as String?) ?? 'xml-${DateTime.now().microsecondsSinceEpoch}';
      if (name == null) return null;
      return AgentToolCall(
        id: id,
        name: name,
        input: args is Map<String, dynamic> ? args : {'raw': args},
      );
    } catch (e) {
      debugPrint('⚠️ XmlToolParser: failed to parse: $e');
      return null;
    }
  }
}
