import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';
import '../utils/user_info.dart';

class ReportProgressBox extends StatefulWidget {
  final ConversationReport report;
  const ReportProgressBox({super.key, required this.report});

  @override
  State<ReportProgressBox> createState() => _ReportProgressBoxState();
}

class _ReportProgressBoxState extends State<ReportProgressBox> {
  int? _targetSpeechCount;
  int? _targetFocusTime;
  int _actualSpeechCount = 0;
  int _actualFocusTime = 0; // 분 단위
  List<String> _goalContexts = []; // 모든 미션 상황을 저장할 리스트

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    try {
      final userName = UserInfo.name ?? "unknown";

      // 1-1 리포트 메타데이터에서 contextId 리스트 불러오기
      final reportMetadataRef = FirebaseDatabase.instance.ref(
          "reports/$userName/${widget.report.id}");
      final reportMetadataSnap = await reportMetadataRef.get();

      List<int> contextIdIndices = []; // 리포트에 저장된 모든 상황 ID

      if (reportMetadataSnap.exists) {
        final rData = Map<String, dynamic>.from(reportMetadataSnap.value as Map);
        final rawContextIds = rData["contextId"];

        // contextId가 List 형태인 경우 모든 인덱스 저장
        if (rawContextIds is List) {
          contextIdIndices = List<int>.from(rawContextIds.whereType<int>());
        } else if (rawContextIds is int) {
          // 과거 데이터 호환성을 위해 단일 int도 List로 변환
          contextIdIndices = [rawContextIds];
        }
      }

      // 1-2 환경 설정 및 목표치 불러오기
      final settingsRef = FirebaseDatabase.instance
          .ref("preference/$userName/character_settings");
      final settingsSnap = await settingsRef.get();

      if (settingsSnap.exists) {
        final data = Map<String, dynamic>.from(settingsSnap.value as Map);
        _targetSpeechCount = data["targetSpeechCount"] ?? 0;
        _targetFocusTime = data["focusTime"] ?? 0;

        // contextList에서 모든 contextId에 해당하는 텍스트 찾기
        final rawContextList = data["contextList"];
        List<String> foundContexts = [];

        if (rawContextList != null) {
          for (int index in contextIdIndices) {
            String? contextText;

            if (rawContextList is List && index >= 0 && index < rawContextList.length) {
              contextText = rawContextList[index];
            } else if (rawContextList is Map) {
              contextText = rawContextList[index.toString()] ?? rawContextList[index];
            }

            // 텍스트를 찾았으면 리스트에 추가
            if (contextText != null) {
              foundContexts.add(contextText);
            } else {
              foundContexts.add("상황 정보 없음 (Index: $index)");
            }
          }
        }

        _goalContexts = foundContexts;
      }

      // 2. 실제 대화 데이터 불러오기
      final convRef = FirebaseDatabase.instance.ref(
        "reports/$userName/${widget.report.id}/conversation/messages",
      );
      final convSnap = await convRef.get();

      if (convSnap.exists) {
        int speechCount = 0;
        DateTime? first;
        DateTime? last;

        for (final msg in convSnap.children) {
          final val = Map<String, dynamic>.from(msg.value as Map);
          if (val["role"] == "user") speechCount++;
          if (val["timestamp"] != null) {
            final time = DateTime.tryParse(val["timestamp"]);
            if (time != null) {
              first ??= time;
              last = time;
            }
          }
        }

        // setState는 finally에서 한 번만 호출하도록 로직 변경
        _actualSpeechCount = speechCount;
        if (first != null && last != null) {
          _actualFocusTime =
              last!.difference(first!).inMinutes.clamp(0, 9999);
        }
      }
    } catch (e) {
      debugPrint("[ReportProgressBox] 데이터 불러오기 실패: $e");
    } finally {
      // 모든 데이터 로드가 완료된 후 UI 업데이트
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    double speechProgress = 0;
    double focusProgress = 0;

    if (_targetSpeechCount != null && _targetSpeechCount! > 0) {
      speechProgress =
          (_actualSpeechCount / _targetSpeechCount!).clamp(0, 1).toDouble();
    }

    if (_targetFocusTime != null && _targetFocusTime! > 0) {
      focusProgress =
          (_actualFocusTime / _targetFocusTime!).clamp(0, 1).toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFfff),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "목표 달성률",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 16),

          // 모든 미션 상황 텍스트 출력
          ..._goalContexts.asMap().entries.map((entry) {
            final index = entry.key;
            final contextText = entry.value;
            final missionNumber = index + 1;

            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3DC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD180),
                  width: 1,
                ),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.0,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: "목표 상황 $missionNumber",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, // 미션 번호 굵게
                        color: Color(0xFF5D4037), // 짙은 갈색 등 포인트 색상
                      ),
                    ),
                    const TextSpan(
                      text: " | ", // 구분자
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Colors.black54,
                      ),
                    ),
                    TextSpan(
                      text: contextText, // 상황 텍스트
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          if (_goalContexts.isNotEmpty) const SizedBox(height: 8),

          _buildProgressRow(
            label: "발화 횟수",
            value:
            "$_actualSpeechCount / ${_targetSpeechCount ?? '-'} (${(speechProgress * 100).toStringAsFixed(0)}%)",
            progress: speechProgress,
          ),
          const SizedBox(height: 10),
          _buildProgressRow(
            label: "집중 시간",
            value:
            "$_actualFocusTime / ${_targetFocusTime ?? '-'}분 (${(focusProgress * 100).toStringAsFixed(0)}%)",
            progress: focusProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required String value,
    required double progress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.black87)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black54, height: 1.2)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.black12,
            color: const Color(0xFFFFB74D),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}