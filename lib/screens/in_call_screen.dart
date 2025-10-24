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
import '../services/fairy_service.dart';



class InCallScreen extends StatefulWidget {
  final String dbPath;

  const InCallScreen({super.key, required this.dbPath});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool isSpeaking = false;
  bool isFairyMode = false;
  bool _isEndingCall = false;
  bool _isFairyButtonEnabled = false;

  String dummySpeech = "메타몽 목이 너무 말라... 근데 뭐라고 말해야 할지 모르겠어.";
  String childSpeech = "";
  CharacterSettings? _characterSettings;
  DateTime? _lastAssistantEndTime;

  late STTService _sttService;
  late TTSService _ttsService;
  late FairyService _fairyService;
  final GPTResponse gpt = GPTResponse();

  late ConversationService _conversation;

  @override
  void initState() {
    super.initState();
    _sttService = STTService(callId: "test_call_001");
    _ttsService = TTSService();
    _conversation = ConversationService(stt: _sttService, tts: _ttsService);
    _fairyService = FairyService(tts: _ttsService, stt: _sttService);

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
    await Future.delayed(const Duration(seconds: 1));
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
      if (_isEndingCall || !mounted || text.isEmpty) return;

      // 1️⃣ 반응 시간 계산
      final now = DateTime.now();
      int? responseDelayMs;
      if (_lastAssistantEndTime != null) {
        responseDelayMs = now.difference(_lastAssistantEndTime!).inMilliseconds;
        debugPrint("[ResponseDelay] 아이 반응 시간: ${responseDelayMs}ms");
      }

      setState(() {
        childSpeech = text;
        final currentStage = _conversation.conversationStage;
        if (currentStage >= 2 && !_isFairyButtonEnabled) {
          setState(() {
            _isFairyButtonEnabled = true;
            debugPrint("[UI] 요정 버튼 활성화 (단계: $currentStage)");
          });
        }
        isSpeaking = true;
      });

      // 2️⃣ 발화 카운트 업데이트
      _conversation.registerUserSpeech(text);

      // 3️⃣ 현재 대화 단계 문장 가져오기
      final userName = UserInfo.name ?? "unknown";
      final stageInstruction =
      await _conversation.getStageInstruction(username: userName);

      // 4️⃣ GPT 호출 (단계 정보 포함)
      final reply = await gpt.sendMessageToLLM(
        text,
        stageInstruction: stageInstruction,
      );

      if (_isEndingCall || reply.isEmpty) return;

      setState(() => dummySpeech = reply);

      // 5️⃣ Firebase에 대화 저장 (responseDelay 포함)
      await _conversation.saveMessage(
        dbPath: widget.dbPath,
        role: "user",
        text: text,
        timestamp: now,
        extra: {
          if (responseDelayMs != null) "responseDelayMs": responseDelayMs,
        },
      );
      await Future.delayed(const Duration(milliseconds: 200));
      await _conversation.saveMessage(
        dbPath: widget.dbPath,
        role: "assistant",
        text: reply,
        timestamp: now.add(const Duration(milliseconds: 200)),
      );

      // 6️⃣ TTS 실행 전 STT 중지
      await _sttService.stopListening(tempStop: true);

      if (_isEndingCall) return;

      // 7️⃣ TTS 실행
      await _ttsService.speak(reply);

      // ✅ 8️⃣ TTS가 끝난 시점 기록 (다음 반응시간 계산용)
      _lastAssistantEndTime = DateTime.now();

      // 9️⃣ TTS 완료 후 STT 재개
      await _sttService.startListening();
    };
  }


  @override
  void dispose() {
    debugPrint("[InCallScreen] 세션 종료 중...");
    _sttService.onResult = null;
    _sttService.dispose();
    _ttsService.dispose();
    _fairyService.stopSession();
    super.dispose();
    debugPrint("[InCallScreen] 세션 종료 완료");
  }

  void _onEndCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    debugPrint("[InCallScreen] 통화 종료 시작 (모든 비동기 작업 즉시 중단)");

    try {
      // STT/TTS 즉시 중단
      await Future.wait([
        _sttService.stopListening().catchError((_) {}),
        _ttsService.stop().catchError((_) {}),
      ]);
      await Future.wait([
        _sttService.dispose().catchError((_) {}),
        _ttsService.dispose().catchError((_) {}),
      ]);

      if (!mounted) return;

      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );

      const bool useDalle = false;
      const imagePrompt = "밝은 하늘 아래에서 메타몽이 미소 짓는 장면을 그려줘";
      String imageBase64 = "";

      if (useDalle) {
        try {
          imageBase64 = await gpt.generateAndSaveImageBase64(
            prompt: imagePrompt,
            dbPath: widget.dbPath,
          );
          debugPrint("[InCallScreen] 이미지 생성 완료 (${imageBase64.length} bytes)");
        } catch (e) {
          debugPrint("[InCallScreen] 이미지 생성 실패: $e");
        }
      }

      // 리포트 생성
      final reportService = ReportService();
      final userName = UserInfo.name ?? "unknown";
      final reportId =
          DateTime.now().toIso8601String().replaceAll('T', '_').split('.').first;

      final report = await reportService.generateReport(userName, reportId, widget.dbPath);

      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReportScreen(report: report)),
      );
    } catch (e, st) {
      debugPrint("[InCallScreen] 통화 종료 중 예외: $e\n$st");
    } finally {
      debugPrint("[InCallScreen] 통화 종료 완료");
      _isEndingCall = false;
    }
  }

  void _toggleFairyMode() async {
    if (!_isFairyButtonEnabled) {
      debugPrint("[FairyMode] 아직 2단계 전이므로 요정 모드 진입 불가");
      return;
    }

    setState(() {
      isFairyMode = !isFairyMode;
    });

    if (isFairyMode) {
      setState(() => dummySpeech = "걱정 마! 요정이 도와줄게~ 같이 말해보자! 🌟");
      await _ttsService.speak(dummySpeech);
      final ctx = _conversation.contextText ?? "캐릭터가 도움이 필요해요.";
      final target = _characterSettings?.targetSpeech ?? "도와줘";
      await _fairyService.startGuidedSession(
        context: ctx,
        targets: [target],
      );

    } else {
      setState(() => dummySpeech = "메타몽 모드로 돌아왔어~ 😌");
      await _fairyService.stopSession();
      await _sttService.startListening();
    }
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
                    backgroundColor: !_isFairyButtonEnabled
                        ? Colors.grey
                        : (isFairyMode
                        ? const Color(0xFFB39DDB)
                        : const Color(0xFF91D8F7)),
                    onPressed: _isFairyButtonEnabled ? _toggleFairyMode : null,
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
