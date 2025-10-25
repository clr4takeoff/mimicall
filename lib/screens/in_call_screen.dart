import 'package:flutter/material.dart';
import 'report_screen.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/llm_service.dart';
import '../services/report_service.dart';
import '../services/conversation_service.dart';
import '../utils/user_info.dart';
import '../models/character_settings_model.dart';
import '../services/fairy_service.dart';
import 'package:firebase_database/firebase_database.dart';


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

  String dummySpeech = "";
  String childSpeech = "";
  CharacterSettings? _characterSettings;
  DateTime? _lastAssistantEndTime;
  DateTime? _speechStartTime;
  String _characterName = "캐릭터";

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
    final greeting = "안녕! 나는 $_characterName 이야. 오늘 뭐하고 있었어?";

    setState(() => dummySpeech = greeting);

    final conv = ConversationService(stt: _sttService, tts: _ttsService);
    await conv.saveMessage(
      dbPath: widget.dbPath,
      role: "z_assistant",
      text: greeting,
    );

    await _ttsService.speak(greeting, UserInfo.name ?? "unknown");


    await Future.delayed(const Duration(seconds: 1));
    _speechStartTime = DateTime.now();
    await _sttService.startListening();
  }

  Future<void> _loadCharacterSettings() async {
    try {
      final childName = UserInfo.name;
      if (childName == null) return;

      final ref =
      FirebaseDatabase.instance.ref('preference/$childName/character_settings');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final settings = CharacterSettings.fromJson(data);

        setState(() {
          _characterSettings = settings;
          _characterName = settings.characterName.isNotEmpty
              ? settings.characterName
              : "캐릭터";
        });

        gpt.initializeCharacterContext(
          context: settings.contextText,
          style: settings.speakingStyle,
          targetSpeechCount: settings.targetSpeechCount,
        );
      }
    } catch (e) {
      debugPrint("캐릭터 설정 불러오기 실패: $e");
    }
  }

Future<void> _initializeSTT() async {
  await _sttService.initialize();

  // 아이 발화 시작 시점 감지
  _sttService.onSpeechDetected = () {
    _speechStartTime = DateTime.now();
    debugPrint("[InCallScreen] 아이 발화 시작 시점 기록됨");
  };

  // Whisper 결과 수신 시 처리
  _sttService.onResult = (text) async {
    if (_isEndingCall || !mounted || text.isEmpty) return;

    final now = DateTime.now();

    int? speechDurationMs;
    if (_speechStartTime != null) {
      speechDurationMs = now.difference(_speechStartTime!).inMilliseconds;
      debugPrint("[SpeechDuration] 아이 발화 길이: ${speechDurationMs}ms");
    }

    int? responseDelayMs;
    if (_lastAssistantEndTime != null && _speechStartTime != null) {
      responseDelayMs =
          _speechStartTime!.difference(_lastAssistantEndTime!).inMilliseconds;
      debugPrint("[ResponseDelay] 아이 반응 시간: ${responseDelayMs}ms");
    }

    setState(() {
      childSpeech = text;
      final currentStage = _conversation.conversationStage;
      if (currentStage >= 2 && !_isFairyButtonEnabled) {
        _isFairyButtonEnabled = true;
      }
      isSpeaking = true;
    });

    _conversation.registerUserSpeech(text);

    final userName = UserInfo.name ?? "unknown";
    final stageInstruction =
    await _conversation.getStageInstruction(username: userName);

    final reply = await gpt.sendMessageToLLM(
      text,
      stageInstruction: stageInstruction,
    );

    if (_isEndingCall || reply.isEmpty) return;

    setState(() => dummySpeech = reply);

    await _conversation.saveMessage(
      dbPath: widget.dbPath,
      role: "user",
      text: text,
      timestamp: now,
      extra: {
        if (responseDelayMs != null) "responseDelayMs": responseDelayMs,
        if (speechDurationMs != null) "speechDurationMs": speechDurationMs,
      },
    );

    await Future.delayed(const Duration(milliseconds: 200));
    await _conversation.saveMessage(
      dbPath: widget.dbPath,
      role: "z_assistant",
      text: reply,
      timestamp: now.add(const Duration(milliseconds: 200)),
    );

    await _sttService.stopListening(tempStop: true);

    if (_isEndingCall) return;
    await _ttsService.speak(reply, UserInfo.name ?? "unknown");
    await Future.delayed(const Duration(milliseconds: 800));
    _lastAssistantEndTime = DateTime.now();
    _speechStartTime = null;
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
      // STT, TTS 중단
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

      // 이미지 생성 (옵션)
      const bool useDalle = false;
      final imagePrompt = "밝은 하늘 아래에서 $_characterName 이 미소 짓는 장면을 그려줘";
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

      final reportService = ReportService();
      final userName = UserInfo.name ?? "unknown";
      final reportId =
          DateTime.now().toIso8601String().replaceAll('T', '_').split('.').first;

      // 1️⃣ 리포트 생성 및 DB 저장
      await reportService.generateReport(userName, reportId, widget.dbPath,_characterSettings?.characterName ?? '캐릭터');

      // 2️⃣ DB 업데이트 완료 후 최신 리포트 다시 가져오기
      final updatedReport = await reportService.getLatestReport(userName);

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      // 3️⃣ 최신 리포트 데이터로 이동
      if (updatedReport != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReportScreen(report: updatedReport),
          ),
        );
      } else {
        debugPrint("[InCallScreen] 최신 리포트 불러오기 실패 — generateReport는 성공했지만 getLatestReport 결과 없음");
      }
    } catch (e, st) {
      debugPrint("[InCallScreen] 통화 종료 중 예외 발생: $e\n$st");
      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("리포트 생성 중 오류가 발생했습니다: $e")),
        );
      }
    } finally {
      debugPrint("[InCallScreen] 통화 종료 완료");
      _isEndingCall = false;
    }
  }

  void _toggleFairyMode() async {
    if (!isFairyMode) {
      await _sttService.stopListening(tempStop: true);
      await _ttsService.stop();

      _conversation.enableFairyMode();

      setState(() {
        isFairyMode = true;
        dummySpeech = "요정이 나타났어! 같이 말해보자.";
      });

      final context = _characterSettings?.contextText ?? "무슨 일이 생겼대.";
      final targetList = (_characterSettings?.targetSpeech ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await _fairyService.startGuidedSession(
        context: context,
        targets: targetList,
      );
    } else {
      await _fairyService.stopSession();
      _conversation.disableFairyMode();

      setState(() {
        isFairyMode = false;
        dummySpeech = "잠깐 다른 친구랑 이야기하고 왔구나. 나는 여전히 이런 상황을 겪고있어.";
      });

      _speechStartTime = DateTime.now();
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
                children: [
                  Text(
                    _characterName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
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
            Positioned(
              top: MediaQuery.of(context).size.height * 0.30,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 240,
                child: Image.asset(
                  isSpeaking
                      ? 'assets/characters/character_talking.gif'
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
