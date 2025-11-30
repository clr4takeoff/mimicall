import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'stt_service.dart';
import 'tts_service.dart';
import 'scenario_service.dart';

class ConversationService {
  final _db = FirebaseDatabase.instance.ref();
  final STTService stt;
  final TTSService tts;
  final ScenarioService scenarioService;

  int turnCount = 0;
  int conversationStage = 1; // 1=라포, 2=도움요청, 3=칭찬및잡담

  ConversationService({
    required this.stt,
    required this.tts,
    required this.scenarioService,
  }) {
    _setupTtsListeners();
  }

  // 3단계에서 2단계로 복귀하는 함수 (InCallScreen에서 Next 버튼 누르면 호출)
  void startNewRound() {
    conversationStage = 2;
    debugPrint("Stage 2로 복귀 (새 라운드)");
  }

  Future<String> getStageInstruction({
    required String username,
    required String characterName,
  }) async {

    if (conversationStage == 2) {
      if (scenarioService.currentContext == null) {
        await scenarioService.loadNewScenario(username);
      }

      final currentSituation = scenarioService.currentContext ?? "도움이 필요한 상황";

      return """
      [중요: 새로운 장면 시작]
      이전의 대화 내용이나 상황은 모두 잊어버려. 지금 새로운 상황극이 시작됐어.
      
      너의 역할: $characterName
      현재 상황: '$currentSituation'
      
      위 상황을 겪고 있어서 아이($username)에게 다급하게 도움을 요청해야 해.
      마치 지금 막 이 일이 벌어진 것처럼 생생하게 연기해줘.
      """;
    }

    switch (conversationStage) {
      case 1:
        return "지금은 1단계야. 아이와 친해지고 편안하게 대화해.";
      case 3:
        return """
        지금은 3단계야. 아이가 미션을 성공해서 기분 좋은 상태야.
        계속해서 아이를 칭찬해주거나, 가벼운 일상 대화를 이어가.
        아직 작별 인사는 하지 마. 아이가 더 놀고 싶어 하니까 즐겁게 받아줘.
        """;
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

  void _updateConversationStage() {
    if (conversationStage == 3 || conversationStage == 2) return;
    // 1, 2단계 자동 전환 로직
    if (turnCount < 3) {
      conversationStage = 1;
    } else {
      conversationStage = 2;
    }
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
      case 3: return "3단계 (칭찬/잡담)";
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
      final safePath = dbPath.replaceAll('.', '-').replaceAll('#', '-').replaceAll('\$', '-').replaceAll('[', '-').replaceAll(']', '-').replaceAll('T', '_');
      final now = timestamp ?? DateTime.now();
      final adjustedTime = role == "user" ? now : now.add(const Duration(milliseconds: 1));
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

      debugPrint("[Firebase] 저장 완료 → $msgId");
    } catch (e) {
      debugPrint("[Firebase] 저장 오류: $e");
    }
  }
}