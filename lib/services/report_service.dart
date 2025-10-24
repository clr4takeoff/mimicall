import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';
import 'llm_service.dart';

class ReportService {
  final db = FirebaseDatabase.instance.ref();
  final llm = GPTResponse();

  Future<ConversationReport> generateReport(
      String userName, String reportId) async {
    final reportRef = db.child('reports/$userName/$reportId');

    // 1️⃣ 대화 불러오기
    final convSnap = await reportRef.child('conversation/messages').get();
    if (!convSnap.exists) {
      print("[Report] 대화 데이터 없음");
      return ConversationReport(
        id: reportId,
        summary: "대화가 없어요.",
        imageUrl: "",
        imageBase64: "",
        speechRatio: {"아이": 0, "AI": 0},
        createdAt: DateTime.now(),
      );
    }

    final messages = <Map<String, dynamic>>[];
    for (final entry in convSnap.children) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      messages.add({
        "role": value['role'],
        "text": value['text'],
        "timestamp": value['timestamp'],
      });
    }

    messages.sort((a, b) =>
        a['timestamp'].toString().compareTo(b['timestamp'].toString()));

    // 2️⃣ GPT 분석
    final prompt = _buildPrompt(messages);
    final response = await llm.fetchPromptResponse(
      "너는 언어치료 전문가야. 아이와 캐릭터의 대화를 분석해서 리포트를 작성해줘.",
      prompt,
    );

    final parsed = _safeParse(response);

    // 3️⃣ DB 저장
    await reportRef.update({
      'summary': parsed['summary'],
      'speechRatio': parsed['speechRatio'],
      'comment': parsed['comment'] ?? '',
      'generatedAt': DateTime.now().toIso8601String(),
    });

    // 4️⃣ ConversationReport 모델 생성 후 반환
    return ConversationReport(
      id: reportId,
      summary: parsed['summary'],
      imageUrl: "",
      imageBase64: "",
      speechRatio: Map<String, double>.from(
        (parsed['speechRatio'] as Map).map(
              (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
      ),
      createdAt: DateTime.now(),
    );
  }

  String _buildPrompt(List<Map<String, dynamic>> messages) {
    final dialogue = messages
        .map((m) => "${m['role'] == 'assistant' ? 'AI' : '아이'}: ${m['text']}")
        .join('\n');
    return '''
        다음은 언어치료 세션 중 아이와 AI 캐릭터의 대화입니다.
        이를 분석하여 JSON 형태의 리포트를 만들어주세요.
        
        형식 예시:
        {
          "summary": "오늘 대화의 요약",
          "speechRatio": {"아이": 60, "AI": 40},
          "comment": "아동의 발화가 늘었어요."
        }
        
        대화:
        $dialogue
        ''';
          }

  Map<String, dynamic> _safeParse(String content) {
    try {
      return jsonDecode(content);
    } catch (_) {
      return {
        'summary': content,
        'speechRatio': {'아이': 50, 'AI': 50}, // 일단 더미데이터 넣어뒀는데 나중에 로직 구현 해야함
        'comment': '응답 파싱 실패',
      };
    }
  }
}
