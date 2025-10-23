import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_database/firebase_database.dart';

class GPTResponse {
  final _chatUrl = Uri.parse("https://api.openai.com/v1/chat/completions");
  final _imageUrl = Uri.parse("https://api.openai.com/v1/images/generations");

  // 이미지 생성 및 Firebase 저장
  Future<String> generateAndSaveImageBase64({
    required String prompt,
    required String dbPath,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    debugPrint("OpenAI API Key length: ${apiKey.length}");
    if (apiKey.isEmpty) {
      debugPrint("API 키에 문제있음.");
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

  // 캐릭터 설정을 반영한 텍스트 대화
  Future<String> sendMessageToLLM(
      String userMessage, {
        String? context,          // 대화 주제
        String? style,            // 대화 스타일 (encouraging, questioning, reflective)
        int? targetSpeechCount,   // 목표 발화 횟수 (필요시 참고)
      }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint("API 키가 비어 있습니다. .env 파일을 확인하세요.");
      return "";
    }

    // 스타일별 말투 설명
    String toneDescription;
    switch (style) {
      case "questioning":
        toneDescription = "짧고 호기심 많은 질문 위주로 이야기해줘.";
        break;
      case "reflective":
        toneDescription = "아이의 말을 공감하며 되짚어 주는 반응형 말투로 이야기해줘.";
        break;
      case "encouraging":
      default:
        toneDescription = "따뜻하고 칭찬해주는 말투로 이야기해줘.";
        break;
    }

    // LLM 프롬프트 구성
    final prompt = """
      너는 3세~7세 아동의 언어 발달을 돕는 AI 캐릭터 친구야.
      너는 ${context ?? "자유로운 일상 대화"} 상황을 겪고 있으며, 이때 대답으로 적절한 2-3단어를 아동이 말하게 해야해.
      절대로 먼저 정답을 말하지 말고, 아이가 스스로 말을 이어갈 수 있도록 친절하고 자연스럽게 반응해줘.
      말은 무조건 1문장으로 간결하게, 쉽고 따뜻하게 해줘.
      
      대화 스타일: $toneDescription
      아이 목표 발화 횟수: ${targetSpeechCount ?? 5}회 중 한 회차라고 생각해줘.
      
      아이가 말한 내용:
      "$userMessage"
      
      이 아이의 말에 맞춰 자연스럽고 짧게 다음 말을 이어주고, 아이가 적절한 대답을 하면 칭찬을 하며 영웅으로 만들어줘.
      """;

    try {
      final response = await http.post(
        _chatUrl,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": "너는 아동 언어치료를 돕는 AI 캐릭터야."},
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.7,
          "max_tokens": 200,
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
