import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

class TTSService {
  final _player = AudioPlayer();

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('[TTS] API 키 없음');
        return;
      }

      debugPrint('[TTS] 요청 시작...');
      final url = Uri.parse('https://api.openai.com/v1/audio/speech');

      final body = jsonEncode({
        'model': 'gpt-4o-mini-tts',
        'voice': 'shimmer', // 밝고 어린 톤
        'input': text,
        'format': 'mp3',
        'speed': 1.4,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(response.bodyBytes);

        debugPrint('[TTS] 재생 시작: ${file.path}');
        await _player.setFilePath(file.path);
        await _player.play();

        // 재생 완료까지 기다리기
        await _player.processingStateStream.firstWhere(
              (state) => state == ProcessingState.completed,
        );
      } else {
        debugPrint('[TTS 오류] ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[TTS 예외] $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[TTS stop 오류] $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
