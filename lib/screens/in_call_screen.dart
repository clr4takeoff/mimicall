import 'package:flutter/material.dart';
import 'report_screen.dart';
import '../models/report_model.dart';

class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool isSpeaking = false;
  String dummySpeech = "메타몽 목이 너무 말라... 근데 뭐라고 말해야 할지 모르겠어 😥";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 상단 통화 정보
          Positioned(
            top: 100,
            child: Column(
              children: const [
                Text(
                  "하츄핑",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "통화 중...",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          ),

          // 캐릭터
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 240,
              child: Image.asset(
                isSpeaking
                    ? 'assets/character_talking.gif'
                    : 'assets/characters/ditto.png',
              ),
            ),
          ),

          // 말풍선
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                dummySpeech,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),

          // 하단 통화 버튼
          Positioned(
            bottom: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'mute',
                  backgroundColor: Colors.grey[800],
                  onPressed: () {
                    setState(() {
                      isSpeaking = !isSpeaking;
                    });
                  },
                  child: Icon(
                    isSpeaking ? Icons.mic : Icons.mic_off,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 70),
                FloatingActionButton(
                  heroTag: 'end',
                  backgroundColor: Colors.redAccent,
                  onPressed: () {
                    // 통화 종료 시 리포트 화면으로 이동
                    final report = ConversationReport(
                      id: DateTime.now().toIso8601String(),
                      summary: "오늘 하츄핑과 즐거운 대화를 나눴어요!",
                      imageUrl: "https://placekitten.com/400/300", // 임시 이미지
                      speechRatio: {"아이": 60, "AI": 40},
                      createdAt: DateTime.now(),
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportScreen(report: report),
                      ),
                    );
                  },
                  child: const Icon(Icons.call_end, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
