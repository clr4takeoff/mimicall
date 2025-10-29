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

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? contextText;
  List<String> targetPhrases = [];

  FairyService({
    required this.tts,
    required this.stt,
    required this.gpt,
    this.onFairySpeak,
    this.onChildSpeak,
    this.onFairyComplete,
  });

  /// 요정 모드 시작
  Future<void> startGuidedSession({
    required String username,
    required String characterName,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

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
        contextText =
            data['contextText']?.toString() ?? "작은 문제가 생긴 상황이야.";
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
      String username, String characterName) async {
    if (!_isRunning) return;
    final userName = UserInfo.name ?? username;

    // Environmental Arrangement + Affective Engagement
    final systemPrompt = """
      너는 '요정'이야.
      아이는 3~7세이고, ${characterName}가 곤란한 상황(contextText)에 빠졌어.
      너의 역할은 아이가 ${characterName}를 돕도록 언어적으로 유도하는 거야.

      - 아이의 감정에 공감하고 ("그랬구나~", "속상했겠다~")
      - 상황을 간단히 요약하며 공감적으로 설명
      - 아이가 먼저 반응할 수 있도록 잠시 기다려줘 (Time Delay)
      - 정답은 targetSpeech 리스트에서 참고해줘.
      - 예시는 간단히, 감정 표현은 풍부하게 해줘.
    """;

    final userPrompt = "캐릭터의 상황: ${contextText ?? '무슨 일이 생겼대.'}";
    final intro = await gpt.fetchPromptResponse(systemPrompt, userPrompt);

    onFairySpeak?.call(intro);
    await tts.speak(intro, userName);

    // TTS 완료 후 STT 시작 (타이밍 충돌 방지)
    tts.onComplete = () async {
      if (!_isRunning) return;
      await Future.delayed(const Duration(milliseconds: 400));
      await stt.startListening();
    };

    stt.onResult = (childText) async {
      if (!_isRunning) return;
      await stt.stopListening();
      onChildSpeak?.call(childText);
      debugPrint("[FairyMode] 아이가 먼저 발화: $childText");

      // 아이 반응에 따른 요정 피드백
      final followUpPrompt = """
        아이가 이렇게 말했어: "$childText"
        이에 맞게 요정이 따뜻하게 반응하면서, 
        자연스럽게 목표 발화를 연습하자고 제안해줘.
        targetSpeech 참고: ${targetPhrases.join(', ')}
      """;

      final followUp =
      await gpt.fetchPromptResponse(systemPrompt, followUpPrompt);
      onFairySpeak?.call(followUp);
      await tts.speak(followUp, userName);

      tts.onComplete = () async {
        if (!_isRunning) return;
        await Future.delayed(const Duration(milliseconds: 500));

        // Model + Prompt Fading
        if (targetPhrases.isNotEmpty) {
          await _promptToRepeatWithFading(targetPhrases.first, userName);
        } else {
          final fallback = "지금은 알려줄 말이 없네. 그래도 네가 정말 잘하고 있어!";
          onFairySpeak?.call(fallback);
          await tts.speak(fallback, userName);
          _completeAndReturnToCharacter();
        }
      };
    };
  }

  /// Model + Prompt Fading + Reinforcement
  Future<void> _promptToRepeatWithFading(
      String phrase, String userName, {int attempt = 0}) async {
    if (!_isRunning) return;

    String prompt;
    if (attempt == 0) {
      prompt = "우리 같이 말해볼까? '$phrase'";
    } else if (attempt == 1) {
      prompt = "요정은 안 도와줄게~ 이번엔 혼자 '$phrase' 말해볼까?";
    } else {
      prompt = "기억나? '$phrase'처럼 말하면 될 거야!";
    }

    onFairySpeak?.call(prompt);
    await tts.speak(prompt, userName);

    // TTS 종료 후 STT 시작
    tts.onComplete = () async {
      if (!_isRunning) return;
      await Future.delayed(const Duration(milliseconds: 400));
      await stt.startListening();
    };

    stt.onResult = (text) async {
      if (!_isRunning) return;
      await stt.stopListening();
      onChildSpeak?.call(text);

      if (text.contains(phrase)) {
        // Natural Reinforcement + Affective Engagement
        final praise = "우와~ 완벽해! 이제 이 말을 캐릭터에게 알려주러 가자!";
        onFairySpeak?.call(praise);
        await tts.speak(praise, userName);
        _completeAndReturnToCharacter();
      } else {
        final retry = "괜찮아~ 천천히 다시 한 번 해보자.";
        onFairySpeak?.call(retry);
        await tts.speak(retry, userName);
        await Future.delayed(const Duration(seconds: 1));

        if (_isRunning) {
          await _promptToRepeatWithFading(phrase, userName, attempt: attempt + 1);
        }
      }
    };
  }

  /// 요정 모드 종료 및 캐릭터 화면 복귀
  void _completeAndReturnToCharacter() {
    _isRunning = false;
    debugPrint("[FairyService] 요정 모드 완료 → 캐릭터 화면 복귀 신호 보냄");
    onFairyComplete?.call();
  }

  /// 강제 종료 (TTS/STT 모두 중단)
  Future<void> stopSession() async {
    if (!_isRunning) return;
    _isRunning = false;

    try {
      await tts.stop();
    } catch (_) {}
    try {
      await stt.stopListening();
    } catch (_) {}

    debugPrint("[FairyService] 요정 모드 완전 종료");
  }
}