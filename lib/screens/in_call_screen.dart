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
import '../widgets/hidden_touch_layer.dart';
import '../services/scenario_service.dart';
import '../services/mission_service.dart';


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
  bool _isHintMode = false;
  int _stage2TurnCount = 0;

  String dummySpeech = "";
  String childSpeech = "";
  CharacterSettings? _characterSettings;
  DateTime? _lastAssistantEndTime;
  DateTime? _speechStartTime;
  String _characterName = "캐릭터";
  String _lastSystemMessage = "";

  late STTService _sttService;
  late TTSService _ttsService;
  late ScenarioService _scenarioService;
  late MissionService _missionService;
  final GPTResponse gpt = GPTResponse();

  late ConversationService _conversation;

  @override
  void initState() {
    super.initState();

    // 서비스 초기화
    _sttService = STTService(callId: "test_call_001");
    _ttsService = TTSService();
    _scenarioService = ScenarioService();
    _missionService = MissionService();
    _conversation = ConversationService(
        stt: _sttService,
        tts: _ttsService,
        scenarioService: _scenarioService
    );

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

    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final userName = UserInfo.name ?? "unknown";

    // 앱 시작 시 랜덤 시나리오 로드
    await _scenarioService.loadNewScenario(userName);

    // 이후 캐릭터 설정 및 STT 초기화
    await _loadCharacterSettings();
    await _initializeSTT();
    Future.delayed(const Duration(seconds: 1), _speakInitialGreeting);
  }

  // 왼쪽 히든 버튼 로직 (실패 처리)
  Future<void> _onLeftHiddenTap() async {
    final userName = UserInfo.name ?? "unknown";

    // 1. [모방 모드일 때] 왼쪽 버튼 클릭 -> 힌트 TTS 재생 (듣고 따라하기 시도)
    if (_isHintMode) {
      debugPrint("모방 모드 중 왼쪽 클릭 -> 힌트 오디오 재생");

      if (_ttsService.isPlaying) await _ttsService.stop();

      // 화면에 떠있는 dummySpeech를 읽어줌
      await _ttsService.speak(dummySpeech, userName);
      return;
    }

    // 2. [일반 모드일 때] 실패 카운트 증가 로직
    debugPrint("일반 모드 왼쪽(실패) 버튼 눌림");

    // 동작 중단
    await _ttsService.stop();
    await _sttService.stopListening(tempStop: true);

    // 서비스 호출
    final result = await _missionService.handleFailure(
      userName: userName,
      scenarioService: _scenarioService,
      gpt: gpt,
    );

    if (!mounted) return;

    if (result.type == MissionResultType.hintMode) {
      // 3회 누적 -> 모방 모드 진입
      debugPrint("3회 누적, 힌트 텍스트 표시 (TTS 대기)");

      final hintMessage = result.message!;

      setState(() {
        dummySpeech = hintMessage; // 텍스트 갱신
        _isHintMode = true; // 모방모드 활성화
        _isThinking = false;
      });

      // DB 저장 (타입: hint_guide)
      await _conversation.saveMessage(
        dbPath: widget.dbPath,
        role: "z_assistant",
        text: hintMessage,
        extra: {"type": "hint_guide"},
      );

      // speak() 호출하지 않음
      // 다시 왼쪽 버튼을 눌러야 소리남

    } else {
      // 3회 미만 -> 단순 재질문 (기존 로직)
      debugPrint("재시도 모드 (${_missionService.currentFailureCount}/3)");

      setState(() => _isThinking = false);

      // 기존 질문 다시 읽기
      await _ttsService.speak(dummySpeech, userName);
    }
  }

  // 오른쪽 히든 버튼 로직 (성공 처리)
  Future<void> _onRightHiddenTap() async {
    debugPrint("오른쪽(성공) 버튼 눌림");

    // 동작 중지
    await _ttsService.stop();
    await _sttService.stopListening(tempStop: true);

    // 성공했으므로 모방 모드 해제
    if (_isHintMode) {
      debugPrint("모방 성공, 모방모드 해제");
      setState(() {
        _isHintMode = false;
      });
    }

    // 실패 카운트 리셋
    _missionService.reset();

    // 칭찬 및 3단계 이동
    await _enterPraiseMode();
  }

  Future<void> _speakInitialGreeting() async {
    _isGreeting = true; // 마이크 비활성화 시작
    final lastChar = _characterName.characters.last;
    final codeUnit = lastChar.codeUnitAt(0);
    final hasBatchim = (codeUnit - 0xAC00) % 28 != 0; // 받침 여부 판별
    final ending = hasBatchim ? "이야" : "야";

    final greeting = "안녕! 나는 $_characterName$ending. 오늘 뭐하고 있었어?";


    setState(() => dummySpeech = greeting);

    await _conversation.saveMessage(
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

        final currentScenario = _scenarioService.currentContext ?? "일상 대화";

        gpt.initializeCharacterContext(
          characterName: settings.characterName,
          context: currentScenario,
          contextText: currentScenario,
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

      // GPT 준비 상태 진입
      setState(() {
        childSpeech = text;
        isSpeaking = true;
        dummySpeech = "음... 생각 중이야";
        _isThinking = true;
      });

      _conversation.registerUserSpeech(text);

      // 2단계: 마이크 트리거 비활성화
      if (_conversation.conversationStage == 2) {
        // 0, 1 (총 2회) 까지는 허용
        if (_stage2TurnCount < 2) {
          debugPrint("[InCallScreen] 2단계 발화 허용 (${_stage2TurnCount + 1}번째)");

          _stage2TurnCount++;
        } else {
          // B. 두 번째 발화부터 차단 (버튼 대기)
          debugPrint("[InCallScreen] 2단계 추가 발화 -> 자동 응답 차단. 보호자 버튼 대기.");

          if (mounted) {
            setState(() {
              _isThinking = false;
              // 기억해둔 마지막 질문으로 복구 (없으면 기본값)
              dummySpeech = _lastSystemMessage.isNotEmpty
                  ? _lastSystemMessage
                  : "다시 한 번 말해줄래?";
            });
          }
          // DB 저장만 하고 종료
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
          return;
        }
      }

      // 1,3단계: 마이크 트리거 활성화
      final userName = UserInfo.name ?? "unknown";
      final stageInstruction = await _conversation.getStageInstruction(
        username: userName,
        characterName: _characterName,
      );

      // GPT 응답 생성
      final reply = await gpt.sendMessageToLLM(
        text,
        stageInstruction: stageInstruction,
      );

      if (_isEndingCall || reply.isEmpty) return;

      // GPT 응답 도착 시 — 말풍선 업데이트만 하고, 버튼은 계속 회색 유지
      if (mounted) {
        setState(() {
          _lastSystemMessage = reply;
          dummySpeech = reply; // 말풍선만 변경
          // _isThinking 유지 (아직 TTS 대기)
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
          child: CircularProgressIndicator(color: Colors.orange),
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

  // 성공 처리 & 3단계(칭찬) 진입
  Future<void> _enterPraiseMode() async {
    final userName = UserInfo.name ?? "친구";

    debugPrint("[InCallScreen] 🎉 미션 성공! 3단계(칭찬 모드) 진입");

    // 1. 동작 중지
    await _ttsService.stop();
    await _sttService.stopListening(tempStop: true);

    // 2. 모방 모드 해제
    if (_isHintMode) setState(() => _isHintMode = false);

    // 3. 실패 카운트 리셋
    _missionService.reset();

    // 4. 서비스 상태를 3단계로 변경
    // (이제부터 아이가 말을 걸면 ConversationService의 3단계 프롬프트가 적용됨)
    _conversation.conversationStage = 3;

    final solvedMission = _scenarioService.currentTargetSpeech ?? "정답";

    _conversation.registerUserSpeech(solvedMission); // 턴 수 증가

    setState(() {
      _isThinking = true;
      dummySpeech = "생각하는 중...";
    });

    await _conversation.saveMessage(
      dbPath: widget.dbPath,
      role: "user",
      text: solvedMission,
      extra: {
        "isCorrectAnswer": true,
        "scenarioContext": _scenarioService.currentContext,
      },
    );

    // 칭찬 멘트 생성 및 재생
    final praisePrompt = """
    아이가 미션인 '$solvedMission'을 말하는 데 성공했어!
    캐릭터로서 아주 기뻐하면서 아이를 듬뿍 칭찬해줘.
    반말을 사용하고, 감탄사를 섞어서 신나게 말해줘.
    """;

    final praiseMessage = await gpt.sendMessageToLLM(
        "나 말하는 것에 성공했어!", // 트리거
        stageInstruction: praisePrompt
    );

    if (!mounted) return;

    setState(() {
      dummySpeech = praiseMessage;
      _isThinking = false;
    });

    // 칭찬 DB 저장
    await _conversation.saveMessage(
      dbPath: widget.dbPath,
      role: "z_assistant",
      text: praiseMessage,
      extra: {"type": "praise"},
    );

    await _ttsService.speak(praiseMessage, userName);

    // 이제 아이가 마이크에 대고 말을 하면 STT 리스너가 동작하고, 3단계 대화를 이어가게 됨
  }


  // 새로운 라운드(2단계) 시작
  Future<void> _startNextMission() async {
    // 칭찬 중이거나 인사 중이면 무시 (원하면 빼도 됨)
    if (_isGreeting) return;

    final userName = UserInfo.name ?? "친구";
    debugPrint("[InCallScreen] 🔄 Next 버튼 클릭 -> 다음 미션(2단계) 로드");

    // 1. 동작 중지
    await _ttsService.stop();
    await _sttService.stopListening(tempStop: true);

    setState(() {
      _isThinking = true;
      dummySpeech = "생각 중...";
    });

    // 1. 랜덤 시나리오 교체
    await _scenarioService.loadNewScenario(userName);

    // 2. 대화 서비스 상태를 2단계로 설정
    _conversation.startNewRound();
    _stage2TurnCount = 0;

    // 3. GPT 대화 맥락 삭제
    gpt.startNewTopic();

    // 새로운 문제 제시
    if (!mounted) return;

    // 새 상황 지침 가져오기
    final nextStageInstruction = await _conversation.getStageInstruction(
      username: userName,
      characterName: _characterName,
    );

    // GPT에게 새로운 문제 상황 연기 요청
    final newProblemMessage = await gpt.sendMessageToLLM(
        "(새로운 상황 시작)",
        stageInstruction: nextStageInstruction
    );

    if (!mounted) return;

    setState(() {
      dummySpeech = newProblemMessage;
      _isThinking = false;
    });

    // 새 문제 DB 저장
    await _conversation.saveMessage(
      dbPath: widget.dbPath,
      role: "z_assistant",
      text: newProblemMessage,
      extra: {"type": "new_mission"},
    );

    await _ttsService.speak(newProblemMessage, userName);
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
              top: 60,
              child: SizedBox(
                width: 120,
                height: 50,
                child: Image.asset(
                  'assets/temp/traffic_light.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
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
              child: TopBubble(text: dummySpeech),
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
                    onPressed: _startNextMission,
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
            HiddenTouchLayer(
              height: 200,
              onLeftTap: _onLeftHiddenTap,
              onRightTap: _onRightHiddenTap,
            ),
          ],
        ),
      ),
    );
  }
}
