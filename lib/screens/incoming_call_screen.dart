import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'in_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String? userName;

  const IncomingCallScreen({super.key, this.userName});

  Future<void> _createReportRecord(String userName) async {
    final db = FirebaseDatabase.instance.ref();

    final now = DateTime.now();
    // Firebase 경로에 안전한 형식으로 변경
    final safeKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final reportRef = db.child('reports/$userName/$safeKey');

    await reportRef.set({
      'id': safeKey,
      'summary': '',
      'imageUrl': '',
      'speechRatio': {},
      'createdAt': now.toIso8601String(),
      'conversation': ['_init'],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 흐릿 캐릭터
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
                  onPressed: () async {
                    // DB에 새 리포트 기록 생성
                    final name = userName ?? "unknown";
                    await _createReportRecord(name);

                    // 통화 화면으로 이동
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
