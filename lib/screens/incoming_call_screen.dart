import 'package:flutter/material.dart';
import 'in_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 흐릿 캐릭터 (옵션)
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/characters/ditto.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 상단 정보
          Positioned(
            top: 140,
            child: Column(
              children: const [
                Text(
                  "메타몽",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "수신 중...",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          ),

          // 중앙 캐릭터
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            child: Image.asset(
              'assets/characters/ditto.png',
              height: 200,
            ),
          ),

          // 하단 버튼 (거절 / 수락)
          Positioned(
            bottom: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'decline',
                  backgroundColor: Colors.redAccent,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.call_end, size: 36),
                ),
                const SizedBox(width: 80),
                FloatingActionButton(
                  heroTag: 'accept',
                  backgroundColor: Colors.green,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InCallScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.call, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
