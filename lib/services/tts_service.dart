import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';

class TTSService {
  bool _isProcessing = false;
  Function()? onStart;
  Function()? onComplete;
  final AudioPlayer _player = AudioPlayer();

  Future<void> speak(String text) async {
    if (_isProcessing || text.trim().isEmpty) return;
    _isProcessing = true;

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint("[TTS] OpenAI API 키가 없습니다.");
        _isProcessing = false;
        return;
      }

      final uri = Uri.parse("https://api.openai.com/v1/audio/speech");
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };
      final body = '''
      {
        "model": "gpt-4o-mini-tts",
        "voice": "alloy",
        "input": "${text.replaceAll('"', '\\"')}"
      }
      ''';

      debugPrint("[TTS] OpenAI 요청 중...");
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final filePath =
            '${Directory.systemTemp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        debugPrint("[TTS] 음성 파일 생성 완료: $filePath");

        await _player.setFilePath(file.path);

        onStart?.call();
        debugPrint("[TTS] 재생 시작");

        // 재생 완료 감지 (정확한 타이밍)
        StreamSubscription<PlayerState>? subscription;
        subscription = _player.playerStateStream.listen((state) async {
          if (state.processingState == ProcessingState.completed) {
            debugPrint("[TTS] 재생 완료 감지됨");
            await _player.stop();
            await subscription?.cancel();
            onComplete?.call();
          }
        });

        await _player.play();
      } else {
        debugPrint("[TTS 오류] ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      debugPrint("[TTS 예외] $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isProcessing = false;
  }

  Future<void> dispose() async {
    try {
      await _player.stop();
      await _player.dispose();
      debugPrint("[TTS] 세션 완전 종료됨");
    } catch (e) {
      debugPrint("[TTS dispose 오류] $e");
    }
  }

}
