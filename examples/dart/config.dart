// DocuCraft — Configuration
// Dart equivalent of config.py

import 'dart:io';

/// Application configuration constants
class AppConfig {
  // AI Configuration
  static const String baseUrl = 'http://127.0.0.1:20128/v1';

  // API Key HANYA dari environment — tidak ada key hard-coded di kode.
  // export AI_API_KEY=sk-... sebelum menjalankan contoh ini.
  static String get apiKey => Platform.environment['AI_API_KEY'] ?? '';

  // Model configurations
  static const String fastModel = 'Open-Code';
  static const String qualityModel = 'kc/nvidia/nemotron-3-ultra-550b-a55b:free';
  static const String freeModel = 'oc/laguna-s-2.1-free';
  static const String longcatModel = 'kc/meituan/longcat-2.0-free';
  static const String visionModel = 'gc/gemini-3-flash-preview';

  // Fallback chain: vision (gemini) → free (laguna) → quality → fast → longcat
  static const List<String> fallbackModels = [
    'gc/gemini-3-flash-preview',
    'oc/laguna-s-2.1-free',
    'kc/nvidia/nemotron-3-ultra-550b-a55b:free',
    'Open-Code',
    'kc/meituan/longcat-2.0-free',
  ];

  static const int maxTokens = 8192;

  // Rate limiting
  static const int maxRequestsPerMinute = 10;

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration baseRetryDelay = Duration(seconds: 2);
  static const Duration maxRetryDelay = Duration(seconds: 30);

  // Canvas defaults
  static const int defaultCanvasWidth = 1920;
  static const int defaultCanvasHeight = 1080;
  static const int minCanvasWidth = 380;
  static const int minCanvasHeight = 214;

  // Zoom limits
  static const double minZoom = 0.3;
  static const double maxZoom = 3.0;
  static const double zoomStep = 0.1;

  // Performance
  static const int maxStrokes = 200;
  static const int maxPointsPerStroke = 500;
  static const double simplificationTolerance = 2.0;
  static const double minPointDistance = 3.0;

  // File paths
  static const String templatesDir = 'skills/ppt-master/templates';
  static const String assetsDir = 'assets';
  static const String imagesDir = 'images';
  static const String iconsDir = 'icons';
  static const String exportsDir = 'exports';

  // Export settings
  static const int exportQuality = 90;
  static const String exportFormat = 'png';
}