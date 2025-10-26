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

    await _runFairyFlow();
  }

  Future<void> _runFairyFlow() async {
    if (!_isRunning) return;

    final userName = UserInfo.name ?? "unknown";

    // 1단계: 상황 제시
    final fairyLine1 = "요정이 왔어. ${contextText ?? "무슨 일이 생겼대."}";
    onFairySpeak?.call(fairyLine1);
    await tts.speak(fairyLine1, userName);
    await Future.delayed(const Duration(seconds: 1));

    // 2단계: 예시 제시
    final examples = targetPhrases.join(", ");
    final fairyLine2 = "이럴 땐 이렇게 말할 수도 있어. $examples.";
    onFairySpeak?.call(fairyLine2);
    await tts.speak(fairyLine2, userName);
    await Future.delayed(const Duration(seconds: 1));

    // 3단계: 모방 유도
    if (targetPhrases.isNotEmpty) {
      await _promptToRepeat(targetPhrases.first, userName);
    } else {
      final fairyLine3 = "지금은 예시가 없네. 다음에 같이 해보자.";
      onFairySpeak?.call(fairyLine3);
      await tts.speak(fairyLine3, userName);
      _isRunning = false;
    }
  }

  Future<void> _promptToRepeat(String phrase, String userName) async {
    final fairyLine = "자, 따라 말해볼까? '$phrase'";
    onFairySpeak?.call(fairyLine);
    await tts.speak(fairyLine, userName);
    await Future.delayed(const Duration(seconds: 1));
    await stt.startListening();

    stt.onResult = (text) async {
      await stt.stopListening();
      debugPrint("[FairyMode] User said: $text");

      // 아이 발화 표시
      onChildSpeak?.call(text);

      if (text.contains(phrase)) {
        final success = "정말 잘했어! 바로 그거야!";
        onFairySpeak?.call(success);
        await tts.speak(success, userName);
        _isRunning = false;
      } else {
        final retry = "괜찮아. 다시 천천히 '$phrase' 말해볼까?";
        onFairySpeak?.call(retry);
        await tts.speak(retry, userName);
        await Future.delayed(const Duration(seconds: 1));
        await _promptToRepeat(phrase, userName);
      }
    };
  }

  Future<void> stopSession() async {
    _isRunning = false;
    await stt.stopListening();
  }
}
