import 'package:flutter/material.dart';
import '../models/character_settings_model.dart';
import 'package:image_picker/image_picker.dart';
import '../services/character_settings_service.dart';

class CharacterSettingsDialog extends StatefulWidget {
  final String childName;

  const CharacterSettingsDialog({
    super.key,
    required this.childName,
  });

  @override
  State<CharacterSettingsDialog> createState() =>
      _CharacterSettingsDialogState();
}

class _CharacterSettingsDialogState extends State<CharacterSettingsDialog> {
  final CharacterSettingsService _settingsService = CharacterSettingsService();

  bool _isLoading = true;

  CharacterSettings settings = const CharacterSettings(
    imagePath: '기본 캐릭터',
    voicePath: '기본 음성',
    contextText: '없음',
    targetSpeech: '',
  );

  @override
  void initState() {
    super.initState();
    _loadCharacterSettings();
  }

  Future<void> _loadCharacterSettings() async {
    try {
      final savedSettings =
      await _settingsService.loadCharacterSettings(widget.childName);
      if (savedSettings != null) {
        setState(() {
          settings = savedSettings;
        });
      }
    } catch (e) {
      debugPrint('설정 불러오기 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCharacterImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        settings = settings.copyWith(imagePath: image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB74D)),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFFFFF7E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '캐릭터 설정',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF5D4037),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 캐릭터 이미지 변경
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFFFF8A80)),
              title: const Text('캐릭터 이미지 변경'),
              subtitle: Text(
                '현재: ${settings.imagePath}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              onTap: _pickCharacterImage,
            ),
            const Divider(thickness: 0.8),

            // 캐릭터 음성 설정
            ListTile(
              leading:
              const Icon(Icons.record_voice_over, color: Color(0xFF4FC3F7)),
              title: const Text('캐릭터 음성 설정'),
              subtitle: Text(
                '현재: ${settings.voicePath}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              onTap: () {
                // TODO: 음성 설정 로직
              },
            ),
            const Divider(thickness: 0.8),

            // 대화 주제 / 상황 + 목표 발화 설정
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF91b32e)),
              title: const Text('대화 상황 / 목표 발화 설정'),
              subtitle: Text(
                '상황: ${settings.contextText}\n목표 발화: ${settings.targetSpeech.isEmpty ? "없음" : settings.targetSpeech}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              onTap: () async {
                final result = await _showContextAndTargetDialog(context);
                if (result != null) {
                  setState(() {
                    settings = settings.copyWith(
                      contextText: result['contextText'] ?? settings.contextText,
                      targetSpeech:
                      result['targetSpeech'] ?? settings.targetSpeech,
                    );
                  });
                }
              },
            ),
            const Divider(thickness: 0.8),

            // 대화 스타일
            ListTile(
              leading: const Icon(Icons.psychology, color: Color(0xFF8E24AA)),
              title: const Text('대화 스타일'),
              subtitle: Text(
                _styleLabel(settings.speakingStyle),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              onTap: () async {
                final result = await _showSpeakingStyleDialog(context);
                if (result != null) {
                  setState(() {
                    settings = settings.copyWith(speakingStyle: result);
                  });
                }
              },
            ),
            const Divider(thickness: 0.8),

            // 목표 발화 횟수
            ListTile(
              leading:
              const Icon(Icons.flag_outlined, color: Color(0xFFFFB74D)),
              title: const Text('목표 발화 횟수'),
              subtitle: Text('${settings.targetSpeechCount}회'),
              onTap: () async {
                final result = await _showNumberInputDialog(
                    context, '목표 발화 횟수', settings.targetSpeechCount);
                if (result != null) {
                  setState(() {
                    settings = settings.copyWith(targetSpeechCount: result);
                  });
                }
              },
            ),
            const Divider(thickness: 0.8),

            // 목표 집중 시간
            ListTile(
              leading:
              const Icon(Icons.timer_outlined, color: Color(0xFF4CAF50)),
              title: const Text('목표 집중 시간 (분)'),
              subtitle: Text('${settings.focusTime}분'),
              onTap: () async {
                final result = await _showNumberInputDialog(
                    context, '집중 시간 (분)', settings.focusTime);
                if (result != null) {
                  setState(() {
                    settings = settings.copyWith(focusTime: result);
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('닫기', style: TextStyle(color: Color(0xFF5D4037))),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await _settingsService.saveCharacterSettings(
                childName: widget.childName,
                settings: settings,
              );

              if (context.mounted) {
                Navigator.pop(context, settings);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('설정이 저장되었습니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB74D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('저장', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

// 상황 + 목표 발화 입력 다이얼로그
  Future<Map<String, String>?> _showContextAndTargetDialog(
      BuildContext context) async {
    final contextController = TextEditingController(text: settings.contextText);
    final targetController = TextEditingController(text: settings.targetSpeech);

    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '상황과 목표 발화 설정',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          contentPadding: EdgeInsets.zero, // (1) 기본 여백 제거
          content: SingleChildScrollView( // (2) 스크롤 허용
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🪄 아이가 연습할 발화 상황',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: contextController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '예: 목말라서 물을 마시고 싶은데 물을 달라고 말하지 못하는 상황',
                    hintStyle: const TextStyle(color: Colors.black38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '🎯 아이가 말하길 원하는 문장',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: targetController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '예: 물 주세요, 물 마실래요',
                    hintStyle: const TextStyle(color: Colors.black38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D)),
              onPressed: () {
                Navigator.pop(context, {
                  'contextText': contextController.text,
                  'targetSpeech': targetController.text,
                });
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }


  // 대화 스타일 선택 다이얼로그
  Future<String?> _showSpeakingStyleDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('대화 스타일 선택'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "encouraging"),
            child: const Text("격려형 (예: 잘했어요!, 좋아요!)"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "questioning"),
            child: const Text("질문형 (예: 그 다음엔 어떻게 됐을까?)"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "reflective"),
            child: const Text("반응형 (예: 음~ 그렇구나!)"),
          ),
        ],
      ),
    );
  }

  // 숫자 입력 다이얼로그
  Future<int?> _showNumberInputDialog(
      BuildContext context, String title, int currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());
    return showDialog<int>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E9),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D)),
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) Navigator.pop(context, value);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  String _styleLabel(String code) {
    switch (code) {
      case "encouraging":
        return "격려형 (따뜻하게 칭찬하며 유도)";
      case "questioning":
        return "질문형 (짧은 질문으로 대화 이어가기)";
      case "reflective":
        return "반응형 (공감하며 되묻기)";
      default:
        return "격려형";
    }
  }
}
