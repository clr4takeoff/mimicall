import 'package:flutter/material.dart';
import '../models/report_model.dart';

class ReportSummaryBox extends StatelessWidget {
  final ConversationReport report;

  const ReportSummaryBox({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "오늘의 대화 요약",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(report.summary, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
