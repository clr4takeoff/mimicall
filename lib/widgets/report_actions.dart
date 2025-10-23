import 'package:flutter/material.dart';
import '../screens/main_screen.dart';

class ReportActions extends StatelessWidget {
  const ReportActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
