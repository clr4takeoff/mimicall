import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '/services/stt_service.dart';
import '/services/tts_service.dart';

class ConversationService {
  final _db = FirebaseDatabase.instance.ref();
  final STTService stt;
  final TTSService tts;

  ConversationService({
    required this.stt,
    required this.tts,
  }) {
    _setupTtsListeners();
  }

  /// TTS 발화 중에는 STT 일시정지 / 완료 후 재개
  void _setupTtsListeners() {
    tts.onStart = () async {
      debugPrint("[Conversation] TTS 시작 → STT 일시정지");
      await stt.stopListening(tempStop: true);
    };

    tts.onComplete = () async {
      debugPrint("[Conversation] TTS 완료 → STT 재개");
      await Future.delayed(const Duration(seconds: 2));
      await stt.startListening();
    };
  }

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    await stt.initialize();
  }

  /// Firebase에 대화 메시지 저장
  Future<void> saveMessage({
    required String dbPath,
    required String role,   // "user" or "assistant"
    required String text,
    DateTime? timestamp,
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
          .replaceAll('T', '_');

      // 메시지 ID 생성
      final now = timestamp ?? DateTime.now();
      final msgId = "msg_${now.toIso8601String().replaceAll('T', '_').split('.').first}_$role";

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
