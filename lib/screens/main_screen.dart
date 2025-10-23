import 'package:flutter/material.dart';
import 'incoming_call_screen.dart';
import 'report_list_screen.dart';
import '../widgets/character_settings.dart';

class MainScreen extends StatelessWidget {
  final String? userName;

  const MainScreen({Key? key, this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        title: Text(
          '안녕, ${userName ?? "친구"}!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 상단 우측에 설정 버튼 추가 (부모용)
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            tooltip: '캐릭터 설정',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CharacterSettingsDialog(),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎥 영상 통화 시작
            _buildMenuButton(
              context,
              color: Colors.pinkAccent,
              icon: Icons.videocam_rounded,
              label: '영상 통화 시작하기',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncomingCallScreen(userName: userName),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 📋 지난 통화 리포트 보기
            _buildMenuButton(
              context,
              color: Colors.amber,
              icon: Icons.list_alt_rounded,
              label: '지난 통화 리포트 보기',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportListScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, {
        required Color color,
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
