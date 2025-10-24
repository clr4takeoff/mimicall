class ConversationReport {
  final String id;
  final String summary;
  final String imageUrl;
  final String? imageBase64;
  final DateTime createdAt;

  ConversationReport({
    required this.id,
    required this.summary,
    required this.imageUrl,
    this.imageBase64,
    required this.createdAt,
  });

  factory ConversationReport.fromJson(Map<String, dynamic> json) {
    return ConversationReport(
      id: json['id'] ?? '',
      summary: json['summary'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      imageBase64: json['imageBase64'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'summary': summary,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
