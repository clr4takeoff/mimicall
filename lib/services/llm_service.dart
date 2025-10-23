import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_database/firebase_database.dart';

class GPTResponse {
  final _chatUrl = Uri.parse("https://api.openai.com/v1/chat/completions"); // ✅ 추가
  final _imageUrl = Uri.parse("https://api.openai.com/v1/images/generations");

  // 이미지 생성
  Future<String> generateAndSaveImageBase64({
    required String prompt,
    required String dbPath,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    debugPrint("OpenAI API Key length: ${apiKey.length}");
    if (apiKey.isEmpty) {
      debugPrint("API 키가 비어 있습니다. .env 파일을 확인하세요.");
      return "";
    }

    final safePath = dbPath
        .replaceAll('.', '-')
        .replaceAll('#', '-')
        .replaceAll('\$', '-')
        .replaceAll('[', '-')
        .replaceAll(']', '-');

    final ref = FirebaseDatabase.instance.ref(safePath);

    debugPrint("OpenAI 이미지 요청 시작... (경로: $safePath)");

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

  // 텍스트 대화 (LLM 호출)
  Future<String> sendMessageToLLM(
      String userMessage, {
        String? context,
      }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint("API 키가 비어 있습니다. .env 파일을 확인하세요.");
      return "";
    }

    final prompt = StringBuffer();
    if (context != null && context.isNotEmpty) {
      prompt.writeln("Conversation context: $context\n");
    }
    prompt.writeln("User: $userMessage");

    try {
      final response = await http.post(
        _chatUrl,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini", // 💡 gpt-4o-mini로 변경 추천
          "messages": [
            {"role": "system", "content": prompt.toString()},
          ],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("LLM 응답 오류: ${response.body}");
        return "";
      }

      final data = jsonDecode(response.body);
      final text = data["choices"][0]["message"]["content"];
      debugPrint("LLM 응답: $text");
      return text;
    } catch (e) {
      debugPrint("LLM 호출 중 오류: $e");
      return "";
    }
  }
}
