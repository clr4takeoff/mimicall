import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'tts_service.dart'; // TTSService를 불러오기 (경로에 맞게 수정)

class STTService {
  final String callId;
  final Record _recorder = Record();
  final TTSService? ttsService; // TTSService 참조 (이전 TTS 음성 제거용)
  bool _isRecording = false;
  bool _isStopped = false;
  Timer? _silenceTimer;

  String? _lastText;
  bool _isProcessing = false;

  Function(String text)? onResult;
  Function()? onSpeechDetected;

  bool _speechDetected = false;

  STTService({required this.callId, this.ttsService});

  Future<void> initialize() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint("[STT] 마이크 권한이 없습니다.");
      return;
    }
    debugPrint("[STT] 초기화 완료");
  }

  Future<void> startListening() async {
    if (_isRecording || _isStopped) return;
    _isStopped = false;
    _isRecording = true;
    _speechDetected = false;

    final tempDir = Directory.systemTemp.path;
    final filePath = "$tempDir/temp_${DateTime.now().millisecondsSinceEpoch}.m4a";

    debugPrint("[STT] 녹음 시작: $filePath");

    await _recorder.start(
      path: filePath,
      encoder: AudioEncoder.aacLc,
      bitRate: 96000,
      samplingRate: 16000,
      numChannels: 1,
    );

    _startSilenceDetection(filePath);
  }

  void _startSilenceDetection(String path) {
    debugPrint("[STT] 무음 감지 시작");
    const silenceThreshold = -50.0;
    const speechTriggerDb = -40.0;
    const silenceDuration = Duration(seconds: 2);
    const checkInterval = Duration(milliseconds: 400);

    Duration silentFor = Duration.zero;
    double maxDbDuringRecording = -120.0;
    double minDbDuringRecording = 0.0;
    _silenceTimer?.cancel();

    _silenceTimer = Timer.periodic(checkInterval, (_) async {
      if (_isStopped || _isProcessing) return;

      final amp = await _recorder.getAmplitude();
      final currentDb = amp.current ?? -120;

      // 현재 TTS 음성 재생 중이면 STT 입력 무시
      if (ttsService?.isPlaying == true) {
        debugPrint("[STT] 현재 TTS 재생 중 → 입력 무시");
        silentFor = Duration.zero;
        return;
      }

      // 첫 음성 감지
      if (!_speechDetected && currentDb > speechTriggerDb) {
        _speechDetected = true;
        debugPrint("[STT] 첫 음성 감지됨 (${currentDb.toStringAsFixed(1)} dB)");
        if (onSpeechDetected != null) onSpeechDetected!();
      }

      if (currentDb > maxDbDuringRecording) maxDbDuringRecording = currentDb;
      if (currentDb < minDbDuringRecording) minDbDuringRecording = currentDb;

      if (currentDb < silenceThreshold) {
        silentFor += checkInterval;
      } else {
        silentFor = Duration.zero;
      }

      if (silentFor >= silenceDuration) {
        _silenceTimer?.cancel();
        debugPrint("[STT] 무음 감지됨 → 녹음 중지 및 Whisper 요청");
        await stopListening(tempStop: true);

        final file = File(path);
        if (await file.exists()) {
          final length = await file.length();
          final dynamicRange = maxDbDuringRecording - minDbDuringRecording;

          if (length > 8000 && dynamicRange > 6) {
            debugPrint("[STT] 유효한 발화 감지 → Whisper 전송");
            await _sendToWhisper(path);
          } else {
            debugPrint("[STT] 무음/잡음으로 판단 → Whisper 생략");
          }
        }

        maxDbDuringRecording = -120.0;
        minDbDuringRecording = 0.0;

        if (!_isStopped) {
          debugPrint("[STT] 다음 입력 대기 중...");
          await Future.delayed(const Duration(milliseconds: 800));
          await startListening();
        }
      }
    });
  }

  Future<void> _sendToWhisper(String path) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("[STT] API 키가 비어 있습니다.");
      _isProcessing = false;
      return;
    }

    if (!File(path).existsSync()) {
      debugPrint("[STT] 파일이 존재하지 않습니다: $path");
      _isProcessing = false;
      return;
    }

    final uri = Uri.parse("https://api.openai.com/v1/audio/transcriptions");
    final request = http.MultipartRequest("POST", uri)
      ..headers["Authorization"] = "Bearer $apiKey"
      ..fields["model"] = "whisper-1"
      ..fields["language"] = "ko"
      ..files.add(await http.MultipartFile.fromPath("file", path));

    debugPrint("[STT] Whisper 요청 시작...");
    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final text =
          RegExp(r'"text":\s*"([^"]*)"').firstMatch(body)?.group(1)?.trim() ?? "";

      String clean = text
          .replaceAll(RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣa-zA-Z0-9\s.,!?]'), '')
          .trim();

      // 이전 TTS 발화 텍스트 제거
      final ttsText = ttsService?.lastSpokenText?.trim();
      if (ttsText != null &&
          ttsText.isNotEmpty &&
          clean.contains(ttsText)) {
        debugPrint("[STT] Whisper 결과에 이전 TTS 문장 포함됨 → 제거 처리");
        clean = clean.replaceAll(ttsText, '').trim();
      }

      if (clean.isEmpty) {
        debugPrint("[STT] 비어있는 텍스트 (TTS 제거 후) → 무시");
        _isProcessing = false;
        return;
      }

      // 오인식 필터
      if (clean.contains("뉴스") ||
          clean.contains("이덕영") ||
          clean.contains("구독") ||
          clean.contains("수고") ||
          clean.contains("시청")) {
        debugPrint("[STT] 오인식된 문장 감지, 무시: $clean");
        _isProcessing = false;
        return;
      }

      if (clean != _lastText) {
        _lastText = clean;
        debugPrint("[STT 결과] $clean");
        onResult?.call(clean);
      } else {
        debugPrint("[STT] 중복 결과 무시");
      }
    } else {
      debugPrint("[STT 오류] ${response.statusCode}: $body");
    }

    _isProcessing = false;
  }

  Future<void> stopListening({bool tempStop = false}) async {
    if (!_isRecording) return;
    _isRecording = false;
    _silenceTimer?.cancel();

    try {
      await _recorder.stop();
      debugPrint("[STT] 녹음 중지");
    } catch (e) {
      debugPrint("[STT 중지 오류] $e");
    }

    if (!tempStop) {
      _isStopped = true;
      debugPrint("[STT] 완전 종료됨");
    }
  }

  Future<void> dispose() async {
    debugPrint("[STT] 완전 종료 시도");
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _isStopped = true;
    _isRecording = false;
    _isProcessing = false;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      await _recorder.dispose();
    } catch (e) {
      debugPrint("[STT dispose 오류] $e");
    }

    debugPrint("[STT] 세션 완전 종료됨");
  }
}
