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
  List<String> targetSpeechList = [];

  bool isFairyMode = false;

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
      return "현재 요정 모드야. 캐릭터는 대화하지 않고 요정이 아이 발화를 돕고 있어.";
    }

    if (conversationStage == 2) {
      if (contextText == null) {
        await loadCharacterContext(username);
      }
      return """
      지금은 2단계야. 너는 캐릭터 $characterName이고, $username과 대화 중이야.
      너는 '${contextText ?? "작은 문제가 생긴 상황"}' 상황을 겪고 있어 곤란한 상태야.
      이 상황을 설명하면서 도움을 요청해.
      정답은 말하지 말고, 힌트도 주지 마.
      $username이 너를 도와주는 영웅처럼 느끼게 해줘.
      """;
    }

    switch (conversationStage) {
      case 1:
        return "지금은 1단계야. 아이와 친해지고 편안하게 대화해.";
      case 3:
        return "지금은 3단계야. 아이가 도와줘서 문제가 해결됐어. 고맙다고 말하며 대화를 마무리해.";
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
      if (isFairyMode) {
        debugPrint("[Conversation] Fairy mode active → STT 자동 시작 생략");
        return;
      }
      debugPrint("[Conversation] TTS 완료 → STT 재시작 대기");
    };
  }

  Future<void> initialize() async {
    await stt.initialize();
  }

  void enableFairyMode() {
    isFairyMode = true;
    debugPrint("[Conversation] 요정 모드 활성화");
  }

  void disableFairyMode() {
    isFairyMode = false;
    debugPrint("[Conversation] 요정 모드 비활성화");
  }

  void _updateConversationStage() {
    if (turnCount < 3) {
      conversationStage = 1;
    } else if (turnCount < 6) {
      conversationStage = 2;
    } else {
      conversationStage = 2;
    }
  }

  void registerUserSpeech(String userText) {
    if (userText.trim().isEmpty) return;

    turnCount++;

    if (isFairyMode) {
      debugPrint("[Conversation] 요정 모드 중 → 단계 변경 생략");
      return;
    }

    final prevStage = conversationStage;
    _updateConversationStage();

    final matched = _isSimilarToTargetSpeech(userText);
    if (conversationStage == 2 && matched) {
      conversationStage = 3;
      debugPrint("[Conversation] 목표 발화 유사 감지 → 3단계 전환");
    } else {
      debugPrint("[Conversation] 발화 감지 | 턴: $turnCount | 단계: ${_stageName(conversationStage)}");
    }

    if (conversationStage != prevStage) {
      debugPrint("[Conversation] 단계 전환 → ${_stageName(conversationStage)}");
    }
  }

  bool _isSimilarToTargetSpeech(String userText) {
    if (targetSpeechList.isEmpty) {
      debugPrint("[Conversation] targetSpeechList 비어 있음 (Firebase 로드 실패 가능)");
      return false;
    }

    final normalizedUser = userText.replaceAll(RegExp(r'[\s,.!?]'), '').toLowerCase();

    for (final target in targetSpeechList) {
      final normalizedTarget = target.replaceAll(RegExp(r'[\s,.!?]'), '').toLowerCase();

      if (normalizedUser.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedUser)) {
        debugPrint("[Conversation] 직접 포함 매칭 감지: $target");
        return true;
      }

      final distance = _levenshteinDistance(normalizedUser, normalizedTarget);
      final maxLen = normalizedUser.length > normalizedTarget.length
          ? normalizedUser.length
          : normalizedTarget.length;
      final similarity = 1 - (distance / maxLen);

      if (similarity > 0.6) {
        debugPrint("[Conversation] 유사도 매칭 감지 ($similarity): $target");
        return true;
      }
    }

    debugPrint("[Conversation] 목표 문장 불일치: $userText");
    return false;
  }

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
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
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

  void resetContext() {
    debugPrint("[Conversation] 요정 모드 종료 후 컨텍스트 초기화");
    isFairyMode = false;
    _setupTtsListeners();
  }
}
