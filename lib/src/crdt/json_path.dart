// DocuCraft CRDT — JSONPath Query
// Port dari loro-js: jsonpath.ts

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'id.dart';
import 'container.dart';
import 'doc.dart';
import 'diff.dart';

/// JSONPath query result
class JsonPathResult {
  final List<dynamic> values;
  final List<ContainerID> containerIds;
  final List<List<String>> paths;

  JsonPathResult({required this.values, required this.containerIds, required this.paths});

  bool get isEmpty => values.isEmpty;

  @override
  String toString() => 'JsonPathResult{$values.length values}';
}

/// JSONPath evaluator for CRDT documents
class JsonPathEvaluator {
  final CRDTDocument _doc;

  JsonPathEvaluator(this._doc);

  /// Evaluate JSONPath expression on document
  JsonPathResult evaluate(String path) {
    if (!path.startsWith('\$')) {
      throw ArgumentError('JSONPath must start with \$');
    }

    // Parse path
    final tokens = _tokenize(path.substring(1)); // Remove leading $
    if (tokens.isEmpty) {
      // Root - return entire document
      return JsonPathResult(
        values: [_doc.getDeepValue()],
        containerIds: [],
        paths: [[]],
      );
    }

    // Start from root containers
    var currentValues = <dynamic>[_doc.getDeepValue()];
    var currentPaths = <List<String>>[[]];
    var currentContainerIds = <ContainerID?>[null];

    for (final token in tokens) {
      final nextValues = <dynamic>[];
      final nextPaths = <List<String>>[];
      final nextContainerIds = <ContainerID?>[];

      for (int i = 0; i < currentValues.length; i++) {
        final value = currentValues[i];
        final path = currentPaths[i];
        final containerId = currentContainerIds[i];

        final results = _evaluateToken(value, token, path, containerId);
        nextValues.addAll(results.values);
        nextPaths.addAll(results.paths);
        nextContainerIds.addAll(results.containerIds);
      }

      currentValues = nextValues;
      currentPaths = nextPaths;
      currentContainerIds = nextContainerIds;

      if (currentValues.isEmpty) break;
    }

    return JsonPathResult(
      values: currentValues,
      containerIds: currentContainerIds.whereType<ContainerID>().toList(),
      paths: currentPaths,
    );
  }

  _TokenResult _evaluateToken(dynamic value, _PathToken token, List<String> path, ContainerID? containerId) {
    final allValues = <dynamic>[];
    final allPaths = <List<String>>[];
    final allContainerIds = <ContainerID?>[];

    void addResult(dynamic val, List<String> p, ContainerID? cid) {
      allValues.add(val);
      allPaths.add(p);
      allContainerIds.add(cid);
    }

    switch (token.type) {
      case _PathTokenType.property:
        if (value is Map) {
          if (value.containsKey(token.name)) {
            addResult(value[token.name], path + [token.name!], containerId);
          } else if (token.name == '*') {
            // Wildcard - all properties
            for (final entry in value.entries) {
              addResult(entry.value, path + [entry.key], containerId);
            }
          }
        } else if (value is CRDTMap) {
          if (value.containsKey(token.name!)) {
            addResult(value.get(token.name!), path + [token.name!], containerId);
          }
        }
        break;

      case _PathTokenType.indexToken:
        if (value is List) {
          final index = token.idx;
          if (index != null && index >= 0 && index < value.length) {
            addResult(value[index], path + [index.toString()], containerId);
          } else if (index == -1) {
            // Last element
            if (value.isNotEmpty) {
              addResult(value.last, path + [(value.length - 1).toString()], containerId);
            }
          }
        } else if (value is CRDTList || value is CRDTMovableList) {
          final len = value.length;
          final idx = token.idx! >= 0 ? token.idx! : len + token.idx!;
          if (idx >= 0 && idx < len) {
            addResult(value.get(idx), path + [idx.toString()], containerId);
          }
        }
        break;

      case _PathTokenType.slice:
        if (value is List) {
          final start = token.start ?? 0;
          final end = token.end ?? value.length;
          final slice = value.sublist(start.clamp(0, value.length), end.clamp(0, value.length));
          addResult(slice, path + ['[$start:$end]'], containerId);
        }
        break;

      case _PathTokenType.recursiveDescent:
        // Recursively search all descendants
        _recursiveDescentCollect(value, token.next!, path, containerId, allValues, allPaths, allContainerIds);
        break;

      case _PathTokenType.filter:
        // Filter expression - simplified
        if (value is List) {
          for (int i = 0; i < value.length; i++) {
            if (_matchesFilter(value[i], token.filter!)) {
              addResult(value[i], path + [i.toString()], containerId);
            }
          }
        }
        break;

      case _PathTokenType.wildcard:
        // Wildcard - all properties/elements
        if (value is Map) {
          for (final entry in value.entries) {
            addResult(entry.value, path + [entry.key], containerId);
          }
        } else if (value is List) {
          for (int i = 0; i < value.length; i++) {
            addResult(value[i], path + [i.toString()], containerId);
          }
        } else if (value is CRDTMap) {
          for (final entry in value.entries) {
            addResult(entry.value, path + [entry.key], containerId);
          }
        } else if (value is CRDTList || value is CRDTMovableList) {
          for (int i = 0; i < value.length; i++) {
            addResult(value.get(i), path + [i.toString()], containerId);
          }
        }
        break;
    }

    return _TokenResult(
      values: allValues,
      paths: allPaths,
      containerIds: allContainerIds,
    );
  }

  void _recursiveDescentCollect(dynamic value, _PathToken nextToken, List<String> path, ContainerID? containerId,
      List<dynamic> allValues, List<List<String>> allPaths, List<ContainerID?> allContainerIds) {
    if (value is Map) {
      for (final entry in value.entries) {
        _recursiveDescentCollect(entry.value, nextToken, path + [entry.key], containerId, allValues, allPaths, allContainerIds);
      }
    } else if (value is List) {
      for (int i = 0; i < value.length; i++) {
        _recursiveDescentCollect(value[i], nextToken, path + [i.toString()], containerId, allValues, allPaths, allContainerIds);
      }
    } else if (value is CRDTMap) {
      for (final entry in value.entries) {
        _recursiveDescentCollect(entry.value, nextToken, path + [entry.key], containerId, allValues, allPaths, allContainerIds);
      }
    } else if (value is CRDTList || value is CRDTMovableList) {
      for (int i = 0; i < value.length; i++) {
        _recursiveDescentCollect(value.get(i), nextToken, path + [i.toString()], containerId, allValues, allPaths, allContainerIds);
      }
    }
    // Also check current value
    final nextResults = _evaluateToken(value, nextToken, path, containerId);
    allValues.addAll(nextResults.values);
    allPaths.addAll(nextResults.paths);
    allContainerIds.addAll(nextResults.containerIds);
  }

  List<_PathToken> _tokenize(String path) {
    final tokens = <_PathToken>[];
    int i = 0;

    while (i < path.length) {
      final c = path[i];

      if (c == '.') {
        i++;
        // Property access
        if (i < path.length && path[i] == '*') {
          tokens.add(_PathToken(_PathTokenType.property, name: '*'));
          i++;
        } else {
          final start = i;
          while (i < path.length && !['.', '[', ']'].contains(path[i])) {
            i++;
          }
          tokens.add(_PathToken(_PathTokenType.property, name: path.substring(start, i)));
        }
      } else if (c == '[') {
        i++;
        if (i < path.length && path[i] == '*') {
          i++;
          if (i < path.length && path[i] == ']') {
            i++;
            tokens.add(_PathToken(_PathTokenType.wildcard));
          }
        } else if (i < path.length && path[i] == '?') {
          // Filter
          i++;
          final filterStart = i;
          while (i < path.length && path[i] != ']') i++;
          final filterStr = path.substring(filterStart, i);
          tokens.add(_PathToken(_PathTokenType.filter, filter: _parseFilter(filterStr)));
          if (i < path.length && path[i] == ']') i++;
        } else {
          // Index or slice
          final start = i;
          while (i < path.length && path[i] != ']' && path[i] != ':') i++;
          final first = path.substring(start, i);

          if (i < path.length && path[i] == ':') {
            // Slice
            i++;
            final endStart = i;
            while (i < path.length && path[i] != ']') i++;
            final endStr = path.substring(endStart, i);
            tokens.add(_PathToken(
              _PathTokenType.slice,
              start: int.tryParse(first) ?? 0,
              end: endStr.isEmpty ? null : int.tryParse(endStr),
            ));
          } else {
            // Single index
            tokens.add(_PathToken(_PathTokenType.indexToken, idx: int.tryParse(first) ?? 0));
          }
          if (i < path.length && path[i] == ']') {
            i++;
          }
        }
      } else if (c == '*' && i + 1 < path.length && path[i + 1] == '*') {
        // Recursive descent **
        tokens.add(_PathToken(_PathTokenType.recursiveDescent));
        i += 2;
      } else {
        i++;
      }
    }

    return tokens;
  }

  _FilterExpr? _parseFilter(String str) {
    // Simplified: field == value
    final match = RegExp(r'(\w+)\s*(==|!=|>|<|>=|<=)\s*(.+)').firstMatch(str);
    if (match != null) {
      return _FilterExpr(
        field: match.group(1)!,
        operator: match.group(2)!,
        value: _parseValue(match.group(3)!),
      );
    }
    return null;
  }

  dynamic _parseValue(String str) {
    str = str.trim();
    if (str.startsWith('"') && str.endsWith('"')) return str.substring(1, str.length - 1);
    if (str.startsWith("'") && str.endsWith("'")) return str.substring(1, str.length - 1);
    if (str == 'true') return true;
    if (str == 'false') return false;
    if (str == 'null') return null;
    return num.tryParse(str) ?? str;
  }

  bool _matchesFilter(dynamic value, _FilterExpr filter) {
    if (value is! Map) return false;
    final fieldValue = value[filter.field];
    switch (filter.operator) {
      case '==':
        return fieldValue == filter.value;
      case '!=':
        return fieldValue != filter.value;
      case '>':
        return (fieldValue as num) > (filter.value as num);
      case '<':
        return (fieldValue as num) < (filter.value as num);
      case '>=':
        return (fieldValue as num) >= (filter.value as num);
      case '<=':
        return (fieldValue as num) <= (filter.value as num);
      case 'in':
        return (filter.value as List).contains(fieldValue);
      default:
        return false;
    }
  }
}

/// Path token types
enum _PathTokenType {
  property,
  indexToken,
  slice,
  wildcard,
  recursiveDescent,
  filter,
}

/// Path token
class _PathToken {
  final _PathTokenType type;
  final String? name;
  final int? idx;
  final int? start;
  final int? end;
  final _FilterExpr? filter;
  _PathToken? next;

  _PathToken(
    this.type, {
    this.name,
    this.idx,
    this.start,
    this.end,
    this.filter,
  });
}

/// Filter expression
class _FilterExpr {
  final String field;
  final String operator;
  final dynamic value;

  _FilterExpr({required this.field, required this.operator, required this.value});
}

/// Token evaluation result
class _TokenResult {
  final List<dynamic> values;
  final List<List<String>> paths;
  final List<ContainerID?> containerIds;

  _TokenResult({
    required this.values,
    required this.paths,
    required this.containerIds,
  });
}

/// JSONPath subscription callback
typedef JsonPathCallback = void Function(JsonPathResult result);

/// JSONPath subscription for reactive queries
class JsonPathSubscription {
  final CRDTDocument _doc;
  final String _path;
  final JsonPathCallback _callback;
  final JsonPathEvaluator _evaluator;
  Timer? _timer;

  JsonPathSubscription(this._doc, this._path, this._callback)
      : _evaluator = JsonPathEvaluator(_doc) {
    _evaluate();
  }

  void _evaluate() {
    try {
      final result = _evaluator.evaluate(_path);
      _callback(result);
    } catch (e) {
      // Ignore evaluation errors
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}