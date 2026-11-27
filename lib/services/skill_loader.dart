// DocuCraft — Skill Loader Service
// Memuat file markdown skill dari asset bawaan aplikasi (assets/skills-md/)
// agar AI chat di dalam aplikasi dapat memahami seluruh kemampuan workflow PPT.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// Thrown when a skill file cannot be loaded from assets.
class SkillLoadException implements Exception {
  final String path;
  SkillLoadException(this.path);
  @override
  String toString() => 'SkillLoadException: Failed to load skill file: $path';
}

/// Loads and caches skill markdown files bundled with the app.
class SkillLoader {
  static final Map<String, String> _cache = {};

  /// Base path for all skill assets
  static const String _base = 'assets/skills-md';

  /// Load a skill file by relative path (e.g., 'workflows/routing.md')
  /// Throws [SkillLoadException] if the file cannot be loaded.
  static Future<String> load(String relativePath) async {
    final key = '$_base/$relativePath';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final content = await rootBundle.loadString(key);
      _cache[key] = content;
      return content;
    } catch (e) {
      debugPrint('⚠️ SkillLoader: Failed to load $relativePath: $e');
      throw SkillLoadException(relativePath);
    }
  }

  /// Load multiple skill files and concatenate
  static Future<String> loadMultiple(List<String> paths) async {
    final sb = StringBuffer();
    for (final path in paths) {
      sb.writeln(await load(path));
      sb.writeln('\n---\n');
    }
    return sb.toString();
  }

  /// Get the main skill entry point
  static Future<String> loadMainSkill() => load('SKILL-DOCUCRAFT.md');

  /// Get routing rules
  static Future<String> loadRouting() => load('workflows/routing.md');

  /// Get route authority for a specific route
  static Future<String> loadRoute(String routeName) => load('workflows/$routeName.md');

  /// Get profile for a specific profile name
  static Future<String> loadProfile(String profileName) => load('workflows/profiles/$profileName.md');

  /// Get stage documentation
  static Future<String> loadStage(String stageName) => load('workflows/stages/$stageName.md');

  /// Get role reference
  static Future<String> loadReference(String roleName) => load('references/$roleName.md');

  /// Build lightweight routing prompt (Call 1 — Router)
  /// Lists available workflows with short descriptions only
  /// LLM picks one based on user intent
  static Future<String> buildRoutingPrompt() async {
    return '''
You are a presentation workflow router. Based on the user's request, select exactly one workflow.

Available workflows:

1. **generate-pptx** — Create a new presentation from topic, text, or sketch
   Triggers: "buat presentasi", "buat ppt", "create presentation", "generate slide", topic-only requests

2. **create-template** — Create a reusable Brand/Style/Layout/Deck template workspace
   Triggers: "buat template", "create template", "buat brand", "buat style", reusable design requests

3. **fill-pptx** — Fill an existing PPTX template with new content (no SVG conversion)
   Triggers: "fill template", "isi template", "use this ppt", existing PPTX + new content

4. **enhance-pptx** — Add notes, audio, transitions to an existing finished PPTX
   Triggers: "enhance", "tambah audio", "add narration", "add transitions", finished PPTX improvements

5. **quick-generate** — Fast generation without interaction gates
   Triggers: "quick", "fast", "langsung", "cepat", explicit skip-strategy

6. **sketch-to-design** — Convert hand-drawn sketch to professional design
   Triggers: "coret", "sketch", "gambar", "draw", image input with drawing

Reply with ONLY the workflow name (e.g., "generate-pptx"). No explanation.
''';
  }

  /// Build full system prompt for selected route (Call 2 — Generator)
  /// Combines skill entry + route authority + role references
  static Future<String> buildSystemPrompt({
    String route = 'generate-pptx',
    bool includeReferences = true,
  }) async {
    final sb = StringBuffer();

    // 1. Main skill entry
    sb.writeln(await loadMainSkill());
    sb.writeln('\n---\n');

    // 2. Route authority (full workflow for selected route)
    sb.writeln(await load('workflows/$route.md'));
    sb.writeln('\n---\n');

    // 3. Role references
    if (includeReferences) {
      sb.writeln(await load('references/strategist.md'));
      sb.writeln('\n---\n');
      sb.writeln(await load('references/executor.md'));
    }

    return sb.toString();
  }

  /// Clear cache (useful after hot reload)
  static void clearCache() => _cache.clear();
}
