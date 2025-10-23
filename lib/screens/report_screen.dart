import 'package:flutter/material.dart';
import 'main_screen.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('통화 리포트')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('통화 요약', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('통화 시간: 3분 42초'),
            const Text('친구: 디토'),
            const Text('감정 상태: 😊 행복했어요!'),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                        (route) => false,
                  );
                },
                child: const Text('홈으로 돌아가기'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
