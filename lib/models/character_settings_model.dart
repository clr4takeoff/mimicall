class CharacterSettings {
  final String? imageBase64;
  final String voicePath;
  final String characterName;
  final List<String> contextList;
  final List<String> targetList;
  final String speakingStyle;
  final int targetSpeechCount;
  final int focusTime;

  const CharacterSettings({
    this.imageBase64,
    this.voicePath = '기본 음성',
    this.characterName = '',
    this.contextList = const [],
    this.targetList = const [],
    this.speakingStyle = 'encouraging',
    this.targetSpeechCount = 1,
    this.focusTime = 10,
  });

  CharacterSettings copyWith({
    String? imageBase64,
    String? voicePath,
    String? characterName,
    List<String>? contextList,
    List<String>? targetList,
    String? speakingStyle,
    int? targetSpeechCount,
    int? focusTime,
  }) {
    return CharacterSettings(
      imageBase64: imageBase64 ?? this.imageBase64,
      voicePath: voicePath ?? this.voicePath,
      characterName: characterName ?? this.characterName,
      contextList: contextList ?? this.contextList,
      targetList: targetList ?? this.targetList,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      targetSpeechCount: targetSpeechCount ?? this.targetSpeechCount,
      focusTime: focusTime ?? this.focusTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'imageBase64': imageBase64,
    'voicePath': voicePath,
    'characterName': characterName,
    'contextList': contextList,
    'targetList': targetList,
    'speakingStyle': speakingStyle,
    'targetSpeechCount': targetSpeechCount,
    'focusTime': focusTime,
  };

  factory CharacterSettings.fromJson(Map<String, dynamic> json) {
    return CharacterSettings(
      imageBase64: json['imageBase64'],
      voicePath: json['voicePath'] ?? '기본 음성',
      characterName: json['characterName'] ?? '',
      contextList: List<String>.from(json['contextList'] ?? []),
      targetList: List<String>.from(json['targetList'] ?? []),
      speakingStyle: json['speakingStyle'] ?? 'encouraging',
      targetSpeechCount: json['targetSpeechCount'] ?? 1,
      focusTime: json['focusTime'] ?? 10,
    );
  }
}
