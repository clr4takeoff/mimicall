import 'tts_service.dart';
import 'stt_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/user_info.dart';

class FairyService {
  final TTSService tts;
  final STTService stt;

  // UI 업데이트용 콜백
  Function(String)? onFairySpeak;
  Function(String)? onChildSpeak;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? contextText;
  List<String> targetPhrases = [];

  FairyService({required this.tts, required this.stt});

  Future<void> startGuidedSession({
    required String context,
    required List<String> targets,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    contextText = context;
    targetPhrases = targets;

    debugPrint("[FairyService] 요정 모드 시작");
    await _runFairyFlow();
  }

  Future<void> _runFairyFlow() async {
    if (!_isRunning) return;

    final userName = UserInfo.name ?? "unknown";

    // 1단계: 상황 제시
    if (!_isRunning) return;
    final fairyLine1 = "요정이 왔어. ${contextText ?? "무슨 일이 생겼대."}";
    onFairySpeak?.call(fairyLine1);
    await tts.speak(fairyLine1, userName);
    if (!_isRunning) return;

    await Future.delayed(const Duration(seconds: 1));
    if (!_isRunning) return;

    // 2단계: 예시 제시
    final examples = targetPhrases.join(", ");
    final fairyLine2 = "이럴 땐 이렇게 말할 수도 있어. $examples.";
    onFairySpeak?.call(fairyLine2);
    await tts.speak(fairyLine2, userName);
    if (!_isRunning) return;

    await Future.delayed(const Duration(seconds: 1));
    if (!_isRunning) return;

    // 3단계: 모방 유도
    if (targetPhrases.isNotEmpty) {
      await _promptToRepeat(targetPhrases.first, userName);
    } else {
      if (!_isRunning) return;
      final fairyLine3 = "지금은 예시가 없네. 다음에 같이 해보자.";
      onFairySpeak?.call(fairyLine3);
      await tts.speak(fairyLine3, userName);
      _isRunning = false;
    }
  }

  Future<void> _promptToRepeat(String phrase, String userName) async {
    if (!_isRunning) return;

    final fairyLine = "자, 따라 말해볼까? '$phrase'";
    onFairySpeak?.call(fairyLine);
    await tts.speak(fairyLine, userName);
    if (!_isRunning) return;

    await Future.delayed(const Duration(seconds: 1));
    if (!_isRunning) return;

    await stt.startListening();

    stt.onResult = (text) async {
      if (!_isRunning) return;

      await stt.stopListening();
      debugPrint("[FairyMode] User said: $text");
      onChildSpeak?.call(text);

      if (!_isRunning) return;

      if (text.contains(phrase)) {
        final success = "정말 잘했어! 바로 그거야!";
        onFairySpeak?.call(success);
        await tts.speak(success, userName);
        _isRunning = false;
      } else {
        if (!_isRunning) return;
        final retry = "괜찮아. 다시 천천히 '$phrase' 말해볼까?";
        onFairySpeak?.call(retry);
        await tts.speak(retry, userName);
        if (!_isRunning) return;
        await Future.delayed(const Duration(seconds: 1));
        if (_isRunning) {
          await _promptToRepeat(phrase, userName);
        }
      }
    };
  }

  /// 완전한 중단 (TTS/STT 모두 즉시 정지)
  Future<void> stopSession() async {
    if (!_isRunning) return;

    debugPrint("[FairyService] 요정 모드 즉시 중단 요청");
    _isRunning = false;

    try {
      await tts.stop();
    } catch (_) {
      debugPrint("[FairyService] TTS 정지 중 예외 무시");
    }

    try {
      await stt.stopListening();
    } catch (_) {
      debugPrint("[FairyService] STT 정지 중 예외 무시");
    }

    debugPrint("[FairyService] 모든 TTS/STT 중단 완료");
  }
}
