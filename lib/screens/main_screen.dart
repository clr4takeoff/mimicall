import 'package:flutter/material.dart';
import 'incoming_call_screen.dart';
import 'report_screen.dart';

class MainScreen extends StatelessWidget {
  final String? userName;

  const MainScreen({Key? key, this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('안녕, ${userName ?? "친구"}!')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('영상 통화 시작'),
              onPressed: () {
                // 통화 버튼 클릭 시: 수신 화면으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IncomingCallScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text('지난 통화 리포트 보기'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
