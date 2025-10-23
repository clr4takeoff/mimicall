import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_database/firebase_database.dart';

class GPTResponse {
  final url = Uri.parse("https://api.openai.com/v1/chat/completions");
  final dbRef = FirebaseDatabase.instance.ref("gpt_responses");

  /// GPT 코멘트 응답 가져오기 + Firebase에 저장
  Future<String> fetchGPTCommentResponse(String content) async {
    final apiKey = dotenv.env['OPENAI_API_KEY']; // .env에서 불러오기
    if (apiKey == null || apiKey.isEmpty) {
      return "API key not found in .env file";
    }

    const systemRole = '''
너는 바나나랑 사과중 뭐가 더 좋은지 대답해라
''';

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': systemRole},
            {'role': 'user', 'content': content},
          ],
          'temperature': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final text = data['choices'][0]['message']['content'].trim();

        // Firebase에 저장
        await dbRef.push().set({
          'prompt': content,
          'response': text,
          'timestamp': DateTime.now().toIso8601String(),
        });

        return text;
      } else {
        return "오류 발생: ${response.statusCode} ${response.body}";
      }
    } catch (e) {
      return 'Exception: $e';
    }
  }

  /// 프롬프트 기반 GPT 응답 (SharedPreferences는 그대로 유지 가능)
  Future<String> fetchPromptResponse(String systemRole, String prompt) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return "API key not found";
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': systemRole},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final result = data['choices'][0]['message']['content'].trim();
        return result;
      } else {
        return "Failed to load data from OpenAI";
      }
    } catch (e) {
      return 'Exception: $e';
    }
  }
}