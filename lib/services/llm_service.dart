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
    required String characterName,
    required String context,
    required String style,
    String? contextText,
    int targetSpeechCount = 5,
  }) {

    final systemPrompt = """
      너는 3세~7세 아동의 언어 발달을 돕는 '$characterName'이라는 이름의 AI 캐릭터야.
      현재 캐릭터의 상황: ${contextText ?? "특별한 상황 설명 없음"}.
      대화의 맥락: $context
      목표는 아이가 자연스럽게 발화하도록 유도하는 거야.
      - 대답은 한 문장 이내로 간단하게
      - 무조건 반말 사용하기
      - 따뜻하고 친근하게 말하기
      - 아이가 말을 따라 하거나 대답하도록 유도해줘.
      """;

    _conversationHistory.clear();
    _conversationHistory.add({"role": "system", "content": systemPrompt});

    debugPrint("[GPT] 캐릭터 초기화 완료\n$systemPrompt");
  }


  Future<String> sendMessageToLLM(String userMessage, {String? stageInstruction}) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) return "";

    // 단계 전환 시 systemPrompt 교체 + 로그 출력
    if (stageInstruction != null) {
      debugPrint("[GPT] 단계 지침 수신 → $stageInstruction");

      _conversationHistory.removeWhere((m) => m["role"] == "system");
      final newSystemPrompt = """
        너는 3세~7세 아동의 언어 발달을 돕는 AI 친구야.
        이전 단계의 대화는 끝났고, 지금은 새로운 단계야.
        현재 대화 단계: $stageInstruction
        - 아이가 자발적으로 말하도록 유도하고
        - 따뜻하고 간결하게 말해줘.
        - 무조건 반말 사용하기
        """;

      _conversationHistory.insert(0, {"role": "system", "content": newSystemPrompt});
      debugPrint("[GPT] 새로운 systemPrompt 설정 완료:\n$newSystemPrompt");
    }

    _conversationHistory.add({"role": "user", "content": userMessage});
    debugPrint("[GPT] 유저 입력: $userMessage");

    final response = await http.post(
      _chatUrl,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": _conversationHistory,
        "temperature": 0.6,
        "max_tokens": 150,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint("[GPT 오류] ${response.body}");
      return "";
    }

    final data = jsonDecode(response.body);
    final reply = data["choices"][0]["message"]["content"] as String;

    _conversationHistory.add({"role": "assistant", "content": reply});

    debugPrint("[GPT 응답] $reply");
    return reply;
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

  Future<String> fetchPromptResponse(String systemPrompt, String userPrompt) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint("[GPT] API 키가 없습니다.");
      return "";
    }

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
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userPrompt},
          ],
          "temperature": 0.7,
          "max_tokens": 400,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("[GPT 오류] ${response.body}");
        return "";
      }

      final data = jsonDecode(response.body);
      final content = data["choices"][0]["message"]["content"] as String;
      debugPrint("[GPT 리포트 응답] $content");

      return content;
    } catch (e) {
      debugPrint("[GPT 예외] $e");
      return "";
    }
  }

  /// 요정모드 종료 후 캐릭터 대화 컨텍스트 초기화
  void resetCharacterContext() {
    debugPrint("[GPT] 캐릭터 컨텍스트 초기화 (요정 모드 종료)");
    _conversationHistory.clear(); // GPT 대화 기록만 초기화
  }


}
