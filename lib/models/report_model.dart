class ConversationReport {
  final String id;
  final String summary;          // 요약 내용
  final String imageUrl;         // AI가 생성한 이미지
  final Map<String, double> speechRatio; // 발화 비율 그래프 데이터
  final DateTime createdAt;

  ConversationReport({
    required this.id,
    required this.summary,
    required this.imageUrl,
    required this.speechRatio,
    required this.createdAt,
  });

  factory ConversationReport.fromJson(Map<String, dynamic> json) {
    return ConversationReport(
      id: json['id'] ?? '',
      summary: json['summary'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      speechRatio: Map<String, double>.from(json['speechRatio'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'summary': summary,
      'imageUrl': imageUrl,
      'speechRatio': speechRatio,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
