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
  String? _goalContext;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    try {
      final userName = UserInfo.name ?? "unknown";

      // 1️⃣ 목표 데이터 불러오기
      final settingsRef = FirebaseDatabase.instance
          .ref("preference/$userName/character_settings");
      final settingsSnap = await settingsRef.get();

      if (settingsSnap.exists) {
        final data = Map<String, dynamic>.from(settingsSnap.value as Map);
        _targetSpeechCount = data["targetSpeechCount"] ?? 0;
        _targetFocusTime = data["focusTime"] ?? 0;
        _goalContext = data["contextText"];
      }

      // 2️⃣ 실제 대화 데이터 불러오기
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

        setState(() {
          _actualSpeechCount = speechCount;
          if (first != null && last != null) {
            _actualFocusTime =
                last!.difference(first!).inMinutes.clamp(0, 9999);
          }
        });
      }
    } catch (e) {
      debugPrint("[ReportProgressBox] 데이터 불러오기 실패: $e");
    } finally {
      setState(() => _isLoading = false);
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
          if (_goalContext != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3DC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "상황: $_goalContext",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),

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
