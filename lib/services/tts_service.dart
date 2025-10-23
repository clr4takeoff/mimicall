import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

class TTSService {
  final _player = AudioPlayer();

  /// 텍스트를 TTS로 변환 후 재생
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('[TTS] ❌ API 키 없음');
        return;
      }

      debugPrint('[TTS] 요청 시작...');
      final url = Uri.parse('https://api.openai.com/v1/audio/speech');

      final body = {
        'model': 'gpt-4o-mini-tts',
        'voice': 'alloy', // voice 선택 가능: alloy, verse 등
        'input': text,
        'format': 'mp3',
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // ✅ 오디오 파일로 저장
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(response.bodyBytes);

        debugPrint('[TTS] 재생 시작: ${file.path}');
        await _player.setFilePath(file.path);
        await _player.play();
      } else {
        debugPrint('[TTS 오류] ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[TTS 예외] $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
