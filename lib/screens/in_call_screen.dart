import 'package:flutter/material.dart';
import 'report_screen.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/llm_service.dart';
import '../services/report_service.dart';
import '../services/conversation_service.dart';
import '../utils/user_info.dart';
import '../models/character_settings_model.dart';
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
  bool _isGreeting = false;
  bool _isListening = false; // 사용자가 현재 말하고 있는지 여부. 버튼 조작
  bool _isThinking = false; // GPT 처리중
  String _trafficLightAsset = 'assets/temp/traffic_light.png';
  int stage2InternalTurn = 0;
  int stage2FailCount = 0;
  bool isForcedSkip = false;


  String dummySpeech = "";
  String childSpeech = "";
  CharacterSettings? _characterSettings;
  DateTime? _lastAssistantEndTime;
  DateTime? _speechStartTime;
  String _characterName = "캐릭터";

  late STTService _sttService;
  late TTSService _ttsService;
  final GPTResponse gpt = GPTResponse();

  late ConversationService _conversation;


  Future<void> _handleStage2Retry() async {
    final userName = UserInfo.name ?? "친구";
    String? contextText;
    try {
      final _db = FirebaseDatabase.instance.ref();
      final ref = _db.child('preference/$userName/character_settings/contextText');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        contextText = snapshot.value.toString();
        debugPrint("[Conversation] contextText 로드 완료: $contextText");
      } else {
        debugPrint("[Conversation] contextText 없음");
      }
    } catch (e) {
      debugPrint("[Conversation] contextText 로드 실패: $e");
    }
    final retryPrompt = """
너는 지금 2단계야. 아이가 대답을 맞추지 못했어.
하지만 아이가 기분 나쁘지 않도록, 부드럽고 자연스럽게 다시 질문해야 해.
      너는 '${contextText ?? "작은 문제가 생긴 상황"}' 상황을 겪고 있어 곤란한 상태야.
      이 상황을 설명하면서 다시 도움을 요청해.
      $userName이 너를 도와주는 영웅처럼 느끼게 해줘.
규칙:
- "틀렸어" 같은 표현 금지
- 자연스럽고 힌트를 조금만 섞은 재질문
- 아이가 다시 시도할 기회를 느끼게
""";

    setState(() {
      dummySpeech = "음... 다시 생각해볼까?";
      _isThinking = true;
    });

    final reply = await gpt.sendMessageToLLM(
      "아이가 질문에 답하지 못했어. 다시 자연스럽게 물어봐줘.",
      stageInstruction: retryPrompt,
    );

    setState(() {
      dummySpeech = reply;
      _isThinking = false;
    });

    await _ttsService.speak(reply, userName);
    _lastAssistantEndTime = DateTime.now();
  }


  Future<void> restartstage2() async {
    final userName = UserInfo.name ?? "친구";
    setState(() {
      _trafficLightAsset = 'assets/temp/traffic_light.png';
      stage2FailCount = 0;
      isForcedSkip = false;

      _conversation.conversationStage = 2;

      _isListening = false;  // 캐릭터 말할 때까지 OFF
      _isThinking = true;
      dummySpeech = "잠깐만...";
    });

    // Stage2 첫 질문 프롬프트 생성
    final stage2Instruction = await _conversation.getStageInstruction(
      username: userName,
      characterName: _characterName,
    );

    final firstQuestion = await gpt.sendMessageToLLM(
      "Stage2 문제 상황을 기억해. ",
      stageInstruction: stage2Instruction,
    );

    setState(() {
      dummySpeech = firstQuestion;
      _isThinking = false;
    });

    // 캐릭터가 Stage2 첫 질문 말하기
    await _ttsService.speak(firstQuestion, userName);

    // 캐릭터 말 끝 → 아이 말 가능
    setState(() {
      _isThinking = false;
      _isGreeting = false;
    });


    _lastAssistantEndTime = DateTime.now();
  }



  Future<void> _goToStage5() async {
    debugPrint("[Stage5] 강제 스킵 실행");

    setState(() {
      _isListening = false;
      _isThinking = true;
      dummySpeech = "잠깐만…";
    });

    final userName = UserInfo.name ?? "친구";

    final stage5Instruction = """
너는 Stage5야.

역할:
1. 아이가 틀린 문제를 자연스럽게 설명하고 정답을 알려줘.
2. 아이가 노력한 것에 대해 따뜻하게 칭찬해.
3. 너무 길지 않게 말해 (2~3문장)
금지:
- 부정적 표현
- 아이 기죽이는 말
""";

    final reply = await gpt.sendMessageToLLM(
      "아이에게 문제의 정답을 알려주고 부드럽게 칭찬해줘.",
      stageInstruction: stage5Instruction,
    );

    setState(() {
      dummySpeech = reply;
      _isThinking = false;
    });

    await _ttsService.speak(reply, userName);

    await Future.delayed(const Duration(milliseconds: 400));

    //-------------------------------------------------------
    // Stage5 끝 → Stage2 재시작
    //-------------------------------------------------------

    await restartstage2();

  }

  Future<void> complimentaftersuccess() async {
    setState(() {
      _isListening = false;
      _isThinking = true;
    });

    final userName = UserInfo.name ?? "친구";

    final stage5Instruction = """

역할:
1. 아이가 정답을 말한 것을 크게 칭찬해줘
2. 아이가 노력한 것에 대해 따뜻하게 칭찬해.
3. 너무 길지 않게 말해 (2~3문장)
금지:
- 부정적 표현
- 아이 기죽이는 말
""";

    final reply = await gpt.sendMessageToLLM(
      "아이에게 부드럽게 칭찬해줘.",
      stageInstruction: stage5Instruction,
    );

    setState(() {
      dummySpeech = reply;
      _isThinking = false;
    });

    await _ttsService.speak(reply, userName);

    await Future.delayed(const Duration(milliseconds: 400));

    //-------------------------------------------------------
    // 칭찬 끝 → Stage2 재시작
    //-------------------------------------------------------

    await restartstage2();
  }


  @override
  void initState() {
    super.initState();

    // 서비스 초기화
    _sttService = STTService(callId: "test_call_001");
    _ttsService = TTSService();
    _conversation = ConversationService(stt: _sttService, tts: _ttsService);

    // TTS 상태 스트림 감시 (음성 재생 중/완료 등)
    _ttsService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          // player 상태 변화에 따른 UI 갱신
          _isListening = false;
        });
      }
      debugPrint("[InCallScreen] TTS 완료 — 마이크 다시 활성화 가능");
    });

    // TTS 시작 이벤트 설정
    _ttsService.onStart = () {
      if (mounted) {
        setState(() {
          _isListening = false; // 말하는 동안 마이크 비활성화
        });
      }
      debugPrint("[InCallScreen] TTS 시작 — 마이크 버튼 비활성화");
    };

    // TTS 완료 이벤트 설정
    _ttsService.onComplete = () {
      if (mounted) {
        setState(() {
          _isListening = false; // 다시 마이크 활성화 가능
        });
      }
      debugPrint("[InCallScreen] TTS 완료 — 마이크 다시 활성화 가능");
    };

    // 캐릭터 설정 및 STT 초기화 후 인사 발화
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

      final ref = FirebaseDatabase.instance.ref('preference/$childName/character_settings');
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

      // 👉 Stage 바뀌기 전 단계(이전 단계) 기억
      final prevStage = _conversation.conversationStage;

      final now = DateTime.now();

      // 발화 시간 및 반응 속도 계산
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

      // 아이 발화 텍스트 표시
      setState(() {
        childSpeech = text;
        isSpeaking = true;
      });

      // 👉 여기서 turnCount / conversationStage 업데이트
      _conversation.registerUserSpeech(text);
      final currentStage = _conversation.conversationStage;

      // "방금 막 Stage2로 진입했는지" 여부
      final bool justEnteredStage2 =
      (prevStage != 2 && currentStage == 2);

      // GPT가 실제로 말했는지 여부
      bool didAssistantSpeak = false;
      String reply = "";

      final userName = UserInfo.name ?? "unknown";

      // ================================
      // 🌟 Stage2 로직
      // ================================
      if (currentStage == 2 && !justEnteredStage2) {
        // 👉 이미 Stage2인 상태에서 아이가 또 말한 경우
        //    → 부모 투명 버튼 입력을 기다려야 하므로 GPT는 조용히 있음.
        debugPrint("[Stage2] 아이 발화 → GPT 발화 잠시 중지, 부모 판단 대기 모드");

        setState(() {
          _isThinking = false; // 마이크/버튼 다시 활성화
          // dummySpeech 는 이전 캐릭터 말풍선 그대로 유지
          // 노란불은 녹음 시작 시에 이미 켜졌다고 가정
        });

        // 이 경우에는 reply 없이, user 메시지만 로그에 남기고 종료
      } else {
        // ================================
        // 🌟 Stage1 이거나
        // 🌟 "방금 막" Stage2로 진입한 첫 턴(도움요청 질문)인 경우
        //     → GPT가 정상적으로 발화해야 함
        // ================================
        setState(() {
          dummySpeech = "음... 생각 중이야";
          _isThinking = true;
        });

        final stageInstruction = await _conversation.getStageInstruction(
          username: userName,
          characterName: _characterName,
        );

        // GPT 응답 생성
        reply = await gpt.sendMessageToLLM(
          text,
          stageInstruction: stageInstruction,
        );

        if (_isEndingCall || reply.isEmpty) {
          setState(() => _isThinking = false);
          return;
        }

        if (mounted) {
          setState(() {
            dummySpeech = reply;
            _isThinking = false;
          });
        }

        // TTS 실행
        await _ttsService.speak(reply, userName);
        didAssistantSpeak = true;
        _lastAssistantEndTime = DateTime.now();
      }
      // 🔥🔥🔥 [여기까지가 Stage2에서는 실행하면 안 되는 부분임!] -------------------
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
      const bool useDalle = true; // 개발 테스트용 -> false
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

  // 3단계로 강제 전환
  Future<void> _forceNextStage() async {
    if (_isThinking || _isGreeting || _ttsService.isPlaying) return;

    debugPrint("[InCallScreen] Next 버튼 클릭 → 3단계(마무리) 전환 시작");

    await _sttService.stopListening();
    await _ttsService.stop();

    setState(() {
      _isListening = false;
      _isThinking = true;
      dummySpeech = "마무리하는 중...";
    });

    // 서비스의 상태를 먼저 3단계로 강제 변경
    // 턴수도 강제로 늘려둬야 나중에 서비스 로직에 의해 단계가 롤백되지 않음
    _conversation.conversationStage = 3;
    _conversation.turnCount = 20;

    try {
      final userName = UserInfo.name ?? "친구";

      final stageInstruction = await _conversation.getStageInstruction(
        username: userName,
        characterName: _characterName,
      );

      final transitionReply = await gpt.sendMessageToLLM(
        "이제 헤어질 시간이야. 작별 인사를 해줘.",
        stageInstruction: stageInstruction, // 여기에 3단계 프롬프트가 들어감
      );

      if (!mounted) return;

      setState(() {
        dummySpeech = transitionReply;
        _isThinking = false;
      });

      await _conversation.saveMessage(
        dbPath: widget.dbPath,
        role: "z_assistant",
        text: transitionReply,
      );

      await _ttsService.speak(transitionReply, userName);

    } catch (e) {
      debugPrint("단계 전환 중 오류: $e");
      if (mounted) {
        setState(() => _isThinking = false);
      }
    }
    _onEndCall();
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
      // 🔥 2단계 + GPT 발화 직후 + 아이가 말하려는 순간 → 노란불 켜기
      if (_conversation.conversationStage == 2 && !_ttsService.isPlaying && !_isThinking && !_isGreeting) {
        setState(() {
          _trafficLightAsset = 'assets/temp/yellow_traffic_light.png';
        });

        debugPrint("[TrafficLight] 2단계 발화 대기 → 노란 불 ON");
      }

      // 녹음 시작
      await _ttsService.stop(); // 혹시 캐릭터가 말 중이면 중단
      await _sttService.startListening();
      setState(() => _isListening = true);
      _speechStartTime = DateTime.now();
      debugPrint("[InCallScreen] 사용자가 말하기 시작");
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
            /// ================== 신호등 + 투명 버튼 ==================
            Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                const trafficWidth = 120.0;
                const trafficHeight = 50.0;

                // 신호등 위치 계산
                final trafficLeft = screenWidth / 2 - trafficWidth / 2;
                final trafficRight = screenWidth / 2 + trafficWidth / 2;

                const buttonHeight = trafficHeight * 4;

                final isStage2 = (_conversation.conversationStage == 2);

                return Stack(
                  children: [
                    // ★ 신호등
                    Positioned(
                      top: 60,
                      left: trafficLeft,
                      child: SizedBox(
                        width: trafficWidth,
                        height: trafficHeight,
                        child: Image.asset(
                          _trafficLightAsset,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),

                    // ★ 왼쪽 버튼 (FAIL)
                    Positioned(
                      top: 60,
                      left: 0,
                      width: trafficLeft,
                      height: buttonHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: isStage2
                            ? () async {
                          debugPrint("[TrafficLight] FAIL 버튼 클릭");

                          setState(() {
                            stage2FailCount++;
                            _trafficLightAsset = 'assets/temp/red_traffic_light.png';
                          });

                          // 3번 실패 → 강제 스킵 가능
                          if (stage2FailCount >= 3) {
                            debugPrint("[Stage2] 실패 3회 → Stage5로 이동 가능");
                            isForcedSkip = true;
                            _handleStage2Retry();
                          } else {
                            // 실패 1~2회 → GPT가 자연스럽게 다시 물어보기
                            _handleStage2Retry();
                          }
                        }
                        : null, // 🔒 2단계가 아니면 클릭 불가
                      ),
                    ),

                    // ★ 오른쪽 버튼 (SUCCESS)
                    Positioned(
                      top: 60,
                      left: trafficRight,
                      width: screenWidth - trafficRight,
                      height: buttonHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: isStage2
                            ? () {
                          debugPrint("[TrafficLight] SUCCESS 클릭됨");

                          // 신호등 초록색
                          setState(() {
                            _trafficLightAsset =
                            'assets/temp/green_traffic_light.png';
                          });
                          //엄청난 칭찬하기
                          complimentaftersuccess();
                        }
                            : null, // 🔒 2단계 아니면 클릭불가
                      ),
                    ),
                  ],
                );
              },
            ),

            /// ================== 신호등 + 투명 버튼 ==================



            Positioned(
              top: 120,
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
                  'assets/characters/character_talking.gif', // 항상 GIF 렌더링 (TODO: 동적 수정)
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              child: TopBubble(text: dummySpeech, isFairyMode: isFairyMode,),
            ),
            Positioned(
              bottom: 150,
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
              bottom: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'next',
                    backgroundColor: const Color(0xFF7CCAF3),
                    onPressed: isForcedSkip? () {_goToStage5();}:null,
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 40),

                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: const Color(0xFFFF6B6B),
                    onPressed: _forceNextStage,
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
