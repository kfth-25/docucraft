// DocuCraft Flutter — Deck Blueprint model (Sprint 12)
//
// A "blueprint" adalah resep tersimpan yang dipakai untuk generate deck
// lengkap: topik + gaya + outline. User bisa menjalankan ulang atau
// melakukan fork blueprint tersimpan dari layar BlueprintPicker.
//
// Ini POJO immutable dengan copyWith + JSON. Persistence dilakukan lewat
// [DeckBlueprintStorage] yang memakai Hive Box<Map> mentah.

import 'dart:convert';

/// A saved DocuCraft deck blueprint.
class DeckBlueprint {
  /// Stable id (e.g. "bp-abc123"). Used as the Hive key.
  final String id;

  /// Human-readable name (defaults to first 80 chars of topic).
  final String name;

  /// The user's original prompt / topic.
  final String topic;

  /// Optional style skill identifier (e.g. "modern", "neo-swift").
  final String? styleSkill;

  /// Optional serialized outline JSON (object with `pages` array).
  final String? outlineJson;

  /// Page count when this blueprint was saved.
  final int? pageCount;

  /// ISO 8601 created-at timestamp.
  final String createdAt;

  /// Optional source path of the .pptx (if any).
  final String? sourcePath;

  /// Sprint 10 lineage: id of the parent blueprint this was forked from.
  final String? forkedFrom;

  const DeckBlueprint({
    required this.id,
    required this.name,
    required this.topic,
    this.styleSkill,
    this.outlineJson,
    this.pageCount,
    required this.createdAt,
    this.sourcePath,
    this.forkedFrom,
  });

  DeckBlueprint copyWith({
    String? id,
    String? name,
    String? topic,
    String? styleSkill,
    String? outlineJson,
    int? pageCount,
    String? createdAt,
    String? sourcePath,
    String? forkedFrom,
  }) {
    return DeckBlueprint(
      id: id ?? this.id,
      name: name ?? this.name,
      topic: topic ?? this.topic,
      styleSkill: styleSkill ?? this.styleSkill,
      outlineJson: outlineJson ?? this.outlineJson,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      sourcePath: sourcePath ?? this.sourcePath,
      forkedFrom: forkedFrom ?? this.forkedFrom,
    );
  }

  /// Serialize to a JSON-safe map for Hive (which accepts `Map<dynamic, dynamic>`
  /// or `Map<String, dynamic>`).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'topic': topic,
        if (styleSkill != null) 'styleSkill': styleSkill,
        if (outlineJson != null) 'outlineJson': outlineJson,
        if (pageCount != null) 'pageCount': pageCount,
        'createdAt': createdAt,
        if (sourcePath != null) 'sourcePath': sourcePath,
        if (forkedFrom != null) 'forkedFrom': forkedFrom,
      };

  /// Inverse of [toJson]. Tolerant of missing optional fields. Returns null
  /// if the map is missing the required `id` field.
  static DeckBlueprint? fromJson(Map? raw) {
    if (raw == null) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    return DeckBlueprint(
      id: id,
      name: (raw['name'] as String?) ?? id,
      topic: (raw['topic'] as String?) ?? '',
      styleSkill: raw['styleSkill'] as String?,
      outlineJson: raw['outlineJson'] as String?,
      pageCount: (raw['pageCount'] as num?)?.toInt(),
      createdAt: (raw['createdAt'] as String?) ?? '',
      sourcePath: raw['sourcePath'] as String?,
      forkedFrom: raw['forkedFrom'] as String?,
    );
  }

  /// Pretty-print for debug logs.
  @override
  String toString() => 'DeckBlueprint(${jsonEncode(toJson())})';
}
