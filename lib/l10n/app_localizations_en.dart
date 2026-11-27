// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DocuCraft';

  @override
  String get aiChatGreeting =>
      'Hi! I\'m DocuCraft AI, ready to help you craft a great deck.\n\n**What I can do:**\n✨ Create slides from plain text\n🔄 Redesign an existing slide\n📊 Build a full presentation from an outline\n🎨 Auto-generate layout + content\n🖼️ **AI from Sketches** — sketch on the canvas, AI turns it into a design\n\n*Try: \"Make a slide about marketing strategy\"*';

  @override
  String get aiSketchCanvasEmpty =>
      '⚠️ Canvas is empty. Draw a sketch on the canvas first, then try again.';

  @override
  String get aiSketchNoCanvas => '⚠️ No sketch canvas available.';

  @override
  String get aiSketchAnalyzing => '🧠 Analyzing sketch and planning layout...';

  @override
  String get aiStorageNotReady => 'Storage not ready. Try again.';

  @override
  String get aiErrorPlanningEmpty =>
      'Planning returned no pages; using demo outline.';

  @override
  String aiErrorBackendOffline(String error) {
    return 'Backend offline: $error — using demo outline.';
  }

  @override
  String get aiErrorNoPages => 'No pages to generate.';

  @override
  String aiErrorGeneration(String error) {
    return 'Generation failed: $error';
  }

  @override
  String aiBlueprintForkedNoOutline(String name) {
    return 'Forked $name: no saved outline, replan from scratch.';
  }

  @override
  String aiBlueprintForkedEmpty(String name) {
    return 'Forked $name: saved outline was empty, replan.';
  }

  @override
  String aiBlueprintForkedReady(String name) {
    return 'Forked $name — edit and generate.';
  }

  @override
  String aiBlueprintLoaded(String name) {
    return 'Loaded: $name';
  }

  @override
  String aiSketchConvertFailed(String reason) {
    return '⚠️ Failed to convert sketch: $reason';
  }

  @override
  String aiGenericError(String message) {
    return '⚠️ Error: $message';
  }

  @override
  String get aiGenerateFailed => '⚠️ Failed to generate: no result';

  @override
  String aiDesignGateIntro(String topic, String color, String style) {
    return 'I\'ll design with:\n• Topic: $topic\n• Color: $color\n• Style: $style\n\n[✅ Generate Now] [✏️ Edit Details]';
  }

  @override
  String aiDesignSuccess(
    int count,
    int textCount,
    int shapeCount,
    int imageCount,
  ) {
    return '✅ **Success!** $count visual elements added to the slide.\n\nDetails:\n• $textCount text\n• $shapeCount shapes\n• $imageCount images\n\n[🔄 Try Again] [✏️ Edit]';
  }

  @override
  String get aiSketchConvertSuccess => '✅ **Sketch → Design successful!**\n\n';

  @override
  String get aiSketchConvertSuccessFallback =>
      '✅ **Sketch → Design successful!** (fallback)\n\n';

  @override
  String get aiNoResult => 'no result';

  @override
  String get uiRetry => 'Try Again';

  @override
  String get uiEditDesignDetail => 'Edit Design Detail';

  @override
  String get uiCancel => 'Cancel';

  @override
  String get uiGenerating => 'Generating…';
}
