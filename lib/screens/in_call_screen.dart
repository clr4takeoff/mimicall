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

  // 왼쪽 히든 버튼 로직
  void _onLeftHiddenTap() {
    debugPrint("왼쪽 투명 버튼 누름 - 실패 진행");
    // TODO: 실패 로직 구현
  }

  // 오른쪽 히든 버튼 로직
  void _onRightHiddenTap() {
    debugPrint("오른쪽 투명 버튼 눌림 - 성공 진행");
    // TODO: 성공 로직 구현
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
          context: settings.contextList.join(", "),
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

      // 아이 발화 텍스트 표시 + GPT 준비 상태 진입
      setState(() {
        childSpeech = text;
        isSpeaking = true;
        dummySpeech = "음... 생각 중이야";
        _isThinking = true; // GPT 생각 중 → 마이크 회색 유지
      });

      _conversation.registerUserSpeech(text);

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
                    onPressed: _forceNextStage,
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
