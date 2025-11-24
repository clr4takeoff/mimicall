import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '/services/stt_service.dart';
import '/services/tts_service.dart';

class ConversationService {
  final _db = FirebaseDatabase.instance.ref();
  final STTService stt;
  final TTSService tts;

  int turnCount = 0;
  int conversationStage = 1; // 1=라포, 2=도움요청, 3=마무리
  String? contextText;

  ConversationService({
    required this.stt,
    required this.tts,
  }) {
    _setupTtsListeners();
  }

  Future<void> loadCharacterContext(String username) async {
    try {
      final ref = _db.child('preference/$username/character_settings/contextText');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        contextText = snapshot.value.toString();
        debugPrint("[Conversation] contextText 로드 완료: $contextText");
      } else {
        debugPrint("[Conversation] contextText 없음");
      }
    } catch (e) {
      debugPrint("[Conversation] contextText 로드 실패: $e");
    }
  }

  Future<String> getStageInstruction({
    required String username,
    required String characterName,
  }) async {
    // 2단계 (도움 요청) 로직
    if (conversationStage == 2) {
      if (contextText == null) {
        await loadCharacterContext(username);
      }
      return """
      지금은 2단계야. 너는 캐릭터 $characterName이고, $username과 대화 중이야.
      너는 '${contextText ?? "작은 문제가 생긴 상황"}' 상황을 겪고 있어 곤란한 상태야.
      이 상황을 설명하면서 도움을 요청해.
      $username이 너를 도와주는 영웅처럼 느끼게 해줘.
      """;
    }

    // 그 외 단계 로직
    switch (conversationStage) {
      case 1:
        return "지금은 1단계야. 아이와 친해지고 편안하게 대화해.";
      case 3:
        return "지금은 3단계야. 아이가 너의 문제를 해결해줬어. 이제 고맙다고 말하며 자연스럽게 대화를 마무리해.";
      default:
        return "항상 따뜻하고 친근하게 대화해.";
    }
  }

  void _setupTtsListeners() {
    tts.onStart = () async {
      debugPrint("[Conversation] TTS 시작 → STT 일시정지");
      await stt.stopListening(tempStop: true);
    };

    tts.onComplete = () async {
      debugPrint("[Conversation] TTS 완료 → STT 재시작 대기");
    };
  }

  Future<void> initialize() async {
    await stt.initialize();
  }

  // 턴 수에 따라 단계를 변경하는 로직
  void _updateConversationStage() {
    // 예시: 1~2턴(1단계), 3~5턴(2단계), 10턴 이상(3단계)
    if (turnCount < 3) {
      conversationStage = 1;
    } else if (turnCount < 10) {
      conversationStage = 2;
    } else {
      conversationStage = 3; // TODO: 2단계 로직 구성 후 next버튼을 통해 도달할 수 있게 수정
    }
  }

  void registerUserSpeech(String userText) {
    if (userText.trim().isEmpty) return;

    turnCount++;

    final prevStage = conversationStage;

    // 복잡한 검사 없이 턴 수만 확인하여 단계 업데이트로 구현
    _updateConversationStage();

    debugPrint("[Conversation] 발화 감지 | 턴: $turnCount | 단계: ${_stageName(conversationStage)}");

    if (conversationStage != prevStage) {
      debugPrint("[Conversation] 단계 전환 → ${_stageName(conversationStage)}");
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

  Future<void> saveMessage({
    required String dbPath,
    required String role,
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
      final adjustedTime =
      role == "user" ? now : now.add(const Duration(milliseconds: 1));

      final msgId =
          "msg_${adjustedTime.toIso8601String().replaceAll('T', '_').split('.').first}_$role";
      final msgRef = _db.child('$safePath/conversation/messages/$msgId');

      await msgRef.set({
        'role': role,
        'text': text,
        'timestamp': adjustedTime.toIso8601String(),
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