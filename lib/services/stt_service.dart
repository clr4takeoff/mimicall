import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool _isListening = false;
  String _currentText = '';
  Timer? _silenceTimer;

  final int silenceThreshold;
  final String callId;

  /// 콜백: 인식된 텍스트를 외부로 전달
  Function(String)? onSpeechResult;

  STTService({
    required this.callId,
    this.silenceThreshold = 3,
  });

  Future<void> initialize() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      print('[STT] 마이크 권한이 거부되었습니다.');
      return;
    }

    bool available = await _speech.initialize(
      onError: (val) => print('[STT Error]: $val'),
      onStatus: (val) {
        if (val == 'done') {
          _handleSilence();
        }
      },
    );

    if (available) {
      print('[STT] 초기화 완료');
    } else {
      print('[STT] 음성 인식 엔진 사용 불가');
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (val) {
          _currentText = val.recognizedWords;
          if (onSpeechResult != null) {
            onSpeechResult!(_currentText);
          }
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
    if (_currentText.isNotEmpty) {
      await _uploadToFirebase(_currentText);
      _currentText = '';
    }
    await _speech.stop();
    _isListening = false;
    Future.delayed(const Duration(seconds: 1), startListening);
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
    _silenceTimer?.cancel();
    await _speech.stop();
    _isListening = false;
    print('[STT] 중지됨');
  }
}
