import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '/services/stt_service.dart';
import '/services/tts_service.dart';
import '/services/llm_service.dart'; // [추가] GPTResponse 타입을 위해 필요

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
    // 예시: 1~2턴(1단계), 3턴 이상(2단계)
    if (turnCount < 3) {
      conversationStage = 1;
    } else {
      conversationStage = 2;
    } // 3단계 삭제
  }

  void registerUserSpeech(String userText) {
    if (userText.trim().isEmpty) return;

    turnCount++;

    final prevStage = conversationStage;
    _updateConversationStage();

    debugPrint("[Conversation] 발화 감지 | 턴: $turnCount | 단계: ${_stageName(conversationStage)}");

    if (conversationStage != prevStage) {
      debugPrint("[Conversation] 단계 전환 → ${_stageName(conversationStage)}");
    }
  }

  String _stageName(int stage) {
    switch (stage) {
      case 1: return "1단계 (라포)";
      case 2: return "2단계 (도움 요청)";
      case 3: return "3단계 (마무리)";
      default: return "알 수 없음";
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

  // DB에서 목표 발화(Target Speech) 가져오기
  Future<String?> getTargetSpeech(String username) async {
    try {
      // 1. 현재 로드된 컨텍스트가 없으면 재로딩 시도
      if (contextText == null) {
        await loadCharacterContext(username);
      }
      if (contextText == null) return null;

      // 2. DB에서 contextList와 targetList 전체를 가져옴
      final ref = _db.child('preference/$username/character_settings');
      final snapshot = await ref.get();

      if (!snapshot.exists) return null;

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      final List<dynamic> contextList = List.from(data['contextList'] ?? []);
      final List<dynamic> targetList = List.from(data['targetList'] ?? []);

      // 3. 현재 contextText가 contextList의 몇 번째인지 인덱스 찾기
      int index = -1;
      for (int i = 0; i < contextList.length; i++) {
        // DB 저장 형식에 따라 문자열 비교
        if (contextList[i].toString() == contextText) {
          index = i;
          break;
        }
      }

      // 4. 매칭되는 인덱스가 있고, targetList에도 해당 인덱스가 있다면 반환
      if (index != -1 && index < targetList.length) {
        final targetSpeech = targetList[index].toString();
        debugPrint("[Conversation] 목표 발화 찾음: $targetSpeech (인덱스: $index)");
        return targetSpeech;
      } else {
        debugPrint("[Conversation] 매칭되는 목표 발화를 찾을 수 없음 (Context: $contextText)");
        return null;
      }
    } catch (e) {
      debugPrint("[Conversation] 목표 발화 로드 중 오류: $e");
      return null;
    }
  }
}