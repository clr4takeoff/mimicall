import 'tts_service.dart';
import 'stt_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class FairyService {
  final TTSService tts;
  final STTService stt;

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

    // 1단계: 상황 제시
    await tts.speak("요정이 왔어. ${contextText ?? "무슨 일이 생겼대."}");
    await Future.delayed(const Duration(seconds: 1));

    // 2단계: 예시 제시 (모델링)
    final examples = targetPhrases.join(", ");
    await tts.speak("이럴 땐 이렇게 말할 수도 있어. $examples.");
    await Future.delayed(const Duration(seconds: 1));

    // 3단계: 모방 유도 (첫 번째 문장부터 시작)
    if (targetPhrases.isNotEmpty) {
      await _promptToRepeat(targetPhrases.first);
    } else {
      await tts.speak("지금은 예시가 없네. 다음에 같이 해보자.");
      _isRunning = false;
    }
  }

  Future<void> _promptToRepeat(String phrase) async {
    await tts.speak("자, 따라 말해볼까? '$phrase'");
    await Future.delayed(const Duration(seconds: 1));
    await stt.startListening();

    stt.onResult = (text) async {
      await stt.stopListening();
      debugPrint("[FairyMode] User said: $text");

      if (text.contains(phrase)) {
        await tts.speak("정말 잘했어! 바로 그거야!");
        _isRunning = false;
      } else {
        await tts.speak("괜찮아. 다시 천천히 '$phrase' 말해볼까?");
        await Future.delayed(const Duration(seconds: 1));
        await _promptToRepeat(phrase);
      }
    };
  }

  Future<void> stopSession() async {
    _isRunning = false;
    await stt.stopListening();
  }
}
