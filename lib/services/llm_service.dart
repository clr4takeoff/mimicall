import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_database/firebase_database.dart';

class GPTResponse {
  final _imageUrl = Uri.parse("https://api.openai.com/v1/images/generations");

  Future<String> generateAndSaveImageBase64({
    required String prompt,
    required String dbPath,
  }) async {
    // 1. dotenv에서 런타임에 API 키 읽기
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

    debugPrint("OpenAI API Key length: ${apiKey.length}");
    if (apiKey.isEmpty) {
      debugPrint("API 키가 비어 있습니다. .env 파일을 확인하세요.");
      return "";
    }

    // 2. Firebase 경로 안전하게 변환
    final safePath = dbPath
        .replaceAll('.', '-')
        .replaceAll('#', '-')
        .replaceAll('\$', '-')
        .replaceAll('[', '-')
        .replaceAll(']', '-');

    final ref = FirebaseDatabase.instance.ref(safePath);

    debugPrint("OpenAI 이미지 요청 시작... (경로: $safePath)");

    // 3. DALL·E 3 요청
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

    // 4. 이미지 URL 추출
    final data = jsonDecode(response.body);
    final imageUrl = data['data'][0]['url'];
    debugPrint("이미지 URL 수신: $imageUrl");

    // 5. 이미지 다운로드 및 Base64 변환
    debugPrint("이미지 다운로드 중...");
    final imageResponse = await http.get(Uri.parse(imageUrl));
    if (imageResponse.statusCode != 200) {
      debugPrint("이미지 다운로드 실패: ${imageResponse.statusCode}");
      await ref.update({"error": "download_failed"});
      return "";
    }

    final bytes = imageResponse.bodyBytes;
    final base64Data = base64Encode(bytes);
    debugPrint("Base64 변환 완료 (길이: ${base64Data.length})");

    // 6. Firebase에 저장
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
