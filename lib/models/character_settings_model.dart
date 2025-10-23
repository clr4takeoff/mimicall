class CharacterSettings {
  final String? imagePath;     // 캐릭터 이미지 경로
  final String? voicePath;     // 캐릭터 음성 파일 경로
  final String? contextText;   // 대화 주제나 상황 설명

  CharacterSettings({
    this.imagePath,
    this.voicePath,
    this.contextText,
  });

  CharacterSettings copyWith({
    String? imagePath,
    String? voicePath,
    String? contextText,
  }) {
    return CharacterSettings(
      imagePath: imagePath ?? this.imagePath,
      voicePath: voicePath ?? this.voicePath,
      contextText: contextText ?? this.contextText,
    );
  }
}
