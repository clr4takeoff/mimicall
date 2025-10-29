import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '/services/stt_service.dart';
import '/services/tts_service.dart';

class ConversationService {
  final _db = FirebaseDatabase.instance.ref();
  final STTService stt;
  final TTSService tts;

  int turnCount = 0; // 아이 발화 횟수
  int conversationStage = 1; // 1=라포, 2=도움요청, 3=마무리
  String? contextText; // Firebase에서 불러온 캐릭터 상황
  List<String> targetSpeechList = []; // 목표 발화 문장 목록

  bool isFairyMode = false; // 요정 모드 상태

  ConversationService({
    required this.stt,
    required this.tts,
  }) {
    _setupTtsListeners();
  }

  // Firebase에서 캐릭터 상황(contextText) 불러오기
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

  // Firebase에서 목표 발화(targetSpeech) 불러오기
  Future<void> loadTargetSpeech(String username) async {
    try {
      final ref = _db.child('preference/$username/character_settings/targetSpeech');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final raw = snapshot.value.toString();
        targetSpeechList = raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        debugPrint("[Conversation] targetSpeech 로드 완료: $targetSpeechList");
      } else {
        debugPrint("[Conversation] targetSpeech 없음");
      }
    } catch (e) {
      debugPrint("[Conversation] targetSpeech 로드 실패: $e");
    }
  }

  Future<String> getStageInstruction({
    required String username,
    required String characterName,
  }) async {
    if (isFairyMode) {
      return "현재 요정 모드가 활성화되어 있어. 캐릭터는 대화하지 않고 요정이 아이의 발화를 도와주는 중이야.";
    }

    if (conversationStage == 2) {
      if (contextText == null) {
        await loadCharacterContext(username);
      }
      return """
        지금은 2단계야. 너는 캐릭터 $characterName이고, $username과 대화 중이야.
        너는 '${contextText ?? "작은 문제가 생긴 상황"}' 상황을 겪고 있어 곤란한 상태야.
        이 상황을 설명하면서 어떻게 해야 할지 물어보며 도움을 요청해.
        절대 정답을 이야기해주지 말고, 힌트도 주지 마. 주는 역할은 따로 있어.
        대화 주제도 돌리지 마.
        $username이 널 도와주는 영웅처럼 느끼게 해줘.
        """;
        }

    switch (conversationStage) {
      case 1:
        return "지금은 1단계야. 아이와 친해지고 편안하게 대화해.";
      case 3:
        return "지금은 3단계야. 아이의 도움으로 문제가 해결됐고, 고맙다고 말하며 대화를 마무리해.";
      default:
        return "항상 따뜻하고 친근하게 대화해.";
    }
  }


  // TTS 재생 중 STT를 일시정지
  void _setupTtsListeners() {
    tts.onStart = () async {
      debugPrint("[Conversation] TTS 시작 → STT 일시정지");
      await stt.stopListening(tempStop: true);
    };

    tts.onComplete = () async {
      debugPrint("[Conversation] TTS 완료");
    };
  }

  Future<void> initialize() async {
    await stt.initialize();
  }

  // 요정 모드 활성화/비활성화
  void enableFairyMode() {
    isFairyMode = true;
    debugPrint("[Conversation] 요정 모드 활성화");
  }

  void disableFairyMode() {
    isFairyMode = false;
    debugPrint("[Conversation] 요정 모드 비활성화");
  }

  // 대화 단계 갱신
  // 1~2단계는 turnCount 기준으로 자동 진행
  // 3단계는 목표 발화 조건을 충족해야 진입 가능
  void _updateConversationStage() {
    if (turnCount < 3) {
      conversationStage = 1; // 라포 형성
    } else if (turnCount < 6) {
      conversationStage = 2; // 도움 요청
    } else {
      conversationStage = 2; // 기본적으로 2단계 유지 (자동으로 3단계 전환 금지)
    }
  }

  // 아이 발화 감지 시 처리
  void registerUserSpeech(String userText) {
    if (userText.trim().isEmpty) return;

    turnCount++;

    if (isFairyMode) {
      debugPrint("[Conversation] 요정 모드 중이므로 단계 변경 생략");
      return;
    }

    final prevStage = conversationStage;
    _updateConversationStage();

    // 2단계에서 목표 발화와 유사한 문장을 말한 경우 3단계로 전환
    if (conversationStage == 2 && _isSimilarToTargetSpeech(userText)) {
      conversationStage = 3;
      debugPrint("[Conversation] 아이가 목표 발화를 유사하게 말함 → 3단계 전환");
    }

    debugPrint("[Conversation] 발화 감지 | 턴: $turnCount | 단계: ${_stageName(conversationStage)}");

    if (conversationStage != prevStage) {
      debugPrint("[Conversation] 단계 전환 → ${_stageName(conversationStage)}");
    }
  }

  // 목표 발화와의 유사도 검사
  bool _isSimilarToTargetSpeech(String userText) {
    if (targetSpeechList.isEmpty) return false;

    final normalizedUser = userText.replaceAll(RegExp(r'\s+'), '').toLowerCase();

    for (final target in targetSpeechList) {
      final normalizedTarget = target.replaceAll(RegExp(r'\s+'), '').toLowerCase();

      // 포함 관계면 바로 true
      if (normalizedUser.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedUser)) {
        return true;
      }

      // Levenshtein 거리 기반 유사도 검사
      final distance = _levenshteinDistance(normalizedUser, normalizedTarget);
      final maxLen = normalizedUser.length > normalizedTarget.length
          ? normalizedUser.length
          : normalizedTarget.length;
      final similarity = 1 - (distance / maxLen);

      if (similarity > 0.7) return true;
    }

    return false;
  }

  // 문자열 유사도 계산 (Levenshtein 거리)
  int _levenshteinDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1, // 삭제
          dp[i][j - 1] + 1, // 삽입
          dp[i - 1][j - 1] + cost, // 교체
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[m][n];
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

  // Firebase에 대화 내용 저장
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
      final adjustedTime = role == "user"
          ? now
          : now.add(const Duration(milliseconds: 1));

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

  // 요정 모드 종료 후 초기화
  void resetContext() {
    debugPrint("[Conversation] 요정 모드 종료 후 컨텍스트 초기화");
    isFairyMode = false;
    _setupTtsListeners();
  }
}
