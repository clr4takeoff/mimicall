class CharacterSettings {
  final String? imageBase64;
  final String voicePath;
  final String? voiceId;
  final String contextText;
  final String targetSpeech;
  final String speakingStyle;
  final int targetSpeechCount;
  final int focusTime;

  const CharacterSettings({
    this.imageBase64,
    this.voicePath = '기본 음성',
    this.voiceId,
    this.contextText = '',
    this.targetSpeech = '',
    this.speakingStyle = 'encouraging',
    this.targetSpeechCount = 3,
    this.focusTime = 5,
  });

  CharacterSettings copyWith({
    String? imageBase64,
    String? voicePath,
    String? voiceId,
    String? contextText,
    String? targetSpeech,
    String? speakingStyle,
    int? targetSpeechCount,
    int? focusTime,
  }) {
    return CharacterSettings(
      imageBase64: imageBase64 ?? this.imageBase64,
      voicePath: voicePath ?? this.voicePath,
      voiceId: voiceId ?? this.voiceId,
      contextText: contextText ?? this.contextText,
      targetSpeech: targetSpeech ?? this.targetSpeech,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      targetSpeechCount: targetSpeechCount ?? this.targetSpeechCount,
      focusTime: focusTime ?? this.focusTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageBase64': imageBase64,
      'voicePath': voicePath,
      'voiceId': voiceId,
      'contextText': contextText,
      'targetSpeech': targetSpeech,
      'speakingStyle': speakingStyle,
      'targetSpeechCount': targetSpeechCount,
      'focusTime': focusTime,
    };
  }

  factory CharacterSettings.fromJson(Map<String, dynamic> json) {
    return CharacterSettings(
      imageBase64: json['imageBase64'],
      voicePath: json['voicePath'] ?? '기본 음성',
      voiceId: json['voiceId'],
      contextText: json['contextText'] ?? '',
      targetSpeech: json['targetSpeech'] ?? '',
      speakingStyle: json['speakingStyle'] ?? 'encouraging',
      targetSpeechCount: json['targetSpeechCount'] ?? 3,
      focusTime: json['focusTime'] ?? 5,
    );
  }
}
