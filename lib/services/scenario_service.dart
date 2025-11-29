import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ScenarioService {
  final _db = FirebaseDatabase.instance.ref();

  // 현재 선택된 시나리오 저장 변수
  String? _currentContext;      // 예: "장난감 달라고 할 때"
  String? _currentTargetSpeech; // 예: "장난감 주세요"

  // 외부에서 읽기만 가능한 Getter
  String? get currentContext => _currentContext;
  String? get currentTargetSpeech => _currentTargetSpeech;

  /// 새로운 랜덤 시나리오 불러오기 (앱 시작 시 or 2단계 진입 시 호출)
  Future<void> loadNewScenario(String username) async {
    try {
      debugPrint("[Scenario] 시나리오 로딩 중...");
      final ref = _db.child('preference/$username/character_settings');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        debugPrint("[Scenario] 설정 데이터 없음");
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<dynamic> contextList = List.from(data['contextList'] ?? []);
      final List<dynamic> targetList = List.from(data['targetList'] ?? []);

      if (contextList.isEmpty || targetList.isEmpty) {
        debugPrint("[Scenario] 리스트가 비어있음");
        return;
      }

      // 두 리스트 길이 중 짧은 쪽에 맞춤 (인덱스 오류 방지)
      final length = min(contextList.length, targetList.length);
      debugPrint("[Scenario] 총 $length개의 시나리오 로드됨 (Context: ${contextList.length}개 / Target: ${targetList.length}개)");
      final randomIndex = Random().nextInt(length);

      // 변수에 확정 저장
      _currentContext = contextList[randomIndex].toString();
      _currentTargetSpeech = targetList[randomIndex].toString();

      debugPrint("[Scenario] 시나리오 확정 (Index: $randomIndex)");
      debugPrint("   - 상황: $_currentContext");
      debugPrint("   - 목표: $_currentTargetSpeech");

    } catch (e) {
      debugPrint("[Scenario] 로드 실패: $e");
    }
  }

  /// 시나리오 초기화 (필요시 사용)
  void clear() {
    _currentContext = null;
    _currentTargetSpeech = null;
  }
}