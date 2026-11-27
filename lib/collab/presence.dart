// DocuCraft — Presence & Awareness Models
// Melacak posisi kursor user, seleksi, dan status online untuk kolaborasi

class PresenceUser {
  final String userId;
  final String name;
  final String? color;
  final String? avatarUrl;
  final String? initials;
  CursorState? cursor;
  bool isOnline;
  DateTime lastSeen;

  PresenceUser({
    required this.userId,
    required this.name,
    this.color,
    this.avatarUrl,
    this.initials,
    this.cursor,
    this.isOnline = true,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'color': color,
    'avatarUrl': avatarUrl,
    'initials': initials,
    'cursor': cursor?.toJson(),
    'isOnline': isOnline,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory PresenceUser.fromJson(Map<String, dynamic> json) => PresenceUser(
    userId: json['userId'],
    name: json['name'],
    color: json['color'],
    avatarUrl: json['avatarUrl'],
    initials: json['initials'],
    cursor: json['cursor'] != null ? CursorState.fromJson(json['cursor']) : null,
    isOnline: json['isOnline'] ?? true,
    lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : DateTime.now(),
  );
}

class CursorState {
  int slideIndex;
  String? elementId;
  double x, y;

  CursorState({
    this.slideIndex = 0,
    this.elementId,
    this.x = 0,
    this.y = 0,
  });

  Map<String, dynamic> toJson() => {
    'slideIndex': slideIndex,
    'elementId': elementId,
    'x': x, 'y': y,
  };

  factory CursorState.fromJson(Map<String, dynamic> json) => CursorState(
    slideIndex: json['slideIndex'] ?? 0,
    elementId: json['elementId'],
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
  );
}

class PresenceState {
  CursorState cursor;
  String? selectedElementId;
  int viewportSlideIndex;
  bool isEditing;

  PresenceState({
    CursorState? cursor,
    this.selectedElementId,
    this.viewportSlideIndex = 0,
    this.isEditing = false,
  }) : cursor = cursor ?? CursorState();

  Map<String, dynamic> toJson() => {
    'cursor': cursor.toJson(),
    'selectedElementId': selectedElementId,
    'viewportSlideIndex': viewportSlideIndex,
    'isEditing': isEditing,
  };

  factory PresenceState.fromJson(Map<String, dynamic> json) => PresenceState(
    cursor: json['cursor'] != null ? CursorState.fromJson(json['cursor']) : CursorState(),
    selectedElementId: json['selectedElementId'],
    viewportSlideIndex: json['viewportSlideIndex'] ?? 0,
    isEditing: json['isEditing'] ?? false,
  );
}
