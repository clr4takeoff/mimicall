import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ConversationService {
  final _db = FirebaseDatabase.instance.ref();

  /// Firebase에 대화 메시지를 저장
  Future<void> saveMessage({
    required String dbPath,
    required String role,   // "user" or "assistant"
    required String text,
  }) async {
    try {
      if (text.trim().isEmpty) return;

      // 안전한 Firebase 경로로 변환
      final safePath = dbPath
          .replaceAll('.', '-')
          .replaceAll('#', '-')
          .replaceAll('\$', '-')
          .replaceAll('[', '-')
          .replaceAll(']', '-')
          .replaceAll('T', '_'); // :는 그대로 두되, T만 _로

      // 메시지 ID 생성
      final now = DateTime.now();
      final timestamp = now.toIso8601String().replaceAll('T', '_').split('.').first;
      final msgId = "msg_${timestamp}_$role";

      // 경로 구조
      final msgRef = _db.child('$safePath/conversation/messages/$msgId');

      await msgRef.set({
        'role': role,
        'text': text,
        'timestamp': now.toIso8601String(),
      });

      debugPrint("[Firebase 저장 완료] $safePath/conversation/messages/$msgId");
    } catch (e) {
      debugPrint("[Firebase 저장 오류] $e");
    }
  }
}
