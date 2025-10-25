class ConversationReport {
  final String id;
  final String summary;
  final String imageUrl;
  final String? imageBase64;
  final DateTime createdAt;
  final int? averageResponseDelayMs;
  final String characterName;

  ConversationReport({
    required this.id,
    required this.summary,
    required this.imageUrl,
    this.imageBase64,
    this.averageResponseDelayMs,
    required this.createdAt,
    this.characterName = '',
  });

  factory ConversationReport.fromJson(Map<String, dynamic> json) {
    return ConversationReport(
      id: json['id'] ?? '',
      summary: json['summary'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      imageBase64: json['imageBase64'],
      averageResponseDelayMs: json['averageResponseDelayMs'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      characterName: json['characterName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'summary': summary,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'averageResponseDelayMs': averageResponseDelayMs,
      'createdAt': createdAt.toIso8601String(),
      'characterName': characterName,
    };
  }
}
