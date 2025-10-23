import 'package:flutter/material.dart';

class FairyHelper extends StatelessWidget {
  final VoidCallback onHelp; // 요정 호출 시 실행할 콜백

  const FairyHelper({super.key, required this.onHelp});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'fairy',
      backgroundColor: const Color(0xFF91D8F7),
      onPressed: onHelp,
      child: const Icon(
        Icons.auto_awesome, // ✨ 요정 느낌나는 아이콘
        size: 32,
        color: Colors.white,
      ),
    );
  }
}
