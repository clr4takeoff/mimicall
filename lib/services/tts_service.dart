import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';


class TTSService {
  bool _isProcessing = false;
  Function()? onStart;
  Function()? onComplete;
  final AudioPlayer _player = AudioPlayer();

  /// 일반 TTS (OpenAI)
  Future<void> _speakWithOpenAI(String text) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("[TTS] OpenAI API 키가 없습니다.");
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

    final response = await http.post(uri, headers: headers, body: body);
    if (response.statusCode != 200) {
      debugPrint("[TTS 오류] ${response.statusCode}: ${response.body}");
      return;
    }

    final bytes = response.bodyBytes;
    final filePath =
        '${Directory.systemTemp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await _player.setFilePath(file.path);
    onStart?.call();
    await _player.play();
    onComplete?.call();
  }

  /// 클로닝된 ElevenLabs 음성으로 TTS
  Future<void> _speakWithElevenLabs(String text, String voiceId) async {
    final apiKey = dotenv.env['ELEVENLABS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("[TTS] ElevenLabs API 키가 없습니다.");
      return;
    }

    final uri =
    Uri.parse("https://api.elevenlabs.io/v1/text-to-speech/$voiceId");

    final response = await http.post(
      uri,
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "text": text,
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.9},
      }),
    );

    if (response.statusCode != 200) {
      debugPrint("[ElevenLabs 오류] ${response.statusCode}: ${response.body}");
      return;
    }

    final bytes = response.bodyBytes;
    final filePath =
        '${Directory.systemTemp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await _player.setFilePath(file.path);
    onStart?.call();
    await _player.play();
    onComplete?.call();
  }

  /// 자동 전환: voiceId가 있으면 ElevenLabs, 없으면 OpenAI
  Future<void> speak(String text, String userName) async {
    if (_isProcessing || text.trim().isEmpty) return;
    _isProcessing = true;

    try {
      final ref = FirebaseDatabase.instance
          .ref("preference/$userName/character_settings/voiceId");
      final snapshot = await ref.get();
      final voiceId = snapshot.value?.toString();

      if (voiceId != null && voiceId.isNotEmpty) {
        debugPrint("[TTS] 클로닝된 음성 사용 ($voiceId)");
        await _speakWithElevenLabs(text, voiceId);
      } else {
        debugPrint("[TTS] 기본 OpenAI 음성 사용");
        await _speakWithOpenAI(text);
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
    await _player.dispose();
  }
}
