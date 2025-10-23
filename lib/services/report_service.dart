import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'llm_service.dart'; // GPT 호출 모듈 불러오기

class ReportService {
  final db = FirebaseDatabase.instance.ref();
  final llm = GPTResponse(); // GPT 호출 클래스

  Future<void> generateReport(String userName, String reportId) async {
    final reportRef = db.child('reports/$userName/$reportId');

    // conversation 데이터 가져오기
    final snapshot = await reportRef.child('conversation').get();
    if (!snapshot.exists) return;

    final conversation = List<Map>.from(snapshot.value as List);

    // GPT 요청 생성
    final prompt = _buildPrompt(conversation);

    // LLM 서비스 호출
    final response = await llm.fetchPromptResponse(
      "너는 언어치료 전문가야. 부모와 아동의 대화를 분석해서 발달지표를 만들어줘.",
      prompt,
    );

    // GPT 응답 파싱 (JSON 예상)
    final parsed = _safeParse(response);

    // DB 업데이트
    await reportRef.update({
      'summary': parsed['summary'],
      'speechRatio': parsed['speechRatio'],
    });
  }

  String _buildPrompt(List<Map> conversation) {
    final text = conversation.map((m) => "${m['speaker']}: ${m['text']}").join('\n');
    return '''
다음은 부모와 아동의 대화입니다. 이를 바탕으로 JSON 형식의 리포트를 만들어주세요.

{
  "summary": "오늘 대화의 요약",
  "speechRatio": {
    "아동": 70,
    "부모": 30
  },
  "comment": "아동이 표현을 잘하지만 문장 구조가 짧아요. 문장 확장을 유도해주세요."
}

대화:
$text
    ''';
  }

  Map<String, dynamic> _safeParse(String content) {
    try {
      return jsonDecode(content);
    } catch (_) {
      return {
        'summary': content,
        'speechRatio': {'아동': 50, '부모': 50},
      };
    }
  }
}
