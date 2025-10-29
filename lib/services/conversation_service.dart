import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '/services/stt_service.dart';
import '/services/tts_service.dart';

class ConversationService {
  final _db = FirebaseDatabase.instance.ref();
  final STTService stt;
  final TTSService tts;

  int turnCount = 0; // 아이 발화 카운트
  int conversationStage = 1; // 1=라포, 2=도움요청, 3=마무리
  String? contextText; // Firebase에서 불러올 캐릭터 상황

  bool isFairyMode = false; // 요정 모드 여부

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
      debugPrint("[Conversation] TTS 완료");
    };
  }

  // 초기화
  Future<void> initialize() async {
    await stt.initialize();
  }

  // 요정 모드 제어
  void enableFairyMode() {
    isFairyMode = true;
    debugPrint("[Conversation] 요정 모드 활성화");
  }

  void disableFairyMode() {
    isFairyMode = false;
    debugPrint("[Conversation] 요정 모드 비활성화");
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
  Future<String> getStageInstruction({required String username, required String characterName,}) async {
    if (isFairyMode) {
      return "현재 요정 모드가 활성화되어 있어. 캐릭터는 대화하지 않고 요정이 아이의 발화를 도와주는 중이야.";
    }

    if (conversationStage == 2) {
      if (contextText == null) {
        await loadCharacterContext(username);
      }
      return """지금은 2단계야. 너는 캐릭터 ${characterName}이고, ${username}과 대화중이야.
      너는 '${contextText ?? "작은 문제가 생긴 상황"}' 상황을 겪고 있어 곤란한 상황이야.
      이 곤란함을 이야기하면서 이런 상황에서는 어떻게 말해야 할지 물어보며 도움을 요청해.
      대화를 유도하며 ${username}를 널 구하는 영웅으로 만들어주어야 해.""";


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

    // turnCount는 항상 증가 (요정 모드에서도)
    turnCount++;

    // 요정 모드일 경우 대화 단계는 고정
    if (isFairyMode) {
      debugPrint("[Conversation] 요정 모드 중: turnCount 증가, 단계 변경은 생략됨");
      return;
    }

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

      // 역할별로 1ms 오프셋 추가
      final adjustedTime = role == "user"
          ? now
          : now.add(const Duration(milliseconds: 1)); // assistant은 +1ms

      final msgId = "msg_${adjustedTime.toIso8601String().replaceAll('T', '_').split('.').first}_$role";

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


  // 요정모드 종료 후 정상 대화 복귀용 초기화
  void resetContext() {
    debugPrint("[Conversation] 대화 컨텍스트 일부 초기화 (요정 모드 종료 후 복귀)");

    isFairyMode = false;

    // turnCount, conversationStage 유지!
    _setupTtsListeners();

    debugPrint("[Conversation] 요정 모드 종료 → 기존 대화 맥락 유지하며 복귀 완료");
  }


}
