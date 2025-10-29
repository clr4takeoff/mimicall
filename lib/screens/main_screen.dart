import 'package:flutter/material.dart';
import 'incoming_call_screen.dart';
import 'report_list_screen.dart';
import '../utils/user_info.dart';
import '../widgets/menu_button.dart';
import '../widgets/app_header.dart';

class MainScreen extends StatelessWidget {
  final String? userName;

  const MainScreen({Key? key, this.userName}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final displayName = userName ?? UserInfo.name ?? "친구";
    UserInfo.name = displayName;

    return Scaffold(
      // Scaffold의 색은 투명하게 두고
      backgroundColor: Colors.transparent,
      body: Container(
        // 배경: 아이보리 계열 그라데이션
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF7E9),
              Color(0xFFFFF3DC),
              Color(0xFFf7d59c),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // 이 부분 중요: Material을 한 번 감싸줘야 Ink, 버튼 색이 제대로 보임
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeader(userName: displayName, showSettings: true),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MenuButton(
                          color: const Color(0xFFFF7043),
                          icon: Icons.videocam_rounded,
                          label: '영상 통화 시작하기',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    IncomingCallScreen(userName: userName),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        MenuButton(
                          color: const Color(0xFF91b32e),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
