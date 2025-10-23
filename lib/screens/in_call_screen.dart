import 'package:flutter/material.dart';
import 'report_screen.dart';
import '../models/report_model.dart';
import '../services/stt_service.dart';
import '../services/llm_service.dart';

class InCallScreen extends StatefulWidget {
  final String dbPath;
  const InCallScreen({super.key, required this.dbPath});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool isSpeaking = false;
  bool isFairyMode = false; // 요정 모드 상태
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

  /// 통화 종료 시 리포트 화면으로 이동
  void _onEndCall() async {
    await _sttService.stopListening();

    final gpt = GPTResponse();
    const imagePrompt = "밝은 하늘 아래에서 메타몽이 미소 짓는 장면을 그려줘";

    String imageBase64 = "";
    String reportKey =
        "reports/est/${DateTime.now().toIso8601String().replaceAll(':', '-')}";

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/characters/ditto.png',
                height: 80,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                strokeWidth: 5,
                color: Colors.purpleAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                "(dummy)메타몽이 그림을 그리고 있어요...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );


    try {
      imageBase64 = await gpt.generateAndSaveImageBase64(
        prompt: imagePrompt,
        dbPath: widget.dbPath,
      );
      debugPrint("이미지 생성 및 저장 완료 (${imageBase64.length} bytes)");
    } catch (e) {
      debugPrint("이미지 생성 실패: $e");
    } finally {
      if (context.mounted) Navigator.pop(context);
    }

    // 로딩 닫기 → 이동
    if (!mounted) return;
    Navigator.pop(context); // 로딩 다이얼로그 닫기

    // Report 객체 생성
    final report = ConversationReport(
      id: reportKey,
      summary: "오늘 메타몽과 즐거운 대화를 나눴어요!",
      imageUrl: "",
      imageBase64: imageBase64,
      speechRatio: {"아이": 60, "AI": 40},
      createdAt: DateTime.now(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(report: report)),
    );
  }

  /// 요정 모드 토글
  void _toggleFairyMode() {
    setState(() {
      isFairyMode = !isFairyMode;

      if (isFairyMode) {
        dummySpeech = "걱정 마! 병아리 요정이 왔어! 🌟 자, 같이 천천히 말해볼까?";
      } else {
        dummySpeech = "메타몽 목이 너무 말라... 근데 뭐라고 말해야 할지 모르겠어 😥";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  /// 도우미 요정 버튼 (토글 가능)
                  FloatingActionButton(
                    heroTag: 'fairy',
                    backgroundColor: isFairyMode
                        ? const Color(0xFFB39DDB) // 요정 모드 중
                        : const Color(0xFF91D8F7), // 기본 모드
                    onPressed: _toggleFairyMode,
                    child: Icon(
                      isFairyMode
                          ? Icons.undo // 돌아가기
                          : Icons.auto_awesome, // ✨ 요정 소환
                      size: 32,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 70),

                  /// 통화 종료 버튼
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
