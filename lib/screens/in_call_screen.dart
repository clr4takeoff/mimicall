import 'package:flutter/material.dart';
import 'report_screen.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/llm_service.dart';
import '../services/report_service.dart';
import '../services/conversation_service.dart';
import '../utils/user_info.dart';
import '../services/character_settings_service.dart';
import '../models/character_settings_model.dart';


class InCallScreen extends StatefulWidget {
  final String dbPath;

  const InCallScreen({super.key, required this.dbPath});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool isSpeaking = false;
  bool isFairyMode = false;
  String dummySpeech = "메타몽 목이 너무 말라... 근데 뭐라고 말해야 할지 모르겠어.";
  String childSpeech = "";
  CharacterSettings? _characterSettings;

  late STTService _sttService;
  late TTSService _ttsService;
  final GPTResponse gpt = GPTResponse();

  late ConversationService _conversation;

  @override
  void initState() {
    super.initState();
    _sttService = STTService(callId: "test_call_001");
    _ttsService = TTSService();
    _conversation = ConversationService(stt: _sttService, tts: _ttsService);

    _loadCharacterSettings().then((_) async {
      await _initializeSTT();
      Future.delayed(const Duration(seconds: 1), _speakInitialGreeting);
    });
  }



  Future<void> _speakInitialGreeting() async {
    final greeting = "안녕! 나는 메타몽이야. 오늘 뭐하고 있었어?";

    setState(() => dummySpeech = greeting);

    // 대화 저장
    final conv = ConversationService(stt: _sttService, tts: _ttsService);
    await conv.saveMessage(
      dbPath: widget.dbPath,
      role: "assistant",
      text: greeting,
    );

    // 음성 생성 + 재생
    await _ttsService.speak(greeting);

    // 발화 끝나면 STT 시작
    await _sttService.startListening();
  }


  Future<void> _loadCharacterSettings() async {
    try {
      final childName = UserInfo.name;
      if (childName == null) return;

      final service = CharacterSettingsService();
      final settings = await service.loadCharacterSettings(childName);

      if (settings != null) {
        setState(() => _characterSettings = settings);

        gpt.initializeCharacterContext(
          context: settings.contextText,
          style: settings.speakingStyle,
          targetSpeechCount: settings.targetSpeechCount,
        );

        debugPrint("캐릭터 설정 불러옴: ${settings.toJson()}");
      } else {
        debugPrint("캐릭터 설정이 존재하지 않습니다.");
      }
    } catch (e) {
      debugPrint("캐릭터 설정 불러오기 실패: $e");
    }
  }

  Future<void> _initializeSTT() async {
    await _sttService.initialize();

    _sttService.onResult = (text) async {
      if (!mounted || text.isEmpty) return;

      setState(() {
        childSpeech = text;
        isSpeaking = true;
      });

      final reply = await gpt.sendMessageToLLM(text);
      if (reply.isEmpty) return;

      setState(() => dummySpeech = reply);

      final now = DateTime.now();
      await _conversation.saveMessage(
        dbPath: widget.dbPath,
        role: "user",
        text: text,
        timestamp: now,
      );
      await Future.delayed(const Duration(milliseconds: 200)); // 순서 보정
      await _conversation.saveMessage(
        dbPath: widget.dbPath,
        role: "assistant",
        text: reply,
        timestamp: now.add(const Duration(milliseconds: 200)),
      );

      // TTS 실행 전 STT 명시적 중지
      await _sttService.stopListening(tempStop: true);

      // TTS 실행
      await _ttsService.speak(reply);

      // TTS 완료 후 STT 다시 시작
      await _sttService.startListening();
    };

  }


  @override
  void dispose() {
    debugPrint("[InCallScreen] 세션 종료 중...");
    _sttService.onResult = null;
    _sttService.dispose();
    _ttsService.dispose();
    super.dispose();
    debugPrint("[InCallScreen] 세션 종료 완료");
  }

  void _onEndCall() async {
    await _sttService.stopListening();
    await _sttService.dispose();
    await _ttsService.dispose(); // 확실히 종료해주겠지?

    const bool useDalle = false;
    const imagePrompt = "밝은 하늘 아래에서 메타몽이 미소 짓는 장면을 그려줘";
    String imageBase64 = "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.purpleAccent),
              SizedBox(height: 20),
              Text(
                "메타몽이 그림을 그리고 있어요...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      if (useDalle) {
        imageBase64 = await gpt.generateAndSaveImageBase64(
          prompt: imagePrompt,
          dbPath: widget.dbPath,
        );
        debugPrint("이미지 생성 완료 (${imageBase64.length} bytes)");
      } else {
        imageBase64 = "";
        debugPrint("테스트 모드: DALL·E 호출 생략");
      }
    } catch (e) {
      debugPrint("이미지 생성 실패: $e");
    } finally {
      if (context.mounted) Navigator.pop(context);
    }

    if (!mounted) return;

    final reportService = ReportService();
    final userName = UserInfo.name ?? "unknown";
    final reportId = DateTime.now().toIso8601String().replaceAll('T', '_').split('.').first;

    await reportService.generateReport(userName, reportId);

    // ReportService가 ConversationReport 반환
    final report = await reportService.generateReport(userName, reportId);

    if (context.mounted) Navigator.pop(context);

    // ReportScreen으로 전달
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(report: report)),
    );
  }

  void _toggleFairyMode() {
    setState(() {
      isFairyMode = !isFairyMode;

      if (isFairyMode) {
        dummySpeech = "걱정 마. 병아리 요정이 왔어. 자, 같이 천천히 말해볼까?";
      } else {
        dummySpeech = "메타몽 목이 너무 말라... 근데 뭐라고 말해야 할지 모르겠어.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFEFD5),
              Color(0xFFFFDAB9),
              Color(0xFFFAD0C4),
              Color(0xFFD1C4E9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
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
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      ? "아이가 말하면 여기에 표시됩니다."
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
            Positioned(
              bottom: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'fairy',
                    backgroundColor: isFairyMode
                        ? const Color(0xFFB39DDB)
                        : const Color(0xFF91D8F7),
                    onPressed: _toggleFairyMode,
                    child: Icon(
                      isFairyMode ? Icons.undo : Icons.auto_awesome,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 70),
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
