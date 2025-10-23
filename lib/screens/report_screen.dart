import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../screens/main_screen.dart';
import '../widgets/report_summary_box.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_image.dart';

class ReportScreen extends StatelessWidget {
  final ConversationReport report;

  const ReportScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        title: const Text('통화 리포트'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '홈으로 이동',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              const Text(
                "축하해요 임무 완료!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Base64 or URL 이미지 표시
              ReportImage(
                imageUrl: report.imageUrl,
                imageBase64: report.imageBase64,
              ),

              const SizedBox(height: 24),
              ReportSummaryBox(report: report),
              const SizedBox(height: 24),
              const ReportActions(),
              const SizedBox(height: 12),
              Text(
                "생성일: ${_formatDate(report.createdAt)}",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
