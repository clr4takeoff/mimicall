import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_database/firebase_database.dart';

class GPTResponse {
  final _chatUrl = Uri.parse("https://api.openai.com/v1/chat/completions");
  final _imageUrl = Uri.parse("https://api.openai.com/v1/images/generations");

  final List<Map<String, String>> _conversationHistory = [];

  void initializeCharacterContext({
    required String context,
    required String style,
    int targetSpeechCount = 5,
  }) {
    String toneDescription;
    switch (style) {
      case "questioning":
        toneDescription = "짧고 호기심 많은 질문 위주로 이야기해줘.";
        break;
      case "reflective":
        toneDescription = "아이의 말을 공감하며 되짚어 주는 반응형 말투로 이야기해줘.";
        break;
      default:
        toneDescription = "따뜻하고 칭찬해주는 말투로 이야기해줘.";
        break;
    }

    final systemPrompt = """
너는 3세~7세 아동의 언어 발달을 돕는 AI 친구야.
대화 상황: $context
스타일: $toneDescription
목표 발화 횟수: $targetSpeechCount회
아이의 말은 스스로 이어가게 유도하고, 대답은 1문장 이하로 간단하게.
""";

    _conversationHistory.clear();
    _conversationHistory.add({"role": "system", "content": systemPrompt});
  }

  Future<String> sendMessageToLLM(String userMessage) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint("API 키가 비어 있습니다.");
      return "";
    }

    _conversationHistory.add({"role": "user", "content": userMessage});

    try {
      final response = await http.post(
        _chatUrl,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": _conversationHistory,
          "temperature": 0.7,
          "max_tokens": 200,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("LLM 오류: ${response.body}");
        return "";
      }

      final data = jsonDecode(response.body);
      final reply = data["choices"][0]["message"]["content"] as String;

      _conversationHistory.add({"role": "assistant", "content": reply});
      debugPrint("LLM 응답: $reply");

      return reply;
    } catch (e) {
      debugPrint("LLM 호출 오류: $e");
      return "";
    }
  }

  Future<String> generateAndSaveImageBase64({
    required String prompt,
    required String dbPath,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    debugPrint("OpenAI API Key length: ${apiKey.length}");
    if (apiKey.isEmpty) {
      debugPrint("API 키에 문제 있음.");
      return "";
    }

    final safePath = dbPath
        .replaceAll('.', '-')
        .replaceAll('#', '-')
        .replaceAll('\$', '-')
        .replaceAll('[', '-')
        .replaceAll(']', '-');

    final ref = FirebaseDatabase.instance.ref(safePath);

    debugPrint("OpenAI 이미지 요청 시작 (경로: $safePath)");

    final response = await http.post(
      _imageUrl,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "dall-e-3",
        "prompt": prompt,
        "size": "1024x1024",
      }),
    );

    debugPrint("OpenAI 응답 코드: ${response.statusCode}");

    if (response.statusCode != 200) {
      debugPrint("OpenAI 오류: ${response.body}");
      await ref.update({"error": response.body});
      return "";
    }

    final data = jsonDecode(response.body);
    final imageUrl = data['data'][0]['url'];
    debugPrint("이미지 URL 수신: $imageUrl");

    final imageResponse = await http.get(Uri.parse(imageUrl));
    if (imageResponse.statusCode != 200) {
      debugPrint("이미지 다운로드 실패: ${imageResponse.statusCode}");
      await ref.update({"error": "download_failed"});
      return "";
    }

    final bytes = imageResponse.bodyBytes;
    final base64Data = base64Encode(bytes);
    debugPrint("Base64 변환 완료 (길이: ${base64Data.length})");

    await ref.update({
      "prompt": prompt,
      "imageUrl": imageUrl,
      "imageBase64": base64Data,
      "createdAt": DateTime.now().toIso8601String(),
    });

    debugPrint("Firebase 저장 완료 → $safePath");
    return base64Data;
  }
}
