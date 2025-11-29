import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'tts_service.dart';

class STTService {
  final String callId;
  final Record _recorder = Record();
  final TTSService? ttsService;
  bool _isRecording = false;
  bool _isProcessing = false;

  String? _lastText;
  Function(String text)? onResult;
  Function()? onSpeechDetected;

  STTService({required this.callId, this.ttsService});

  Future<void> initialize() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint("[STT] 마이크 권한이 없습니다.");
      return;
    }
    debugPrint("[STT] 초기화 완료");
  }

  // 버튼 누르면 호출됨
  Future<void> startListening() async {
    if (_isRecording) return;
    _isRecording = true;

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

    // 녹음 중일 때 음성 감지 콜백
    onSpeechDetected?.call();
  }

  // 다시 버튼 누르면 호출됨 → Whisper 전송
  Future<void> stopListening({bool tempStop = false}) async {
    if (!_isRecording) return;
    _isRecording = false;

    String? path;
    try {
      path = await _recorder.stop();
      debugPrint("[STT] 녹음 중지: $path");
    } catch (e) {
      debugPrint("[STT 중지 오류] $e");
      return;
    }

    if (path == null || !File(path).existsSync()) {
      debugPrint("[STT] 녹음 파일이 없습니다 — Whisper 전송 생략");
      return;
    }

    await _sendToWhisper(path);
  }

  // Whisper API 호출
  Future<void> _sendToWhisper(String path) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("[STT] API 키가 비어 있습니다.");
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

      // 🔊 이전 TTS 문장 제거
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
      // if (clean.contains("뉴스") ||
      //     clean.contains("이덕영") ||
      //     clean.contains("구독") ||
      //     clean.contains("수고") ||
      //     clean.contains("영상") ||
      //     clean.contains("REMAX") ||
      //     clean.contains("자막러") ||
      //     clean.contains("시청")) {
      //   debugPrint("[STT] 오인식된 문장 감지, 무시: $clean");
      //   _isProcessing = false;
      //   return;
      // }

      if (clean != _lastText) {
        _lastText = clean;
        debugPrint("[STT 결과] $clean");
        onResult?.call(clean);
      } else {
        debugPrint("[STT] 중복 결과 무시");
        onResult?.call(clean); // TODO: avd 테스트용, 이후 제거 요망
      }
    } else {
      debugPrint("[STT 오류] ${response.statusCode}: $body");
    }

    _isProcessing = false;
  }

  Future<void> dispose() async {
    debugPrint("[STT] 세션 종료 중...");
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
