import 'dart:convert';

class CharacterSettings {
  final String? imageBase64;
  final String voicePath;
  final String contextText;
  final String targetSpeech;
  final String speakingStyle;
  final int targetSpeechCount;
  final int focusTime;

  const CharacterSettings({
    this.imageBase64,
    this.voicePath = '기본 음성',
    this.contextText = '없음',
    this.targetSpeech = '',
    this.speakingStyle = 'encouraging',
    this.targetSpeechCount = 1,
    this.focusTime = 10,
  });

  static const _sentinel = Object();

  CharacterSettings copyWith({
    Object? imageBase64 = _sentinel, // 👈 Object로 받아서 null도 허용하고, 미지정도 구분
    String? voicePath,
    String? contextText,
    String? targetSpeech,
    String? speakingStyle,
    int? targetSpeechCount,
    int? focusTime,
  }) {
    return CharacterSettings(
      imageBase64: identical(imageBase64, _sentinel)
          ? this.imageBase64
          : imageBase64 as String?, // 👈 null이면 진짜 null로 들어감
      voicePath: voicePath ?? this.voicePath,
      contextText: contextText ?? this.contextText,
      targetSpeech: targetSpeech ?? this.targetSpeech,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      targetSpeechCount: targetSpeechCount ?? this.targetSpeechCount,
      focusTime: focusTime ?? this.focusTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'imageBase64': imageBase64,
    'voicePath': voicePath,
    'contextText': contextText,
    'targetSpeech': targetSpeech,
    'speakingStyle': speakingStyle,
    'targetSpeechCount': targetSpeechCount,
    'focusTime': focusTime,
  };

  factory CharacterSettings.fromJson(Map<String, dynamic> json) {
    return CharacterSettings(
      imageBase64: json['imageBase64'],
      voicePath: json['voicePath'] ?? '',
      contextText: json['contextText'] ?? '',
      targetSpeech: json['targetSpeech'] ?? '',
      speakingStyle: json['speakingStyle'] ?? 'encouraging',
      targetSpeechCount: json['targetSpeechCount'] ?? 5,
      focusTime: json['focusTime'] ?? 10,
    );
  }
}
