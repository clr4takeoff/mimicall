import 'package:flutter/material.dart';
import '../models/character_settings_model.dart';
import 'package:image_picker/image_picker.dart';

class CharacterSettingsDialog extends StatefulWidget {
  const CharacterSettingsDialog({super.key});

  @override
  State<CharacterSettingsDialog> createState() =>
      _CharacterSettingsDialogState();
}

class _CharacterSettingsDialogState extends State<CharacterSettingsDialog> {
  CharacterSettings settings = CharacterSettings(
    imagePath: '기본 캐릭터',
    voicePath: '기본 음성',
    contextText: '없음',
  );

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
    return AlertDialog(
      backgroundColor: const Color(0xFFFFF7E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '캐릭터 설정',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF5D4037), // 텍스트 컬러 통일
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 캐릭터 이미지 변경
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFFFF8A80)), // 코랄핑크
              title: const Text('캐릭터 이미지 변경'),
              subtitle: Text(
                '현재: ${settings.imagePath ?? "없음"}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              onTap: _pickCharacterImage,
            ),
            const Divider(thickness: 0.8),

            // 캐릭터 음성 설정
            ListTile(
              leading: const Icon(Icons.record_voice_over, color: Color(0xFF4FC3F7)), // 하늘색
              title: const Text('캐릭터 음성 설정'),
              subtitle: Text(
                '현재: ${settings.voicePath ?? "없음"}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              onTap: () {
                // TODO: 음성 설정 로직 연결
              },
            ),
            const Divider(thickness: 0.8),

            // 대화 주제 / 상황 설정
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF91b32e)), // 연한 초록색 (메인화면 버튼 색과 맞춤)
              title: const Text('대화 주제 / 상황 설정'),
              subtitle: Text(
                '현재: ${settings.contextText ?? "없음"}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              onTap: () async {
                final result = await _showContextInputDialog(context);
                if (result != null && result.isNotEmpty) {
                  setState(() {
                    settings = settings.copyWith(contextText: result);
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text(
            '닫기',
            style: TextStyle(color: Color(0xFF5D4037)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, settings);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB74D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '저장',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// ✏️ 대화 주제 입력용 다이얼로그
  Future<String?> _showContextInputDialog(BuildContext context) async {
    final controller = TextEditingController(text: settings.contextText ?? '');

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '대화 주제 / 상황 입력',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '예: 오늘 기분 이야기하기, 친구와의 약속 등',
              hintStyle: const TextStyle(color: Colors.black38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                '취소',
                style: TextStyle(color: Color(0xFF5D4037)),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB74D),
              ),
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}
