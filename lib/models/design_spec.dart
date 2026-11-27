// DocuCraft — Spesifikasi Desain (DesignSpec)
// Model spesifikasi desain untuk generate presentasi.
// Dibuat pada fase "strategist" (Langkah 5) setelah user mengonfirmasi
// detail desain (warna, font, gaya visual).

/// Spesifikasi desain untuk generate presentasi.
/// Dibuat pada fase "strategist" (Langkah 5) setelah user mengonfirmasi detail desain.
library;

class DesignSpec {
  final String topic;
  final String subtitle;
  final String warna;
  final String style;
  final List<String> elemen;
  final int jumlahSlide;
  final String? audience;
  final String? tone;
  final Map<String, dynamic> metadata;

  DesignSpec({
    required this.topic,
    this.subtitle = '',
    required this.warna,
    required this.style,
    required this.elemen,
    required this.jumlahSlide,
    this.audience,
    this.tone,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'subtitle': subtitle,
        'warna': warna,
        'style': style,
        'elemen': elemen,
        'jumlahSlide': jumlahSlide,
        'audience': audience,
        'tone': tone,
        'metadata': metadata,
      };

  factory DesignSpec.fromJson(Map<String, dynamic> json) => DesignSpec(
        topic: json['topic'] ?? '',
        subtitle: json['subtitle'] ?? '',
        warna: json['warna'] ?? '',
        style: json['style'] ?? '',
        elemen: List<String>.from(json['elemen'] ?? []),
        jumlahSlide: json['jumlahSlide'] ?? 1,
        audience: json['audience'],
        tone: json['tone'],
        metadata: json['metadata'] ?? {},
      );

  /// Generate prompt for AI based on design spec
  String toPrompt() {
    final sb = StringBuffer();
    sb.writeln('Buat presentasi dengan detail:');
    sb.writeln('• Topik: $topic');
    if (subtitle.isNotEmpty) sb.writeln('• Subtitle: $subtitle');
    sb.writeln('• Warna: $warna');
    sb.writeln('• Style: $style');
    sb.writeln('• Elemen: ${elemen.join(", ")}');
    sb.writeln('• Jumlah slide: $jumlahSlide');
    if (audience != null) sb.writeln('• Audience: $audience');
    if (tone != null) sb.writeln('• Tone: $tone');
    return sb.toString();
  }

  /// Create a quick design spec from a simple prompt
  factory DesignSpec.fromPrompt(String prompt) {
    final lower = prompt.toLowerCase();

    // Detect warna
    final warna = _detectWarna(lower);

    // Detect style
    final style = _detectStyle(lower);

    // Detect jumlah slide
    final jumlahSlide = _detectSlideCount(lower);

    return DesignSpec(
      topic: prompt,
      warna: warna,
      style: style,
      elemen: ['judul', 'konten', 'shape dekoratif'],
      jumlahSlide: jumlahSlide,
    );
  }

  static String _detectWarna(String prompt) {
    final warnaMap = {
      'biru': 'biru profesional',
      'merah': 'merah elegan',
      'hijau': 'hijau natural',
      'kuning': 'kuning energik',
      'ungu': 'ungu kreatif',
      'pink': 'pink modern',
      'orange': 'orange hangat',
      'hitam': 'hitam minimalis',
      'putih': 'putih bersih',
      'indigo': 'indigo modern',
      'cyan': 'cyan segar',
      'teal': 'teal profesional',
      'emas': 'emas mewah',
    };

    for (final entry in warnaMap.entries) {
      if (prompt.contains(entry.key)) return entry.value;
    }
    return 'indigo modern';
  }

  static String _detectStyle(String prompt) {
    final styleMap = {
      'modern': 'modern',
      'minimalis': 'minimalis',
      'clean': 'clean',
      'corporate': 'corporate',
      'formal': 'formal',
      'friendly': 'friendly',
      'elegan': 'elegan',
      'casual': 'casual',
      'romantis': 'romantis',
      'futuristik': 'futuristik',
      'kreatif': 'kreatif',
      'profesional': 'profesional',
    };

    for (final entry in styleMap.entries) {
      if (prompt.contains(entry.key)) return entry.value;
    }
    return 'modern profesional';
  }

  static int _detectSlideCount(String prompt) {
    final numbers = {
      'satu': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5,
      'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9, 'sepuluh': 10,
    };

    // Check for digit patterns like "5 slide" or "5-slide"
    final digitMatch = RegExp(r'(\d+)\s*slide').firstMatch(prompt);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!) ?? 1;
    }

    // Check for Indonesian number words
    for (final entry in numbers.entries) {
      if (prompt.contains(entry.key)) return entry.value;
    }

    return 1;
  }
}
