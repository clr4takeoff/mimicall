import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool _isListening = false;
  bool _isStopped = false; // 완전 정지 여부 추가
  String _currentText = '';
  Timer? _silenceTimer;

  final int silenceThreshold;
  final String callId;

  Function(String)? onSpeechResult;

  STTService({
    required this.callId,
    this.silenceThreshold = 3,
  });

  Future<void> initialize() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      print('[STT] 마이크 권한 거부됨');
      return;
    }

    bool available = await _speech.initialize(
      onError: (val) => print('[STT Error]: $val'),
      onStatus: (val) {
        if (val == 'done') _handleSilence();
      },
    );

    if (available) print('[STT] 초기화 완료');
  }

  Future<void> startListening() async {
    if (_isListening || _isStopped) return; // 중단 상태면 시작 안함

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (val) {
          _currentText = val.recognizedWords;
          if (onSpeechResult != null) onSpeechResult!(_currentText);
          _resetSilenceTimer();
        },
        listenMode: stt.ListenMode.dictation,
        localeId: 'ko_KR',
      );
      print('[STT] 음성 인식 시작됨');
    } catch (e) {
      print('[STT] 시작 실패: $e');
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: silenceThreshold), _handleSilence);
  }

  Future<void> _handleSilence() async {
    if (_isStopped) return; // 완전 정지면 무시

    if (_currentText.isNotEmpty) {
      await _uploadToFirebase(_currentText);
      _currentText = '';
    }

    await _speech.stop();
    _isListening = false;

    // 완전 정지 상태가 아닐 때만 다시 시작
    if (!_isStopped) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!_isStopped) startListening();
      });
    }
  }

  Future<void> _uploadToFirebase(String text) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _db.child('calls/$callId/stt/$timestamp').set({
      'text': text,
      'timestamp': timestamp,
    });
    print('[STT 업로드] $text');
  }

  Future<void> stopListening() async {
    _isStopped = true; // 완전 정지 표시
    _silenceTimer?.cancel();
    await _speech.stop();
    _isListening = false;
    print('[STT] 완전 중지됨');
  }
}

