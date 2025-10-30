/// FairyService (Milieu Teaching + NDBI 기반)
/// Milieu Teaching: Model, Mand, Time Delay, Environmental Arrangement, Reinforcement
/// NDBI: Child-Initiated Episode, Shared Control, Natural Reinforcement, Prompt Fading, Affective Engagement
/// References:
/// - Kim, J. & Choi, B. (2003)
/// - Schreibman, L., et al. (2015)

import 'tts_service.dart';
import 'stt_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/user_info.dart';
import 'package:firebase_database/firebase_database.dart';
import 'llm_service.dart';

class FairyService {
  final TTSService tts;
  final STTService stt;
  final GPTResponse gpt;

  /// UI 업데이트용 콜백
  Function(String)? onFairySpeak;
  Function(String)? onChildSpeak;
  Function()? onFairyComplete; // 요정 모드 종료 후 캐릭터 화면 복귀 트리거

  /// 마이크 활성 신호: Fairy가 "이제 아이 차례"라고 알려줄 때 호출
  Function()? onReadyForMic;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 현재 사용자 차례인지 표시 (버튼을 통한 STT만 허용)
  bool _awaitingUser = false;

  /// 따라 말하기 단계에서의 타겟 문장 (있으면 반복 판정에 사용)
  String? _repeatTargetPhrase;

  String? contextText;
  List<String> targetPhrases = [];

  FairyService({
    required this.tts,
    required this.stt,
    required this.gpt,
    this.onFairySpeak,
    this.onChildSpeak,
    this.onFairyComplete,
    this.onReadyForMic,
  });

  /// 요정 모드 시작
  Future<void> startGuidedSession({
    required String username,
    required String characterName,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    _awaitingUser = false;
    _repeatTargetPhrase = null;

    await _loadContextAndTargets(username);
    await _runHybridInteraction(username, characterName);
  }

  /// Firebase에서 캐릭터 상황 및 목표 발화 불러오기
  Future<void> _loadContextAndTargets(String username) async {
    try {
      final db =
      FirebaseDatabase.instance.ref('preference/$username/character_settings');
      final snapshot = await db.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        contextText = data['contextText']?.toString() ?? "작은 문제가 생긴 상황이야.";
        final raw = data['targetSpeech']?.toString() ?? "";
        targetPhrases = raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      debugPrint(
          "[FairyService] Firebase 로드 완료 → contextText: $contextText | targetPhrases: $targetPhrases");
    } catch (e) {
      debugPrint("[FairyService] Firebase 로드 실패: $e");
      contextText = "무슨 일이 생겼대.";
      targetPhrases = [];
    }
  }

  /// 하이브리드 요정 대화 흐름 (Milieu + NDBI)
  Future<void> _runHybridInteraction(
      String username,
      String characterName,
      ) async {
    if (!_isRunning) return;
    final userName = UserInfo.name ?? username;

    // Environmental Arrangement + Affective Engagement
    final systemPrompt = """
      너는 '요정'이야.
      아이는 3~7세이고, ${characterName}가 곤란한 상황${contextText}에 빠졌어.
      너의 역할은 아이가 ${characterName}를 돕도록 언어적으로 유도하는 거야.

      - 아이의 감정에 공감하고 ("그랬구나~", "속상했겠다~")
      - 상황을 간단히 요약하며 공감적으로 설명
      - 아이가 먼저 반응할 수 있도록 잠시 기다려줘 (Time Delay)
      - 정답은 targetSpeech 리스트에서 참고해줘.
      - 예시는 간단히, 감정 표현은 풍부하게 해줘.
      - 출력 문장은 3문장 이내로 해줘.
    """;

    final userPrompt = "캐릭터의 상황: ${contextText ?? '무슨 일이 생겼대.'}";
    final intro = await gpt.fetchPromptResponse(systemPrompt, userPrompt);

    onFairySpeak?.call(intro);
    await tts.speak(intro, userName, isFairyMode: true);


    // TTS 완료 후 Time Delay를 두고 사용자 차례 신호만 보냄
    tts.onComplete = () async {
      if (!_isRunning) return;
      debugPrint("[FairyService] TTS 완료 → Time Delay 대기 중...");
      await Future.delayed(const Duration(seconds: 2));
      _awaitingUser = true;
      debugPrint("[FairyService] Time Delay 종료 → 사용자 차례 대기 (자동 마이크 X)");
    };

  }

  /// InCallScreen에서 버튼으로 녹음 종료 후 전달되는 사용자 발화 처리
  /// Child-Initiated Episode + Shared Control
  Future<void> handleUserText(
      String childText,
      String characterName,
      String userName,
      ) async {
    if (!_isRunning || !_awaitingUser) {
      debugPrint("[FairyService] handleUserText 무시: running=$_isRunning, awaitingUser=$_awaitingUser");
      return;
    }
    _awaitingUser = false;

    onChildSpeak?.call(childText);
    debugPrint("[FairyService] 사용자의 자발적 발화 수신: $childText");

    // targetSpeech(목표 문장) 달성 여부 확인
    final matchedPhrase = targetPhrases.firstWhere(
          (p) => p.isNotEmpty && childText.contains(p),
      orElse: () => "",
    );

    if (matchedPhrase.isNotEmpty) {
      final praise = "우와~ 완벽해! '${matchedPhrase}'라고 정말 잘 말했어! 이제 이 말을 캐릭터에게 알려주러 가자!";
      onFairySpeak?.call(praise);
      await tts.speak(praise, userName, isFairyMode: true);


      // 더 이상 사용자 차례 X (요정 말만 하고 정지)
      tts.onComplete = () async {
        if (!_isRunning) return;
        _awaitingUser = false;
        debugPrint("[FairyService] 목표 문장 성공 발화 후 — 대기 종료 (다음 입력 받지 않음)");
      };
      return;
    }


    // (목표 문장 아직 아님) → GPT 기반 피드백/유도 대화 계속
    final targetSpeechHint =
    targetPhrases.isNotEmpty ? targetPhrases.join(', ') : "특정 목표 문장 없음";

    final systemPrompt = """
  너는 '요정'이야.
  ${characterName}가 ${contextText}에 처했을 때,
  아이가 스스로 도와주려는 말을 하도록 자연스럽게 유도해줘.
  - 참고할 목표 문장: $targetSpeechHint
  - 명령하지 말고 따뜻하고 공감적으로 말하기
  - 아이의 감정에 반응해주기
  - 너무 길지 않게 2~3문장 이내로 대답하기
  """;

    final followUpPrompt = """
  아이가 이렇게 말했어: "$childText"
  이에 맞게 요정이 자연스럽게 대답해줘.
  """;
    debugPrint("🧚 [FairyService] === GPT 호출 시작 ===");
    debugPrint("👶 STT 결과 (아이 발화): $childText");
    debugPrint("📜 System Prompt ↓↓↓\n$systemPrompt");
    debugPrint("💬 Follow-up Prompt ↓↓↓\n$followUpPrompt");


    final followUp = await gpt.fetchPromptResponse(systemPrompt, followUpPrompt);

    onFairySpeak?.call(followUp);

    tts.onComplete = () async {
      if (!_isRunning) return;
      _awaitingUser = true;
      debugPrint("[FairyService] 요정 발화 종료 → 사용자 차례 대기 (자동 마이크 X)");
    };

    await tts.speak(followUp, userName, isFairyMode: true);

  }






  /// Model + Prompt Fading + Reinforcement
  Future<void> _promptToRepeatWithFading(
      String phrase,
      String userName, {
        int attempt = 0,
      }) async {
    if (!_isRunning) return;

    String prompt;
    if (attempt == 0) {
      prompt = "우리 같이 말해볼까? '$phrase'";
    } else if (attempt == 1) {
      prompt = "요정은 안 도와줄게~ 이번엔 혼자 '$phrase' 말해볼까?";
    } else {
      prompt = "기억나? '$phrase'처럼 말하면 될 거야!";
    }

    _repeatTargetPhrase = phrase;

    onFairySpeak?.call(prompt);
    await tts.speak(prompt, userName, isFairyMode: true);


    // 자동 STT 시작 금지. TTS 종료 후 잠시 대기하고 PTT 버튼 허용 신호만 보냄.
    tts.onComplete = () async {
      if (!_isRunning) return;
      await Future.delayed(const Duration(milliseconds: 400));
      _awaitingUser = true;
      onReadyForMic?.call();
      debugPrint("[FairyService] 따라 말하기 차례 → onReadyForMic 호출");
    };
  }

  /// 따라 말하기 결과를 InCallScreen이 넘겨줌 (버튼 기반 PTT)
  Future<void> handleRepeatResult(
      String userText,
      String userName,
      ) async {
    if (!_isRunning || !_awaitingUser) {
      debugPrint("[FairyService] handleRepeatResult 무시: running=$_isRunning, awaitingUser=$_awaitingUser");
      return;
    }
    _awaitingUser = false;

    onChildSpeak?.call(userText);

    final phrase = _repeatTargetPhrase ?? "";
    if (phrase.isNotEmpty && userText.contains(phrase)) {
      // Natural Reinforcement + Affective Engagement
      final praise = "우와~ 완벽해! 이제 이 말을 캐릭터에게 알려주러 가자!";
      onFairySpeak?.call(praise);
      await tts.speak(praise, userName, isFairyMode: true);
      _completeAndReturnToCharacter();
    } else {
      final retry = "괜찮아~ 천천히 다시 한 번 해보자.";
      onFairySpeak?.call(retry);
      await tts.speak(retry, userName, isFairyMode: true);

      // 재도전 기회 제공
      await Future.delayed(const Duration(seconds: 1));
      if (_isRunning && phrase.isNotEmpty) {
        await _promptToRepeatWithFading(phrase, userName, attempt: 1);
      }
    }
  }

  /// 요정 모드 종료 및 캐릭터 화면 복귀
  void _completeAndReturnToCharacter() {
    _isRunning = false;
    _awaitingUser = false;
    _repeatTargetPhrase = null;
    debugPrint("[FairyService] 요정 모드 완료 → 캐릭터 화면 복귀 신호 보냄");
    onFairyComplete?.call();
  }

  /// 강제 종료 (TTS/STT 모두 중단)
  Future<void> stopSession() async {
    if (!_isRunning) return;
    _isRunning = false;
    _awaitingUser = false;
    _repeatTargetPhrase = null;

    try {
      await tts.stop();
    } catch (_) {}
    try {
      await stt.stopListening();
    } catch (_) {}

    tts.onComplete = null;
    tts.onStart = null;
    debugPrint("[FairyService] 요정 모드 완전 종료");
  }
}
