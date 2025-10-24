class CharacterSettings {
  final String imagePath;
  final String voicePath;
  final String contextText;
  final String targetSpeech; // 추가
  final String speakingStyle;
  final int targetSpeechCount;
  final int focusTime;

  const CharacterSettings({
    required this.imagePath,
    required this.voicePath,
    required this.contextText,
    this.targetSpeech = '',
    this.speakingStyle = 'encouraging',
    this.targetSpeechCount = 3,
    this.focusTime = 5,
  });

  CharacterSettings copyWith({
    String? imagePath,
    String? voicePath,
    String? contextText,
    String? targetSpeech,
    String? speakingStyle,
    int? targetSpeechCount,
    int? focusTime,
  }) {
    return CharacterSettings(
      imagePath: imagePath ?? this.imagePath,
      voicePath: voicePath ?? this.voicePath,
      contextText: contextText ?? this.contextText,
      targetSpeech: targetSpeech ?? this.targetSpeech,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      targetSpeechCount: targetSpeechCount ?? this.targetSpeechCount,
      focusTime: focusTime ?? this.focusTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'voicePath': voicePath,
    'contextText': contextText,
    'targetSpeech': targetSpeech,
    'speakingStyle': speakingStyle,
    'targetSpeechCount': targetSpeechCount,
    'focusTime': focusTime,
  };

  factory CharacterSettings.fromJson(Map<String, dynamic> json) {
    return CharacterSettings(
      imagePath: json['imagePath'] ?? '기본 캐릭터',
      voicePath: json['voicePath'] ?? '기본 음성',
      contextText: json['contextText'] ?? '없음',
      targetSpeech: json['targetSpeech'] ?? '',
      speakingStyle: json['speakingStyle'] ?? 'encouraging',
      targetSpeechCount: json['targetSpeechCount'] ?? 3,
      focusTime: json['focusTime'] ?? 5,
    );
  }
}
