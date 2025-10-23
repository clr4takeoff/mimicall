import 'package:flutter/material.dart';
import '../screens/main_screen.dart';
import '../screens/report_list_screen.dart';

class ReportActions extends StatelessWidget {
  const ReportActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 확인 버튼
        ElevatedButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainScreen()),
                  (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB74D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            minimumSize: const Size(120, 48), // 버튼 크기
          ),
          child: const Text(
            "확인",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(width: 16),

        // 이전 리포트 보기 버튼
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportListScreen()), // ✅ 수정됨
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF5D4037),
            side: const BorderSide(color: Color(0xFFFFB74D), width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: const Size(150, 48),
          ),
          child: const Text(
            "이전 리포트 보기",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
