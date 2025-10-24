import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '/services/stt_service.dart';
import '/services/tts_service.dart';

class ConversationService {
  final _db = FirebaseDatabase.instance.ref();
  final STTService stt;
  final TTSService tts;

  // 아이 발화 카운트
  int turnCount = 0;

  // 대화 단계 (1=라포, 2=도움요청, 3=마무리)
  int conversationStage = 1;

  // 캐릭터 상황 (Firebase에서 불러올 contextText)
  String? contextText;

  ConversationService({
    required this.stt,
    required this.tts,
  }) {
    _setupTtsListeners();
  }

  // Firebase에서 contextText 불러오기
  Future<void> loadCharacterContext(String username) async {
    try {
      final ref = _db.child('preference/$username/character_settings/contextText');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        contextText = snapshot.value.toString();
        debugPrint("[Conversation] Firebase contextText 로드 완료: $contextText");
      } else {
        debugPrint("[Conversation] contextText가 존재하지 않음");
      }
    } catch (e) {
      debugPrint("[Conversation] contextText 로드 오류: $e");
    }
  }

  // TTS 발화 중엔 STT 중지, 끝나면 재시작
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

  // 초기화
  Future<void> initialize() async {
    await stt.initialize();
  }

  // 대화 단계 갱신 로직
  void _updateConversationStage() {
    if (turnCount < 3) {
      conversationStage = 1; // 라포 형성
    } else if (turnCount < 6) {
      conversationStage = 2; // 도움 요청
    } else {
      conversationStage = 3; // 마무리
    }
  }

  // 단계별 프롬프트 반환
  Future<String> getStageInstruction({required String username}) async {
    if (conversationStage == 2) {
      if (contextText == null) {
        await loadCharacterContext(username);
      }
      return "지금은 2단계야. 너는 캐릭터인데, 상황은 '${contextText ?? "작은 문제가 생긴 상황"}' 이야. 아이에게 어떻게 해야 할지 물어봐.";
    }

    switch (conversationStage) {
      case 1:
        return "지금은 1단계야. 아이와 친해지고 편안한 대화를 해줘.";
      case 3:
        return "지금은 3단계야. 아이의 도움으로 문제가 해결됐고, 고맙다고 말하며 대화를 마무리해.";
      default:
        return "항상 따뜻하고 친근하게 대화해줘.";
    }
  }

  // 아이 발화 감지 처리
  void registerUserSpeech(String userText) {
    if (userText.trim().isEmpty) return;

    turnCount++;
    final prevStage = conversationStage;
    _updateConversationStage();

    debugPrint("[Conversation] 사용자 발화 감지 | 턴: $turnCount | 단계: ${_stageName(conversationStage)}");

    if (conversationStage != prevStage) {
      debugPrint("[Conversation] 단계 전환 → ${_stageName(conversationStage)}로 이동");
    }
  }

  String _stageName(int stage) {
    switch (stage) {
      case 1:
        return "1단계 (라포)";
      case 2:
        return "2단계 (도움 요청)";
      case 3:
        return "3단계 (마무리)";
      default:
        return "알 수 없음";
    }
  }

  // Firebase 메시지 저장
  Future<void> saveMessage({
    required String dbPath,
    required String role, // "user" or "assistant"
    required String text,
    DateTime? timestamp,
    Map<String, dynamic>? extra,
  }) async {
    try {
      if (text.trim().isEmpty) return;

      final safePath = dbPath
          .replaceAll('.', '-')
          .replaceAll('#', '-')
          .replaceAll('\$', '-')
          .replaceAll('[', '-')
          .replaceAll(']', '-')
          .replaceAll('T', '_');

      final now = timestamp ?? DateTime.now();
      final msgId = "msg_${now.toIso8601String().replaceAll('T', '_').split('.').first}_$role";

      final msgRef = _db.child('$safePath/conversation/messages/$msgId');

      await msgRef.set({
        'role': role,
        'text': text,
        'timestamp': now.toIso8601String(),
        'turnCount': turnCount,
        'stage': conversationStage,
        ...?extra,
      });

      debugPrint("[Firebase] 저장 완료 → $safePath/conversation/messages/$msgId");
    } catch (e) {
      debugPrint("[Firebase] 저장 오류: $e");
    }
  }
}
