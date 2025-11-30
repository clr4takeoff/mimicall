import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ScenarioService {
  final _db = FirebaseDatabase.instance.ref();
  static const _usedIndicesKey = 'usedScenarioIndices';

  // 현재 선택된 시나리오 저장 변수
  String? _currentContext;      // 예: "장난감 달라고 할 때"
  String? _currentTargetSpeech; // 예: "장난감 주세요"
  int? _contextIndex;
  List<int> _usedIndices = [];

  // 외부에서 읽기만 가능한 Getter
  String? get currentContext => _currentContext;
  String? get currentTargetSpeech => _currentTargetSpeech;
  int? get contextIndex => _contextIndex;

  // 한 바퀴 돌고 리셋
  void resetUsedIndices() {
    _usedIndices.clear();
    debugPrint("[Scenario] 사용된 인덱스 리셋됨.");
  }

  // 새로운 랜덤 시나리오 불러오기 (앱 시작 시 or 2단계 진입 시 호출)
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

      final length = min(contextList.length, targetList.length);
      debugPrint("[Scenario] 총 $length개의 시나리오 로드됨 (Context: ${contextList.length}개 / Target: ${targetList.length}개)");

      // 1. ㄴ이전에 사용된 인덱스 로드 및 리셋 로직
      final usedRef = _db.child('preference/$username/$_usedIndicesKey');
      final usedSnapshot = await usedRef.get();
      if (usedSnapshot.exists && usedSnapshot.value is List) {
        _usedIndices = List<int>.from(usedSnapshot.value as List);
      } else {
        _usedIndices = [];
      }
      debugPrint("[Scenario] 현재까지 사용된 인덱스: $_usedIndices");

      // 모든 시나리오를 다 사용했으면 리셋
      if (_usedIndices.length >= length) {
        debugPrint("[Scenario] 모든 시나리오 순회 완료. 리스트를 초기화합니다.");
        _usedIndices.clear();
      }

      // 2. 사용되지 않은 인덱스 중에서 랜덤 선택
      final availableIndices = List.generate(length, (index) => index)
          .where((index) => !_usedIndices.contains(index))
          .toList();

      if (availableIndices.isEmpty) {
        // 혹시 몰라서
        debugPrint("[Scenario] 사용 가능한 새 시나리오가 없음. 첫 시나리오로 강제 리셋.");
        final randomIndex = Random().nextInt(length);
        _contextIndex = randomIndex;

      } else {
        // 사용 가능한 인덱스 중에서 랜덤 선택
        final randomIndex = availableIndices[Random().nextInt(availableIndices.length)];
        _contextIndex = randomIndex;

        // 3.선택된 인덱스를 사용된 리스트에 추가 및 DB 저장
        _usedIndices.add(_contextIndex!);
        await usedRef.set(_usedIndices);
      }

      // 4. 변수에 저장
      final randomIndex = _contextIndex!;
      _currentContext = contextList[randomIndex].toString();
      _currentTargetSpeech = targetList[randomIndex].toString();

      debugPrint("[Scenario] 시나리오 확정 (Index: $randomIndex)");
      debugPrint("   - 상황: $_currentContext");
      debugPrint("   - 목표: $_currentTargetSpeech");

    } catch (e) {
      debugPrint("[Scenario] 로드 실패: $e");
      // 예외 발생 시 인덱스를 null로 설정
      _contextIndex = null;
    }
  }

  /// 시나리오 초기화 (필요시 사용)
  void clear() {
    _currentContext = null;
    _currentTargetSpeech = null;
    _contextIndex = null;
  }
}