import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_database/firebase_database.dart';

class TTSService {
  bool _isProcessing = false;
  Function()? onStart;
  Function()? onComplete;
  final AudioPlayer _player = AudioPlayer();

  String? lastSpokenText; // 최근 발화 저장
  bool get isPlaying => _player.playing;

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
    await _player.processingStateStream.firstWhere(
          (s) => s == ProcessingState.completed,
    );
    onComplete?.call();
  }

  Future<void> _speakWithElevenLabs(String text, String voiceId) async {
    final apiKey = dotenv.env['ELEVEN_API_KEY'];
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

  Future<void> speak(String text, String userName) async {
    if (_isProcessing || text.trim().isEmpty) return;
    _isProcessing = true;

    lastSpokenText = text.trim(); // 최근 발화 저장

    try {
      final elevenKey = dotenv.env['ELEVEN_API_KEY'];

      // ① .env에 ElevenLabs 키가 없으면 → 바로 OpenAI로 이동
      if (elevenKey == null || elevenKey.isEmpty) {
        debugPrint("[TTS] .env에 ELEVEN_API_KEY가 없어 OpenAI로 전환");
        await _speakWithOpenAI(text);
        return;
      }

      // ② ElevenLabs 키가 있으면, Firebase에서 voiceId 확인
      final ref = FirebaseDatabase.instance
          .ref("preference/$userName/character_settings/voiceId");
      final snapshot = await ref.get();
      final voiceId = snapshot.value?.toString();

      if (voiceId != null && voiceId.isNotEmpty) {
        debugPrint("[TTS] 클로닝된 음성 사용 ($voiceId)");
        await _speakWithElevenLabs(text, voiceId);
      } else {
        debugPrint("[TTS] voiceId 없음 → 기본 OpenAI 음성 사용");
        await _speakWithOpenAI(text);
      }

    } catch (e) {
      debugPrint("[TTS 예외] $e");
      await _speakWithOpenAI(text); // 안전망 fallback
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
