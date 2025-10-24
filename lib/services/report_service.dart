import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';
import 'llm_service.dart';

class ReportService {
  final db = FirebaseDatabase.instance.ref();
  final llm = GPTResponse();

  Future<ConversationReport> generateReport(
      String userName, String reportId, String conversationPath) async {
    // 리포트는 대화와 같은 경로에 저장
    final reportRef = db.child(conversationPath);
    final convRef = db.child('$conversationPath/conversation/messages');

    // 1️⃣ 대화 불러오기
    final convSnap = await convRef.get();
    if (!convSnap.exists) {
      print("[Report] 대화 데이터 없음 ($conversationPath)");
      await reportRef.update({
        'summary': '대화 데이터가 없습니다.',
        'comment': '',
      });
      return ConversationReport(
        id: reportId,
        summary: "대화가 없어요.",
        imageUrl: "",
        imageBase64: "",
        speechRatio: {}, // 모델 정의상 남겨둠 (DB엔 안저장됨)
        createdAt: DateTime.now(),
      );
    }

    // 2️⃣ 메시지 정리
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

    // 3️⃣ GPT 분석 요청
    final prompt = _buildPrompt(messages);
    final response = await llm.fetchPromptResponse(
      "너는 언어치료 전문가야. 아이와 캐릭터의 대화를 분석해서 리포트를 작성해줘.",
      prompt,
    );

    final parsed = _safeParse(response);

    // 4️⃣ 결과 저장 (summary + comment만)
    await reportRef.update({
      'summary': parsed['summary'],
      'comment': parsed['comment'] ?? '',
    });

    // 5️⃣ 모델 반환 (speechRatio는 빈 맵)
    return ConversationReport(
      id: reportId,
      summary: parsed['summary'],
      imageUrl: "",
      imageBase64: "",
      speechRatio: {},
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
      {
        "summary": "오늘 대화의 요약",
        "comment": "아동의 발화 특징이나 대화 평가"
      }
      대화:
      $dialogue
    ''';
  }

  Map<String, dynamic> _safeParse(String content) {
    try {
      // GPT 응답에 흔히 붙는 ```json ``` 코드블록 제거
      final cleaned = content
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

      return jsonDecode(cleaned);
    } catch (e) {
      print("[Report] JSON 파싱 실패: $e\n원본: $content");
      return {
        'summary': content,
        'comment': '응답 파싱 실패',
      };
    }
  }

}
