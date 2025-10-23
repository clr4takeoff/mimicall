import 'package:flutter/material.dart';
import '../widgets/character_settings.dart';

class AppHeader extends StatelessWidget {
  final String? userName;
  final String? title;
  final bool showSettings;
  final bool showBackButton;
  final VoidCallback? onSettingsTap;

  const AppHeader({
    super.key,
    this.userName,
    this.title,
    this.showSettings = false,
    this.showBackButton = false,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF3E0), // 부드러운 크림색
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      width: double.infinity,
      child: _buildHeaderContent(context),
    );
  }

  Widget _buildHeaderContent(BuildContext context) {
    // 메인 인삿말 모드
    if (userName != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안녕, $userName!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '여기 어떤 것을 넣으면 좋을까...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8D6E63),
                ),
              ),
            ],
          ),
          if (showSettings)
            IconButton(
              icon: const Icon(
                Icons.settings_rounded,
                color: Color(0xFFFFB74D), // 포인트 주황
                size: 30,
              ),
              onPressed: onSettingsTap ??
                      () {
                    showDialog(
                      context: context,
                      builder: (_) => const CharacterSettingsDialog(),
                    );
                  },
            ),
        ],
      );
    }

    // 나머지 일반 헤더
    return Row(
      children: [
        if (showBackButton)
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF5D4037),
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        Expanded(
          child: Text(
            title ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}
