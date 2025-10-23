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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF7E9),
              Color(0xFFFFF3DC),
              Color(0xFFF7D59C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 상단 헤더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF5D4037),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            '통화 리포트',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFFFFB74D),
                            ),
                            tooltip: '홈으로 이동',
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MainScreen()),
                                    (route) => false,
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "🎉 축하해요! 임무 완료!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D4037),
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            )
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // 이미지
                      ReportImage(
                        imageUrl: report.imageUrl,
                        imageBase64: report.imageBase64,
                      ),
                      const SizedBox(height: 28),

                      // 요약 박스
                      ReportSummaryBox(report: report),
                      const SizedBox(height: 28),

                      // 버튼들
                      const ReportActions(),
                      const SizedBox(height: 16),

                      Text(
                        "생성일: ${_formatDate(report.createdAt)}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),

                      const Spacer(), // 남는 공간이 있어도 하단까지 밀림
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
