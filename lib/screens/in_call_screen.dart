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
import '../widgets/chat_bubble.dart';


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
  bool _isGreeting = false;
  bool _isListening = false; // 사용자가 현재 말하고 있는지 여부. 버튼 조작
  bool _isThinking = false; // GPT 처리중


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
    _fairyService = FairyService(tts: _ttsService, stt: _sttService, gpt: gpt);

    _ttsService.playerStateStream.listen((state) {
      if (mounted) setState(() {});
    });


    _ttsService.onStart = () {
      if (mounted) {
        setState(() {
          _isListening = false; // 마이크 비활성화
        });
      }
      debugPrint("[InCallScreen] TTS 시작 — 마이크 버튼 비활성화");
    };

    _ttsService.onComplete = () {
      if (isFairyMode) {
        debugPrint("[InCallScreen] FairyMode active → 마이크 상태 유지 (비활성)");
        return;
      }

      if (mounted) {
        setState(() {
          _isListening = false; // 여전히 비활성화 상태 유지
        });
      }
      debugPrint("[InCallScreen] TTS 완료 — 마이크 다시 활성화 가능");
    };




    // 요정모드 말풍선 변경 콜백
    _fairyService.onFairySpeak = (line) {
      if (!mounted) return;
      setState(() {
        dummySpeech = line;
        _isListening = false;
      });
    };

    _fairyService.onChildSpeak = (line) {
      if (!mounted) return;
      setState(() {
        childSpeech = line;
      });
    };


    _loadCharacterSettings().then((_) async {
      await _initializeSTT();
      Future.delayed(const Duration(seconds: 1), _speakInitialGreeting);
    });
  }

  Future<void> _speakInitialGreeting() async {
    _isGreeting = true; // 마이크 비활성화 시작
    final lastChar = _characterName.characters.last;
    final codeUnit = lastChar.codeUnitAt(0);
    final hasBatchim = (codeUnit - 0xAC00) % 28 != 0; // 받침 여부 판별
    final ending = hasBatchim ? "이야" : "야";

    final greeting = "안녕! 나는 $_characterName$ending. 오늘 뭐하고 있었어?";


    setState(() => dummySpeech = greeting);

    final conv = ConversationService(stt: _sttService, tts: _ttsService);
    await conv.saveMessage(
      dbPath: widget.dbPath,
      role: "z_assistant",
      text: greeting,
    );

    await _ttsService.speak(greeting, UserInfo.name ?? "unknown").whenComplete(() {
      _isGreeting = false;
      debugPrint("[InCallScreen] 초기 인사 완료 — 마이크 다시 활성화됨");
    });

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
          characterName: settings.characterName,
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

      // 아이 발화 텍스트 표시 + GPT 준비 상태 진입
      setState(() {
        childSpeech = text;
        final currentStage = _conversation.conversationStage;
        if (currentStage >= 2 && !_isFairyButtonEnabled) {
          _isFairyButtonEnabled = true;
        }
        isSpeaking = true;

        dummySpeech = "음... 생각 중이야";
        _isThinking = true; // GPT 생각 중 → 마이크 회색 유지
      });

      _conversation.registerUserSpeech(text);

      final userName = UserInfo.name ?? "unknown";
      final stageInstruction =
      await _conversation.getStageInstruction(username: userName, characterName: _characterName);

      // GPT 응답 생성
      final reply = await gpt.sendMessageToLLM(
        text,
        stageInstruction: stageInstruction,
      );

      if (_isEndingCall || reply.isEmpty) return;

      // GPT 응답 도착 시 — 말풍선 업데이트만 하고, 버튼은 계속 회색 유지
      if (mounted) {
        setState(() {
          dummySpeech = reply; // 말풍선만 변경
          // _isThinking 유지 (아직 TTS 시작 안 됨)
        });
      }

      // TTS 실행 전, _isThinking을 false로 바꾸면서 onStart에서 회색 유지
      _isThinking = false;
      await _ttsService.speak(reply, UserInfo.name ?? "unknown");

      // 대화 로그 저장
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

      // 타이밍 기록 업데이트
      _lastAssistantEndTime = DateTime.now();
      _speechStartTime = null;

      debugPrint("[InCallScreen] Whisper 결과 처리 완료 — STT 대기 상태로 전환됨");
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
      const bool useDalle = false; // 개발 테스트용 -> false
      String imageBase64 = "";

      if (useDalle) {
        try {
          // DB에서 characterName과 summary 불러오기
          final ref = FirebaseDatabase.instance.ref(widget.dbPath);
          final snapshot = await ref.get();

          String dbCharacterName = _characterSettings?.characterName ?? "캐릭터";
          String dbSummary = "";

          if (snapshot.exists) {
            final data = Map<String, dynamic>.from(snapshot.value as Map);
            dbCharacterName = data["characterName"] ?? dbCharacterName;
            dbSummary = data["conversation"]?["summary"] ?? "";
          }

          // 프롬프트 구성
          final imagePrompt = dbSummary.isNotEmpty
              ? "$dbSummary\n이 내용을 바탕으로 $dbCharacterName 이(가) 등장하는 따뜻하고 밝은 분위기의 장면을 그려줘."
              : "$dbCharacterName 이(가) 행복하게 미소 짓는 장면을 그려줘.";

          debugPrint("[InCallScreen] 이미지 프롬프트: $imagePrompt");

          // 이미지 생성 및 DB 저장
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

  // 말하기 버튼: STT 수동 제어
  Future<void> _toggleRecording() async {
    if (_ttsService.isPlaying || _isGreeting) return;
    if (_isListening) {
      // 녹음 중 → 중지 + Whisper 전송
      setState(() => _isListening = false);
      await _sttService.stopListening();
      debugPrint("[InCallScreen] 사용자가 말하기 종료");
    } else {
      // 녹음 시작
      await _ttsService.stop(); // 혹시 캐릭터가 말 중이면 중단
      await _sttService.startListening();
      setState(() => _isListening = true);
      _speechStartTime = DateTime.now();
      debugPrint("[InCallScreen] 사용자가 말하기 시작");
    }
  }

  void _toggleFairyMode() async {
    if (!isFairyMode) {
      // 모든 음성 중단 (캐릭터 말 완전히 멈춤)
      await _ttsService.stop();
      await _sttService.stopListening(tempStop: true);

      // UI 먼저 변경 (요정 등장)
      setState(() {
        isFairyMode = true;
        dummySpeech = "✨요정이 나타났어! 너를 도와주러 왔어~✨";
      });

      // 대화 로직 전환
      _conversation.enableFairyMode();

      // 요정 첫 인사 (겹치지 않게 순차 실행)
      final userName = UserInfo.name ?? "unknown";

      // 요정 인사 먼저 말하기
      await _ttsService.speak("요정이 나타났어! 너를 도와주러 왔어.", userName);

      // TTS 완전히 끝난 뒤 0.5초 대기 (MediaCodec 안정화 시간)
      await Future.delayed(const Duration(milliseconds: 500));

      // 이제 요정 모드 대화 시작
      await _fairyService.startGuidedSession(
        username: userName,
        characterName: _characterSettings?.characterName ?? "캐릭터",
      );


      // 요정 Flow 시작
      await _fairyService.startGuidedSession(
        username: userName,
        characterName: _characterSettings?.characterName ?? "캐릭터",
      );

    } else {
      // 요정모드 종료
      await _fairyService.stopSession();
      _conversation.disableFairyMode();
      await _ttsService.stop();
      gpt.resetCharacterContext();
      _conversation.resetContext();

      const message = "요정이 쉬러 갔어~ 이제 다시 나랑 이야기하자 😊";
      setState(() {
        isFairyMode = false;
        dummySpeech = message;
      });

      final userName = UserInfo.name ?? "unknown";
      await _ttsService.speak(message, userName);

      // 요정모드 콜백 해제 후 TTS 이벤트 원복
      _ttsService.onComplete = () {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
        debugPrint("[InCallScreen] 캐릭터모드 복귀 — TTS 완료 후 마이크 활성화 가능");
      };
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFairyMode
                ? [
              Color(0xFFD1C4E9),
              Color(0xFFA9C2DE),
              Color(0xFFB3E5FC),
            ]
                : [
              Color(0xFFFFE0F0),
              Color(0xFFFFF9C4),
              Color(0xFFB3E5FC),
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
                      color: Color(0xFF787878),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.white70,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "통화 중...",
                    style: TextStyle(
                      color: Color(0xFF898989),
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
              top: MediaQuery.of(context).size.height * 0.4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 240,
                child: Image.asset(
                  isFairyMode
                      ? 'assets/characters/fairy.png' // 요정모드일 때 이미지
                      : isSpeaking
                      ? 'assets/characters/character_talking.gif'  // TODO: 동적 렌더링 수정
                      : 'assets/characters/character.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              child: TopBubble(text: dummySpeech, isFairyMode: isFairyMode,),
            ),
            Positioned(
              bottom: 160,
              child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEBF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFD180),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                child: Builder(
                  builder: (_) {
                    final name = UserInfo.name ?? "아이";
                    final lastChar = name.characters.last;
                    final codeUnit = lastChar.codeUnitAt(0);
                    final hasBatchim = (codeUnit - 0xAC00) % 28 != 0; // 받침 여부 판별
                    final particle = hasBatchim ? "이" : ""; // 받침 있으면 "이", 없으면 공백
                    final defaultText = "$name$particle가 말하는 내용은 여기 나타날 거야.";

                    return Text(
                      childSpeech.isEmpty ? defaultText : childSpeech,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF000000),
                        fontSize: 15,
                        height: 1.3,
                      ),
                    );
                  },
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
                  const SizedBox(width: 40),

                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: const Color(0xFFFF6B6B),
                    onPressed: _onEndCall,
                    child: const Icon(Icons.call_end, size: 36),
                  ),

                  const SizedBox(width: 40),

                  FloatingActionButton(
                    heroTag: 'mic',
                    backgroundColor: _isListening
                        ? const Color(0xFFed6b72)
                        : (_isThinking || _ttsService.isPlaying || _isGreeting
                        ? Colors.grey
                        : const Color(0xFF68d94e)),
                    onPressed: (_isThinking || _ttsService.isPlaying || _isGreeting)
                        ? null
                        : _toggleRecording,

                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      size: 32,
                      color: Colors.white,
                    ),
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
