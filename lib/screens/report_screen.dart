import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/report_model.dart';
import 'main_screen.dart';

class ReportScreen extends StatelessWidget {
  final ConversationReport report; // 상황에 따라 전달되는 리포트 데이터

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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("오늘의 대화 요약",
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(report.summary, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text("오늘의 발화 그래프",
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sections: report.speechRatio.entries
                            .map(
                              (e) => PieChartSectionData(
                            value: e.value,
                            title: e.key,
                          ),
                        )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                          (route) => false,
                    );
                  },
                  child: const Text("확인"),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text("이전 리포트 보기"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
