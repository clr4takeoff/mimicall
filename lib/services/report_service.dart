import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';
import 'llm_service.dart';

class ReportService {
  final db = FirebaseDatabase.instance.ref();
  final llm = GPTResponse();

  Future<ConversationReport> generateReport(
      String userName, String reportId, String conversationPath) async {
    final reportRef = db.child(conversationPath);
    final convRef = db.child('$conversationPath/conversation/messages');

    // 1️⃣ 대화 불러오기
    final convSnap = await convRef.get();
    if (!convSnap.exists) {
      print("[Report] 대화 데이터 없음 ($conversationPath)");
      await reportRef.update({
        'summary': '대화 데이터가 없습니다.',
        'comment': '',
        'averageResponseDelayMs': 0,
      });
      return ConversationReport(
        id: reportId,
        summary: "대화가 없어요.",
        imageUrl: "",
        imageBase64: "",
        createdAt: DateTime.now(),
      );
    }

    // 2️⃣ 메시지 정리 + responseDelay 수집
    final messages = <Map<String, dynamic>>[];
    final responseDelays = <int>[];

    for (final entry in convSnap.children) {
      final value = Map<String, dynamic>.from(entry.value as Map);

      final delay = value['responseDelayMs'];
      if (delay != null) {
        final parsed = int.tryParse(delay.toString());
        if (parsed != null && parsed > 0) responseDelays.add(parsed);
      }

      messages.add({
        "role": value['role'],
        "text": value['text'],
        "timestamp": value['timestamp'],
      });
    }

    messages.sort((a, b) =>
        a['timestamp'].toString().compareTo(b['timestamp'].toString()));

    // 3️⃣ 평균 반응 시간 계산
    final avgResponseDelay = responseDelays.isEmpty
        ? 0
        : (responseDelays.reduce((a, b) => a + b) ~/ responseDelays.length);

    print("[Report] 평균 반응 시간: ${avgResponseDelay}ms "
        "(${(avgResponseDelay / 1000).toStringAsFixed(2)}초)");

    // 4️⃣ GPT 분석 요청
    final prompt = _buildPrompt(messages, avgResponseDelay);
    final response = await llm.fetchPromptResponse(
      "너는 언어치료 전문가야. 아이와 캐릭터의 대화를 분석해서 리포트를 작성해줘.",
      prompt,
    );

    final parsed = _safeParse(response);

    // 5️⃣ 결과 저장 (summary + comment + 평균 반응 시간)
    await reportRef.update({
      'summary': parsed['summary'],
      'comment': parsed['comment'] ?? '',
      'averageResponseDelayMs': avgResponseDelay,
    });

    // 6️⃣ 모델 반환
    return ConversationReport(
      id: reportId,
      summary: parsed['summary'],
      imageUrl: "",
      imageBase64: "",
      createdAt: DateTime.now(),
    );
  }

  String _buildPrompt(List<Map<String, dynamic>> messages, int avgDelayMs) {
    final dialogue = messages
        .map((m) => "${m['role'] == 'assistant' ? 'AI' : '아이'}: ${m['text']}")
        .join('\n');

    final avgDelaySec = (avgDelayMs / 1000).toStringAsFixed(2);

    return '''
      다음은 언어치료 세션 중 아이와 AI 캐릭터의 대화입니다.
      아이의 평균 반응 시간은 약 ${avgDelaySec}초입니다.
      이 정보를 참고하여 리포트를 작성하세요.

      JSON 형태로 응답해주세요:
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
