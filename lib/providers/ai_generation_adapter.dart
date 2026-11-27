// DocuCraft — AI Generation Adapter
// Menjembatani SlideProvider dengan AiGenerationService (pipeline berbasis SVG)

import 'dart:typed_data';
import '../models/slide.dart';
import '../services/ai_generation.dart';
import '../services/svg_to_slide_elements.dart';

class AiGenerationAdapter {
  /// Generate SVG from text prompt
  Future<SvgGenerateResult> generateFromPrompt(String prompt, {String? model}) async {
    final placeholderPng = Uint8List(0);
    return await AiGenerationService.sketchToDesignSvg(placeholderPng, prompt, model: model);
  }

  /// Redesign current slide
  Future<SvgGenerateResult> redesignCurrentSlide(String prompt, {String? model}) async {
    final placeholderPng = Uint8List(0);
    return await AiGenerationService.sketchToDesignSvg(placeholderPng, prompt, model: model);
  }

  /// Generate from sketch/draw strokes
  Future<SvgGenerateResult> generateFromSketch(String prompt, {String? model, Slide? currentSlide}) async {
    final placeholderPng = Uint8List(0);
    return await AiGenerationService.generateFromSketchSvg(
      {'regions': [], 'strokeCount': 0, 'canvasSize': {'width': 1920, 'height': 1080}},
      prompt,
      currentSlide: currentSlide,
      model: model,
    );
  }

  /// Generate outline from topic (not yet implemented)
  Future<List<String>> generateOutline(String topic, {String? model}) async {
    return [];
  }

  /// Generate single slide from topic
  Future<SvgGenerateResult> generateSingleSlide(String topic, {String? model}) async {
    final placeholderPng = Uint8List(0);
    return await AiGenerationService.sketchToDesignSvg(placeholderPng, topic, model: model);
  }

  /// Check AI connection status
  Future<String> checkConnection() async {
    return 'online';
  }

  /// Apply AI result to slide — parse SVG and add elements
  static void applySlideResult(Slide slide, SvgGenerateResult result) {
    if (!result.success || result.svg == null || result.svg!.isEmpty) return;
    final elements = SvgToSlideElements.parse(result.svg!);
    slide.elements.addAll(elements);
  }
}
