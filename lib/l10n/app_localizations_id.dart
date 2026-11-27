// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'DocuCraft';

  @override
  String get aiChatGreeting =>
      'Halo! Saya DocuCraft AI, siap bantu bikin presentasi keren.\n\n**Yang bisa saya lakukan:**\n✨ Buat slide dari teks biasa\n🔄 Redesign slide yang ada\n📊 Buat presentasi full dari outline\n🎨 Generate layout + konten otomatis\n🖼️ **AI dari Coretan** — coret di canvas, AI ubah jadi desain\n\n*Coba: \"Buat slide tentang strategi marketing\"*';

  @override
  String get aiSketchCanvasEmpty =>
      '⚠️ Canvas kosong. Gambar coretan dulu di kanvas, lalu coba lagi.';

  @override
  String get aiSketchNoCanvas => '⚠️ Tidak ada canvas coretan yang tersedia.';

  @override
  String get aiSketchAnalyzing => '🧠 Menganalisis coretan dan merancang...';

  @override
  String get aiStorageNotReady => 'Storage belum siap. Coba lagi.';

  @override
  String get aiErrorPlanningEmpty =>
      'Planning tidak menghasilkan halaman; menggunakan outline demo.';

  @override
  String aiErrorBackendOffline(String error) {
    return 'Backend offline: $error — menggunakan outline demo.';
  }

  @override
  String get aiErrorNoPages => 'Tidak ada halaman untuk di-generate.';

  @override
  String aiErrorGeneration(String error) {
    return 'Generation gagal: $error';
  }

  @override
  String aiBlueprintForkedNoOutline(String name) {
    return 'Fork $name: tidak ada outline tersimpan, replan dari awal.';
  }

  @override
  String aiBlueprintForkedEmpty(String name) {
    return 'Fork $name: outline kosong, replan.';
  }

  @override
  String aiBlueprintForkedReady(String name) {
    return 'Fork $name — edit lalu generate.';
  }

  @override
  String aiBlueprintLoaded(String name) {
    return 'Dimuat: $name';
  }

  @override
  String aiSketchConvertFailed(String reason) {
    return '⚠️ Gagal convert sketch: $reason';
  }

  @override
  String aiGenericError(String message) {
    return '⚠️ Error: $message';
  }

  @override
  String get aiGenerateFailed => '⚠️ Gagal generate: tidak ada hasil';

  @override
  String aiDesignGateIntro(String topic, String color, String style) {
    return 'Saya akan buat desain dengan:\n• Topik: $topic\n• Warna: $color\n• Style: $style\n\n[✅ Generate Sekarang] [✏️ Ubah Detail]';
  }

  @override
  String aiDesignSuccess(
    int count,
    int textCount,
    int shapeCount,
    int imageCount,
  ) {
    return '✅ **Berhasil!** $count elemen visual ditambahkan ke slide.\n\nDetail:\n• $textCount teks\n• $shapeCount bentuk\n• $imageCount gambar\n\n[🔄 Coba Lagi] [✏️ Edit]';
  }

  @override
  String get aiSketchConvertSuccess => '✅ **Coretan → Design berhasil!**\n\n';

  @override
  String get aiSketchConvertSuccessFallback =>
      '✅ **Coretan → Design berhasil!** (fallback)\n\n';

  @override
  String get aiNoResult => 'tidak ada hasil';

  @override
  String get uiRetry => 'Coba Lagi';

  @override
  String get uiEditDesignDetail => 'Edit Detail Desain';

  @override
  String get uiCancel => 'Batal';

  @override
  String get uiGenerating => 'Generating…';
}
