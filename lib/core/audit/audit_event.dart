class AuditEvent {
  AuditEvent({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
    this.metadata,
    this.origin,
  });

  factory AuditEvent.create({
    required String category,
    required AuditEventLevel level,
    required String message,
    Map<String, dynamic>? metadata,
    String? origin,
  }) {
    final now = DateTime.now();
    final uniqueId = '${now.microsecondsSinceEpoch}-${category.toLowerCase()}';
    return AuditEvent(
      id: uniqueId,
      timestamp: now,
      category: category,
      level: level,
      message: message,
      metadata: metadata,
      origin: origin,
    );
  }

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id'] as String,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      category: json['category'] as String? ?? 'general',
      level: AuditEventLevelParser.parse(json['level'] as String? ?? 'info'),
      message: json['message'] as String? ?? '',
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      origin: json['origin'] as String?,
    );
  }

  final String id;
  final DateTime timestamp;
  final String category;
  final AuditEventLevel level;
  final String message;
  final Map<String, dynamic>? metadata;
  final String? origin;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'level': level.name,
      'message': message,
      'metadata': metadata,
      'origin': origin,
    };
  }
}

enum AuditEventLevel { info, warning, error }

class AuditEventLevelParser {
  static AuditEventLevel parse(String value) {
    switch (value.toLowerCase()) {
      case 'warning':
        return AuditEventLevel.warning;
      case 'error':
        return AuditEventLevel.error;
      default:
        return AuditEventLevel.info;
    }
  }
}
