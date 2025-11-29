import 'package:flutter/foundation.dart';
import 'scenario_service.dart';
import 'llm_service.dart';

/// 미션 결과 타입 정의
enum MissionResultType {
  retry,    // 3회 미만: 단순 재시도
  hintMode, // 3회 도달: 모방 유도(힌트) 멘트 생성됨
}

/// 미션 수행 결과 객체
class MissionResult {
  final MissionResultType type;
  final String? message; // hintMode일 때 생성된 멘트가 담김

  MissionResult({required this.type, this.message});
}

class MissionService {
  int _failureCount = 0;
  static const int maxFailures = 3;

  /// 실패 처리 메인 로직
  Future<MissionResult> handleFailure({
    required String userName,
    required ScenarioService scenarioService, // 데이터는 여기서 가져옴
    required GPTResponse gpt,                 // 멘트 생성은 얘가 함
  }) async {
    _failureCount++;
    debugPrint("[MissionService] 실패 카운트: $_failureCount / $maxFailures");

    // 1. 아직 기회가 남은 경우 (재시도)
    if (_failureCount < maxFailures) {
      return MissionResult(type: MissionResultType.retry);
    }

    // 2. 3회 도달 -> 모방 유도(힌트) 로직 실행
    debugPrint("[MissionService] 3회 누적 - 모방 유도 로직 실행");
    _failureCount = 0; // 카운트 초기화

    // ScenarioService에 이미 저장된 목표 발화를 가져옴 (DB 조회 X)
    final targetSpeech = scenarioService.currentTargetSpeech;

    String guideMessage;

    if (targetSpeech != null) {
      // B. 힌트 프롬프트 구성
      final hintInstruction = """
      아이가 대답을 3번이나 어려워하고 있어. 지금은 아이가 자신감을 잃지 않게 도와줘야 해.
      네가 아이에게 정답을 직접적으로 알려줘.
      반드시 아이가 따라 할 수 있게 정확히 이렇게 말해줘: "나를 따라해봐. '$targetSpeech'"
      그리고 아주 따뜻하게 격려해줘.
      """;

      debugPrint("[MissionService] GPT 힌트 생성 요청 (목표: $targetSpeech)");

      // C. GPT 호출
      guideMessage = await gpt.sendMessageToLLM(
        "(아이가 대답을 못해서 힌트가 필요해)",
        stageInstruction: hintInstruction,
      );
    } else {
      // 목표 발화가 없는 예외 상황
      guideMessage = "괜찮아, 천천히 말해도 돼. 우리 같이 다시 해볼까?";
    }

    // 결과 반환
    return MissionResult(type: MissionResultType.hintMode, message: guideMessage);
  }

  /// 성공 시 리셋
  void reset() {
    debugPrint("[MissionService] 발화 성공 - 카운트 초기화");
    _failureCount = 0;
  }

  /// 디버깅용
  int get currentFailureCount => _failureCount;
}