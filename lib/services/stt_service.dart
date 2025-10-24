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
      bitRate: 96000,
      samplingRate: 16000,
      numChannels: 1,
    );

    _startSilenceDetection(filePath);
  }

  /// 무음 감지 로직
  void _startSilenceDetection(String path) {
    debugPrint("[STT] 무음 감지 시작");
    const silenceThreshold = -50.0; // 무음 판단 기준
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

      // 최고/최저 dB 추적
      if (currentDb > maxDbDuringRecording) maxDbDuringRecording = currentDb;
      if (currentDb < minDbDuringRecording) minDbDuringRecording = currentDb;

      // 무음 카운트
      if (currentDb < silenceThreshold) {
        silentFor += checkInterval;
      } else {
        silentFor = Duration.zero;
      }

      // 무음 지속 시 발화 종료로 간주
      if (silentFor >= silenceDuration) {
        _silenceTimer?.cancel();
        debugPrint("[STT] 무음 감지됨 → 녹음 중지 및 Whisper 요청");
        await stopListening(tempStop: true);

        final file = File(path);
        if (await file.exists()) {
          final length = await file.length();
          final dynamicRange = maxDbDuringRecording - minDbDuringRecording;

          // 발화 유효성 판단
          if (length > 8000 && dynamicRange > 6) {
            debugPrint("[STT] 유효한 발화 감지 → Whisper 전송 "
                "(len: $length, range: ${dynamicRange.toStringAsFixed(1)} dB)");
            await _sendToWhisper(path);
          } else {
            debugPrint("[STT] 무음/잡음으로 판단 → Whisper 생략 "
                "(len: $length, range: ${dynamicRange.toStringAsFixed(1)} dB)");
          }
        }

        // 초기화
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
      ..fields["language"] = "ko"
      ..files.add(await http.MultipartFile.fromPath("file", path));

    debugPrint("[STT] Whisper 요청 시작...");
    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final text =
          RegExp(r'"text":\s*"([^"]*)"').firstMatch(body)?.group(1)?.trim() ?? "";

      final clean = text
          .replaceAll(RegExp(r'[^가-힣ㄱ-ㅎㅏ-ㅣa-zA-Z0-9\s.,!?]'), '')
          .trim();

      // 짧은 발화도 허용하지만 노이즈 방지 필터 적용
      if (clean.isEmpty) {
        debugPrint("[STT] 비어있는 텍스트 무시");
        _isProcessing = false;
        return;
      }

      // 노이즈 패턴 필터
      if (clean.contains("뉴스") || clean.contains("이덕영") || clean.contains("구독")) {
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
