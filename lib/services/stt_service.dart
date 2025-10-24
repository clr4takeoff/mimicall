import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class STTService {
  final String callId;
  final Record _recorder = Record();
  bool _isRecording = false;
  bool _isStopped = false;
  Timer? _silenceTimer;

  String? _lastText; // 중복 방지용
  bool _isProcessing = false; // Whisper 요청 중 여부

  Function(String text)? onResult;

  STTService({required this.callId});

  /// 초기화 및 권한 확인
  Future<void> initialize() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint("[STT] 마이크 권한이 없습니다.");
      return;
    }
    debugPrint("[STT] 초기화 완료");
  }

  /// 음성 녹음 시작
  Future<void> startListening() async {
    if (_isRecording || _isStopped) return;
    _isStopped = false;
    _isRecording = true;

    final tempDir = Directory.systemTemp.path;
    final filePath = "$tempDir/temp_${DateTime.now().millisecondsSinceEpoch}.m4a";

    debugPrint("[STT] 녹음 시작: $filePath");

    await _recorder.start(
      path: filePath,
      encoder: AudioEncoder.aacLc,
      bitRate: 96000, // 낮은 비트레이트로 비용 절감
      samplingRate: 16000, // Whisper에 충분한 품질 (16kHz)
      numChannels: 1,
    );

    _startSilenceDetection(filePath);
  }

  /// 무음 감지 로직
  void _startSilenceDetection(String path) {
    debugPrint("[STT] 무음 감지 시작");
    const silenceThreshold = -50.0; // 더 완화된 기준 (기존 -40)
    const silenceDuration = Duration(seconds: 2);
    const checkInterval = Duration(milliseconds: 400);

    Duration silentFor = Duration.zero;
    _silenceTimer?.cancel();

    _silenceTimer = Timer.periodic(checkInterval, (_) async {
      if (_isStopped || _isProcessing) return;

      final amp = await _recorder.getAmplitude();
      final currentDb = amp.current ?? -120;

      // debugPrint("[STT] 현재 dB: $currentDb");

      if (currentDb < silenceThreshold) {
        silentFor += checkInterval;
      } else {
        silentFor = Duration.zero;
      }

      // 연속 무음 지속 시간 초과 시
      if (silentFor >= silenceDuration) {
        _silenceTimer?.cancel();
        debugPrint("[STT] 무음 감지됨 → 녹음 중지 및 Whisper 요청");

        await stopListening(tempStop: true);

        // 파일 길이 검증 후 전송
        final file = File(path);
        if (await file.exists()) {
          final length = await file.length();
          if (length > 20000) { // 약 0.3초 이상
            await _sendToWhisper(path);
          } else {
            debugPrint("[STT] 파일이 너무 짧아 무시됨 (${length} bytes)");
          }
        }

        if (!_isStopped) {
          debugPrint("[STT] 다음 입력 대기 중...");
          await Future.delayed(const Duration(milliseconds: 800));
          await startListening();
        }
      }
    });
  }


  /// Whisper API 호출
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
      ..fields["language"] = "ko" // 한국어 고정
      ..files.add(await http.MultipartFile.fromPath("file", path));

    debugPrint("[STT] Whisper 요청 시작...");
    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final text =
          RegExp(r'"text":\s*"([^"]*)"').firstMatch(body)?.group(1)?.trim() ?? "";

      // 한글, 영문, 숫자, 기본 문장부호만 남김
      final clean = text.replaceAll(RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣa-zA-Z0-9\s.,!?]'), '').trim();

      if (clean.isNotEmpty && clean != _lastText) {
        _lastText = clean;
        debugPrint("[STT 결과] $clean");
        onResult?.call(clean);
      } else {
        debugPrint("[STT] 중복 혹은 비어있는 결과 무시");
      }
    } else {
      debugPrint("[STT 오류] ${response.statusCode}: $body");
    }

    _isProcessing = false;
  }

  /// 녹음 중지 (완전 중지 또는 일시정지)
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