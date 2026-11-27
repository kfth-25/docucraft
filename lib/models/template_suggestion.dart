// DocuCraft — Template Suggestion Model
// Rekomendasikan template berdasarkan prompt user

class TemplateSuggestion {
  final String id;
  final String name;
  final String description;
  final List<String> colors;
  final String style;
  final List<String> tags;

  TemplateSuggestion({
    required this.id,
    required this.name,
    required this.description,
    required this.colors,
    required this.style,
    required this.tags,
  });
}

class TemplateSuggestions {
  static final List<TemplateSuggestion> all = [
    TemplateSuggestion(
      id: 'tech-modern',
      name: 'Tech Modern',
      description: 'Desain futuristik dengan warna biru-ungu',
      colors: ['#6366F1', '#8B5CF6', '#FFFFFF'],
      style: 'futuristik',
      tags: ['tech', 'ai', 'startup', 'digital', 'cyber', 'robot', 'software'],
    ),
    TemplateSuggestion(
      id: 'minimal-clean',
      name: 'Minimal Clean',
      description: 'Desain sederhana dan bersih',
      colors: ['#FFFFFF', '#F3F4F6', '#1F2937'],
      style: 'minimalis',
      tags: ['portfolio', 'pitch', 'clean', 'simple', 'modern'],
    ),
    TemplateSuggestion(
      id: 'corporate',
      name: 'Corporate Professional',
      description: 'Desain formal untuk bisnis',
      colors: ['#1E3A8A', '#374151', '#FFFFFF'],
      style: 'formal',
      tags: ['business', 'corporate', 'report', 'finance', 'company', 'meeting'],
    ),
    TemplateSuggestion(
      id: 'creative',
      name: 'Creative Playful',
      description: 'Desain cerah dan kreatif',
      colors: ['#EC4899', '#F59E0B', '#FFFFFF'],
      style: 'playful',
      tags: ['marketing', 'event', 'creative', 'festival', 'party', 'art'],
    ),
    TemplateSuggestion(
      id: 'dark-elegant',
      name: 'Dark Elegant',
      description: 'Desain gelap elegan',
      colors: ['#0F172A', '#D4AF37', '#FFFFFF'],
      style: 'elegan',
      tags: ['luxury', 'fashion', 'premium', 'gold', 'exclusive'],
    ),
    TemplateSuggestion(
      id: 'nature-green',
      name: 'Nature Green',
      description: 'Desain natural hijau',
      colors: ['#10B981', '#059669', '#FFFFFF'],
      style: 'natural',
      tags: ['nature', 'environment', 'green', 'eco', 'agriculture', 'plant'],
    ),
    TemplateSuggestion(
      id: 'education',
      name: 'Education',
      description: 'Desain untuk pendidikan',
      colors: ['#3B82F6', '#1D4ED8', '#FFFFFF'],
      style: 'educational',
      tags: ['education', 'school', 'university', 'learning', 'student', 'teacher'],
    ),
    TemplateSuggestion(
      id: 'healthcare',
      name: 'Healthcare',
      description: 'Desain untuk kesehatan',
      colors: ['#06B6D4', '#0891B2', '#FFFFFF'],
      style: 'medical',
      tags: ['health', 'medical', 'hospital', 'doctor', 'pharmacy', 'medicine'],
    ),
  ];

  static List<TemplateSuggestion> suggest(String prompt) {
    final lower = prompt.toLowerCase();
    final scored = <MapEntry<TemplateSuggestion, int>>[];

    for (final template in all) {
      int score = 0;

      // Match tags (weight: 3)
      for (final tag in template.tags) {
        if (lower.contains(tag)) score += 3;
      }

      // Match style (weight: 2)
      if (lower.contains(template.style)) score += 2;

      // Match name (weight: 2)
      if (lower.contains(template.name.toLowerCase())) score += 2;

      if (score > 0) scored.add(MapEntry(template, score));
    }

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));

    // Return top 3
    return scored.take(3).map((e) => e.key).toList();
  }
}
