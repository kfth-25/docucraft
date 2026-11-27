// DocuCraft — Import Service (Langkah 1: Pemrosesan Konten Sumber)
// Menangani berbagai jenis input: teks, file, gambar
// @see docs/7-step-comparison.md#step-1-source-content-processing
// @see docs/README.md

import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Source types supported by DocuCraft
enum SourceType {
  text,
  pdf,
  docx,
  image,
  sketch,
}

/// Imported source content
class SourceContent {
  final SourceType type;
  final String text;
  final Uint8List? bytes;
  final String? fileName;
  final Map<String, dynamic>? metadata;

  SourceContent({
    required this.type,
    required this.text,
    this.bytes,
    this.fileName,
    this.metadata,
  });
}

class ImportService {
  /// Process text input (direct prompt)
  static SourceContent fromText(String text) {
    return SourceContent(
      type: SourceType.text,
      text: text,
    );
  }

  /// Process image input (sketch/coretan)
  static SourceContent fromImage(Uint8List bytes, {String? fileName}) {
    return SourceContent(
      type: SourceType.image,
      text: '',
      bytes: bytes,
      fileName: fileName,
    );
  }

  /// Process file input (PDF, DOCX, etc.)
  /// Note: For web platform, file conversion is limited
  /// This is a stub for future implementation
  static Future<SourceContent> fromFile(
    Uint8List bytes, {
    required String fileName,
  }) async {
    // Detect file type from extension
    final ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      case 'pdf':
        // TODO: Implement PDF to text conversion
        return SourceContent(
          type: SourceType.pdf,
          text: '[PDF content - conversion not yet supported on web]',
          bytes: bytes,
          fileName: fileName,
        );
      case 'docx':
        // TODO: Implement DOCX to text conversion
        return SourceContent(
          type: SourceType.docx,
          text: '[DOCX content - conversion not yet supported on web]',
          bytes: bytes,
          fileName: fileName,
        );
      case 'txt':
      case 'md':
        // Text files can be read directly
        final text = String.fromCharCodes(bytes);
        return SourceContent(
          type: SourceType.text,
          text: text,
          bytes: bytes,
          fileName: fileName,
        );
      default:
        return SourceContent(
          type: SourceType.text,
          text: '[Unsupported file type: $ext]',
          bytes: bytes,
          fileName: fileName,
        );
    }
  }

  /// Validate source content
  static bool isValid(SourceContent source) {
    if (source.type == SourceType.text) {
      return source.text.trim().isNotEmpty;
    }
    if (source.type == SourceType.image) {
      return source.bytes != null && source.bytes!.isNotEmpty;
    }
    return true;
  }

  /// Get display name for source type
  static String getSourceTypeName(SourceType type) {
    switch (type) {
      case SourceType.text:
        return 'Text';
      case SourceType.pdf:
        return 'PDF';
      case SourceType.docx:
        return 'DOCX';
      case SourceType.image:
        return 'Image';
      case SourceType.sketch:
        return 'Sketch';
    }
  }
}
