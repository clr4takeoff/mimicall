import 'package:flutter/material.dart';
import 'report_screen.dart';
import '../models/report_model.dart';
import '../services/stt_service.dart';

class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool isSpeaking = false;
  String dummySpeech = "메타몽 목이 너무 말라... 근데 뭐라고 말해야 할지 모르겠어 😥";
  String childSpeech = "";

  late STTService _sttService;

  @override
  void initState() {
    super.initState();
    _sttService = STTService(callId: "test_call_001");
    _sttService.onSpeechResult = (text) {
      setState(() {
        childSpeech = text;
        isSpeaking = text.isNotEmpty;
      });
    };
    _initializeSTT();
  }

  Future<void> _initializeSTT() async {
    await _sttService.initialize();
    await _sttService.startListening();
  }

  @override
  void dispose() {
    _sttService.stopListening();
    super.dispose();
  }

  void _onEndCall() async {
    await _sttService.stopListening();

    final report = ConversationReport(
      id: DateTime.now().toIso8601String(),
      summary: "오늘 하츄핑과 즐거운 대화를 나눴어요!",
      imageUrl: "https://placekitten.com/400/300",
      speechRatio: {"아이": 60, "AI": 40},
      createdAt: DateTime.now(),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(report: report)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✨ 밝은 하늘색~보라색 그라데이션 배경
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3E5FC), Color(0xFFD1C4E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 상단 통화 정보
            Positioned(
              top: 80,
              child: Column(
                children: const [
                  Text(
                    "하츄핑",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "통화 중...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 3),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // AI 말풍선
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
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

            // 캐릭터 (대화 중 애니메이션)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.30,
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

            // 아이 발화 표시 영역
            Positioned(
              bottom: 220,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Text(
                  childSpeech.isEmpty
                      ? "아이가 말하면 여기에 표시됩니다..."
                      : childSpeech,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
              ),
            ),

            // 하단 버튼들
            Positioned(
              bottom: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 마이크 버튼
                  FloatingActionButton(
                    heroTag: 'mute',
                    backgroundColor: const Color(0xFF91D8F7),
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
                  // 종료 버튼
                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: const Color(0xFFFF6B6B),
                    onPressed: _onEndCall,
                    child: const Icon(Icons.call_end, size: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
