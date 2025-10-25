import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';
import 'llm_service.dart';
import 'package:flutter/material.dart';

class ReportService {
  final db = FirebaseDatabase.instance.ref();
  final llm = GPTResponse();

  Future<ConversationReport> generateReport(
      String userName,
      String reportId,
      String conversationPath,
      String characterName,
      ) async {
    final reportRef = db.child(conversationPath);
    final convRef = db.child('$conversationPath/conversation/messages');

    // 1. 대화 불러오기
    final convSnap = await convRef.get();
    if (!convSnap.exists) {
      debugPrint("[Report] 대화 데이터 없음 ($conversationPath)");
      await reportRef.update({
        'summary': '대화 데이터가 없습니다.',
        'comment': '',
        'averageResponseDelayMs': 0,
        'averageSpeechDurationMs': 0,
        'speechCount': 0,
      });
      return ConversationReport(
        id: reportId,
        summary: "대화가 없어요.",
        imageUrl: "",
        imageBase64: "",
        averageResponseDelayMs: 0,
        createdAt: DateTime.now(),
      );
    }

    // 2. 메시지 정리 + 반응시간 및 발화시간 수집
    final messages = <Map<String, dynamic>>[];
    final responseDelays = <int>[];
    final speechDurations = <int>[];
    int speechCount = 0;

    for (final entry in convSnap.children) {
      final value = Map<String, dynamic>.from(entry.value as Map);

      // 반응 지연 시간
      final delay = value['responseDelayMs'];
      if (delay != null) {
        final parsed = int.tryParse(delay.toString());
        if (parsed != null && parsed > 0) responseDelays.add(parsed);
      }

      // 발화 길이
      final duration = value['speechDurationMs'];
      if (duration != null) {
        final parsed = int.tryParse(duration.toString());
        if (parsed != null && parsed > 0) speechDurations.add(parsed);
      }

      // 아이의 발화 횟수 세기
      if (value['role'] == 'user' &&
          (value['text']?.toString().trim().isNotEmpty ?? false)) {
        speechCount++;
      }

      messages.add({
        "role": value['role'],
        "text": value['text'],
        "timestamp": value['timestamp'],
      });
    }

    messages.sort((a, b) =>
        a['timestamp'].toString().compareTo(b['timestamp'].toString()));

    // 3. 평균 계산
    final avgResponseDelay = responseDelays.isEmpty
        ? 0
        : (responseDelays.reduce((a, b) => a + b) ~/ responseDelays.length);

    final avgSpeechDuration = speechDurations.isEmpty
        ? 0
        : (speechDurations.reduce((a, b) => a + b) ~/ speechDurations.length);

    debugPrint("[Report] 평균 반응 시간: ${avgResponseDelay}ms");
    debugPrint("[Report] 평균 발화 시간: ${avgSpeechDuration}ms");
    debugPrint("[Report] 총 발화 횟수: $speechCount");

    // 4. GPT 분석
    final prompt = _buildPrompt(messages, avgResponseDelay, avgSpeechDuration);
    final response = await llm.fetchPromptResponse(
      "너는 언어치료 전문가야. 아이와 캐릭터의 대화를 분석해서 리포트를 작성해줘.",
      prompt,
    );

    final parsed = _safeParse(response);

    // 5. Firebase 저장
    await reportRef.update({
      'summary': parsed['summary'] ?? '요약 없음',
      'comment': parsed['comment'] ?? '',
      'averageResponseDelayMs': avgResponseDelay,
      'averageSpeechDurationMs': avgSpeechDuration,
      'speechCount': speechCount,
      'updatedAt': DateTime.now().toIso8601String(),
      'characterName': characterName,
    });

    debugPrint("[Report] 리포트 저장 완료 → $conversationPath");

    // 6. 모델 반환
    return ConversationReport(
      id: reportId,
      summary: parsed['summary'] ?? '요약 없음',
      imageUrl: "",
      imageBase64: "",
      averageResponseDelayMs: avgResponseDelay,
      createdAt: DateTime.now(),
    );
  }

  String _buildPrompt(
      List<Map<String, dynamic>> messages,
      int avgDelayMs,
      int avgSpeechMs,
      ) {
    final dialogue = messages
        .map((m) => "${m['role'] == 'assistant' ? 'AI' : '아이'}: ${m['text']}")
        .join('\n');
    final avgDelaySec = (avgDelayMs / 1000).toStringAsFixed(2);
    final avgSpeechSec = (avgSpeechMs / 1000).toStringAsFixed(2);

    return '''
      다음은 언어치료 세션 중 아이와 AI 캐릭터의 대화입니다.
      아이의 평균 반응 시간은 약 ${avgDelaySec}초,
      평균 발화 시간은 약 ${avgSpeechSec}초입니다.
      이를 참고하여 리포트를 작성해주세요.

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
      debugPrint("[Report] JSON 파싱 실패: $e\n원본: $content");
      return {
        'summary': content,
        'comment': '응답 파싱 실패',
      };
    }
  }

  Future<List<ConversationReport>> loadAllReports(String childName) async {
    try {
      final snapshot = await db.child('reports/$childName').get();

      if (!snapshot.exists) return [];

      final List<ConversationReport> reports = [];
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        reports.add(ConversationReport.fromJson(data));
      }

      return reports;
    } catch (e) {
      debugPrint('[ReportService] loadAllReports 오류: $e');
      return [];
    }
  }

  Future<ConversationReport?> getLatestReport(String childName) async {
    try {
      final reports = await loadAllReports(childName);
      if (reports.isEmpty) return null;

      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports.first;
    } catch (e) {
      debugPrint('[ReportService] getLatestReport 오류: $e');
      return null;
    }
  }
}
