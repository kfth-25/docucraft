// DocuCraft Flutter — HttpChatTransport tests (Sprint 13)
//
// Unit tests for the SSE/XML parsers and body encoding. The transport's
// real HTTP path is exercised through a mock http.Client.

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:docucraft_app/agent_core/agent_core.dart';
import 'package:docucraft_app/agent_core/http_chat_transport.dart';

void main() {
  group('XmlToolParser', () {
    test('extracts a single tool call from a single delta', () {
      final p = XmlToolParser();
      final calls = p.feed('<tool_call>{"name":"echo","arguments":{"msg":"hi"}}</tool_call>');
      expect(calls.length, 1);
      expect(calls.first.name, 'echo');
      expect(calls.first.input, {'msg': 'hi'});
    });

    test('extracts a tool call split across multiple deltas', () {
      final p = XmlToolParser();
      p.feed('Prose before <tool_call>{"na');
      p.feed('me":"ec');
      final calls = p.feed('ho","arguments":{"msg":"x"}}</tool_call> prose after');
      expect(calls.length, 1);
      expect(calls.first.name, 'echo');
      expect(calls.first.input, {'msg': 'x'});
    });

    test('skips malformed JSON silently', () {
      final p = XmlToolParser();
      final calls = p.feed('<tool_call>not json</tool_call>');
      expect(calls, isEmpty);
    });

    test('returns no call when name is missing', () {
      final p = XmlToolParser();
      final calls = p.feed('<tool_call>{"arguments":{}}</tool_call>');
      expect(calls, isEmpty);
    });

    test('extracts multiple tool calls in one delta', () {
      final p = XmlToolParser();
      final calls = p.feed(
          '<tool_call>{"name":"a","arguments":{"x":1}}</tool_call><tool_call>{"name":"b","arguments":{"y":2}}</tool_call>');
      expect(calls.length, 2);
      expect(calls.map((c) => c.name).toSet(), {'a', 'b'});
    });
  });

  group('HttpChatTransport.buildBody', () {
    test('encodes system + user messages', () {
      final t = HttpChatTransport(config: _config());
      final body = t.buildBody(AgentStreamRequest(
        system: 'sys',
        messages: [const AgentUserMessage(text: 'hello')],
        tools: const [],
      ));
      expect(body['model'], 'test-model');
      final messages = body['messages'] as List;
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');
      expect(body['stream'], true);
    });

    test('encodes assistant tool calls back into the history', () {
      final t = HttpChatTransport(config: _config());
      final body = t.buildBody(AgentStreamRequest(
        system: 'sys',
        messages: const [
          AgentAssistantMessage(
            text: 'ok',
            toolCalls: [AgentToolCall(id: '1', name: 'x', input: {'k': 'v'})],
          ),
          AgentToolMessage(results: [AgentToolResult(id: '1', name: 'x', output: 'out')]),
        ],
        tools: const [],
      ));
      final messages = body['messages'] as List;
      expect(messages[1]['role'], 'assistant');
      expect(messages[1]['tool_calls'], isA<List>());
      expect(messages[2]['role'], 'tool');
    });

    test('emits tool_choice=auto when tools are non-empty', () {
      final t = HttpChatTransport(config: _config());
      final body = t.buildBody(AgentStreamRequest(
        system: 'sys',
        messages: const [AgentUserMessage(text: 'x')],
        tools: const [
          AgentToolDef(name: 't', description: 'd', inputSchema: {}),
        ],
      ));
      expect(body['tools'], isA<List>());
      expect(body['tool_choice'], 'auto');
    });
  });

  group('HttpChatTransport.stream', () {
    test('parses OpenAI-style delta + tool_calls across chunks', () async {
      final chunks = <String>[
        'data: ' +
            jsonEncode({
              'choices': [
                {
                  'delta': {
                    'content': 'Hello, ',
                    'tool_calls': [
                      {'index': 0, 'id': 'c1', 'function': {'name': 'echo', 'arguments': '{"msg":'}}
                    ]
                  }
                }
              ]
            }),
        'data: ' +
            jsonEncode({
              'choices': [
                {
                  'delta': {
                    'content': 'world!',
                    'tool_calls': [
                      {'index': 0, 'function': {'arguments': '"ping"}'}}
                    ]
                  },
                  'finish_reason': 'tool_calls',
                }
              ]
            }),
        'data: [DONE]',
      ];
      final mock = MockClient((req) async {
        return http.Response(chunks.join('\n'), 200,
            headers: {'content-type': 'text/event-stream'});
      });
      final t = HttpChatTransport(config: _config(), client: mock);
      final deltas = <String>[];
      final calls = <AgentToolCall>[];
      final doneCompleter = Completer<void>();
      t.stream(
        AgentStreamRequest(system: 's', messages: const [], tools: const []),
        AgentStreamCallbacks(
          onDelta: deltas.add,
          onToolCall: calls.add,
          onDone: () {
            if (!doneCompleter.isCompleted) doneCompleter.complete();
          },
          onError: (e) {
            if (!doneCompleter.isCompleted) doneCompleter.complete();
          },
        ),
      );
      await doneCompleter.future;
      // Wait one microtask for any trailing events.
      await Future<void>.delayed(Duration.zero);
      expect(deltas.join(), 'Hello, world!');
      expect(calls.length, 1);
      expect(calls.first.name, 'echo');
      expect(calls.first.input, {'msg': 'ping'});
    });

    test('falls back to XML tool calls when content has inline <tool_call>', () async {
      final xmlPayload = 'data: ' +
          jsonEncode({
            'choices': [
              {
                'delta': {
                  'content':
                      'A: <tool_call>{"name":"x","arguments":{"a":1}}</tool_call> done',
                }
              }
            ]
          });
      final mock = MockClient((req) async {
        return http.Response('$xmlPayload\n', 200);
      });
      final t = HttpChatTransport(config: _config(), client: mock);
      final deltas = <String>[];
      final calls = <AgentToolCall>[];
      final doneCompleter = Completer<void>();
      t.stream(
        AgentStreamRequest(system: 's', messages: const [], tools: const []),
        AgentStreamCallbacks(
          onDelta: deltas.add,
          onToolCall: calls.add,
          onDone: () {
            if (!doneCompleter.isCompleted) doneCompleter.complete();
          },
          onError: (e) {
            if (!doneCompleter.isCompleted) doneCompleter.complete();
          },
        ),
      );
      await doneCompleter.future;
      expect(deltas.join(), contains('A:'));
      expect(deltas.join(), contains('done'));
      expect(calls.length, 1);
      expect(calls.first.name, 'x');
      expect(calls.first.input, {'a': 1});
    });
  });
}

HttpChatTransportConfig _config() => const HttpChatTransportConfig(
      baseUrl: 'http://localhost:20128/v1',
      apiKey: 'test',
      defaultModel: 'test-model',
    );
