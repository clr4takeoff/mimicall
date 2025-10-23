// lib/models/character_settings_model.dart

class CharacterSettings {
  final String imagePath;        // 캐릭터 이미지 경로
  final String voicePath;        // 음성 설정
  final String contextText;      // 대화 주제 또는 보호자 입력 문장
  final String speakingStyle;    // 말하기 스타일 (encouraging, questioning, reflective)
  final int targetSpeechCount;   // 목표 발화 횟수
  final int focusTime;           // 목표 집중 시간 (분)

  const CharacterSettings({
    required this.imagePath,
    required this.voicePath,
    required this.contextText,
    this.speakingStyle = "encouraging",
    this.targetSpeechCount = 5,
    this.focusTime = 5,
  });

  CharacterSettings copyWith({
    String? imagePath,
    String? voicePath,
    String? contextText,
    String? speakingStyle,
    int? targetSpeechCount,
    int? focusTime,
  }) {
    return CharacterSettings(
      imagePath: imagePath ?? this.imagePath,
      voicePath: voicePath ?? this.voicePath,
      contextText: contextText ?? this.contextText,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      targetSpeechCount: targetSpeechCount ?? this.targetSpeechCount,
      focusTime: focusTime ?? this.focusTime,
    );
  }

  Map<String, dynamic> toJson() => {
    "imagePath": imagePath,
    "voicePath": voicePath,
    "contextText": contextText,
    "speakingStyle": speakingStyle,
    "targetSpeechCount": targetSpeechCount,
    "focusTime": focusTime,
  };

  factory CharacterSettings.fromJson(Map<String, dynamic> json) {
    return CharacterSettings(
      imagePath: json["imagePath"] ?? '',
      voicePath: json["voicePath"] ?? '',
      contextText: json["contextText"] ?? '',
      speakingStyle: json["speakingStyle"] ?? 'encouraging',
      targetSpeechCount: json["targetSpeechCount"] ?? 5,
      focusTime: json["focusTime"] ?? 5,
    );
  }
}
