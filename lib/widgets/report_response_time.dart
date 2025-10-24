import 'package:flutter/material.dart';
import '../models/report_model.dart';

class ReportResponseTime extends StatelessWidget {
  final ConversationReport report;

  const ReportResponseTime({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final avgDelay = report.averageResponseDelayMs;

    if (avgDelay == null || avgDelay <= 0) {
      return const SizedBox.shrink(); // 값 없으면 아무것도 안 그림
    }

    final seconds = (avgDelay / 1000).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFF5D4037)),
          const SizedBox(width: 8),
          Text(
            "아이의 평균 반응 시간: $seconds초",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }
}
