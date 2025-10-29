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
  bool _isPlaying = false; // 재생 상태 직접 관리
  Function()? onStart;
  Function()? onComplete;
  final AudioPlayer _player = AudioPlayer();

  String? lastSpokenText;
  bool get isPlaying => _isPlaying;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

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

    // 안전한 JSON 직렬화 방식으로 교체
    final body = jsonEncode({
      "model": "gpt-4o-mini-tts",
      "voice": "alloy",
      "input": text,
    });

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
    _isPlaying = true;
    onStart?.call();

    await _player.play();
    await _player.processingStateStream.firstWhere(
          (s) => s == ProcessingState.completed,
    );

    _isPlaying = false;
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
    _isPlaying = true;
    onStart?.call();

    await _player.play();

    _isPlaying = false;
    onComplete?.call();
  }

  Future<void> speak(String text, String userName) async {
    if (_isProcessing || text.trim().isEmpty) return;
    _isProcessing = true;
    _isPlaying = true;
    lastSpokenText = text.trim();

    try {
      final elevenKey = dotenv.env['ELEVEN_API_KEY'];

      if (elevenKey == null || elevenKey.isEmpty) {
        debugPrint("[TTS] .env에 ELEVEN_API_KEY가 없어 OpenAI로 전환");
        await _speakWithOpenAI(text);
        return;
      }

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
      await _speakWithOpenAI(text); // 예외 발생 시 fallback
    } finally {
      _isProcessing = false;
      _isPlaying = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint("[TTS stop 오류] $e");
    } finally {
      _isProcessing = false;
      _isPlaying = false;
      onComplete?.call();
    }
  }


  Future<void> dispose() async {
    await _player.dispose();
  }
}
