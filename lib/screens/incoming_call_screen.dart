import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'in_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String? userName;

  const IncomingCallScreen({super.key, this.userName});

  Future<String> _createReportRecord(String userName) async {
    final db = FirebaseDatabase.instance.ref();

    final now = DateTime.now();
    final safeKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final dbPath = 'reports/$userName/$safeKey';
    final reportRef = db.child(dbPath);

    await reportRef.set({
      'id': safeKey,
      'summary': '',
      'imageUrl': '',
      'imageBase64': '',
      'speechRatio': {},
      'createdAt': now.toIso8601String(),
      'conversation': ['_init'],
    });

    return dbPath;
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
                    final name = userName ?? "unknown";
                    final dbPath = await _createReportRecord(name);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InCallScreen(dbPath: dbPath),
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
