import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../screens/main_screen.dart';
import '../widgets/report_summary_box.dart';
import '../widgets/report_actions.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              "축하해요 임무 완료!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (report.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(report.imageUrl, height: 180),
              ),
            const SizedBox(height: 20),
            ReportSummaryBox(report: report),
            const SizedBox(height: 24),
            const ReportActions(),
          ],
        ),
      ),
    );
  }
}
