import 'package:flutter/foundation.dart';

class TrafficControlService {
  String getTrafficLightAsset({
    required int conversationStage,
    required bool isListening,
    required bool isThinking,
    required bool isTtsPlaying,
    required bool isMissionFailed,
    required bool isGreeting,
  }) {

    final isCharacterActive = isThinking || isTtsPlaying || isGreeting;

    // 1. 미션 실패 상태 (Left Hidden Button 클릭 후 재질문 대기): Red
    if (isMissionFailed) {
      return 'assets/temp/traffic_light_red.png';
    }

    // 2. 칭찬 완료 상태 (Stage 3): Green
    if (conversationStage == 3) {
      return 'assets/temp/traffic_light_green.png';
    }

    // 3. Stage 2에서 캐릭터 발화가 끝났고, 아이의 발화만 기다리는 상태: Yellow
    // Stage 2 이면서, 캐릭터가 발화 중/생각 중/인사 중이 아니고, 아이가 말하고 있지 않을 때
    if (conversationStage == 2 && isCharacterActive == false && isListening == false) {
      return 'assets/temp/traffic_light_yellow.png';
    }

    // 4. 캐릭터가 말하는 중/생각 중이거나, Stage 1 상태: 기본 신호등
    return 'assets/temp/traffic_light.png'; // 기본 회색 신호등
  }
}