import 'package:flutter/material.dart';
import '../utils/user_info.dart';
import '../widgets/app_header.dart';

class TrafficLightGuideScreen extends StatelessWidget {
  const TrafficLightGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. UserInfo에서 이름 가져오기 (없으면 '아이'로 기본값 설정)
    final userName = UserInfo.name ?? "아이";

    // 2. 한글 받침 확인 로직 (조사 처리를 위해)
    final lastChar = userName.characters.last;
    final codeUnit = lastChar.codeUnitAt(0);
    // 한글 유니코드 범위 내에 있고, (코드 - 0xAC00) % 28 != 0 이면 받침 있음
    final hasBatchim = (codeUnit >= 0xAC00 && codeUnit <= 0xD7A3)
        ? (codeUnit - 0xAC00) % 28 != 0
        : false;

    // 받침 있으면 '이와', 없으면 '와' (예: 서영이와 / 우주와)
    final particleWa = hasBatchim ? "이와" : "와";

    return Scaffold(
      backgroundColor: Colors.transparent, // 배경을 투명하게 설정 (Container 그라데이션을 위해)
      body: Container(
        // ReportListScreen과 동일한 배경 그라데이션 적용
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF7E9),
              Color(0xFFFFF3DC),
              Color(0xFFF7D59C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 기존 AppBar 대신 커스텀 AppHeader 사용
              const AppHeader(title: "신호등 가이드 🚥", showBackButton: true),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$userName$particleWa의 대화,\n신호등 순서를 기억하세요!",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                          color: Color(0xFF5D4037), // 텍스트 색상을 배경과 어울리는 짙은 갈색톤으로 미세 조정
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "아이의 자발적인 발화를 돕기 위해, \nMilieu teaching에 근거한 3단계 전략을 사용합니다.",
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                      const SizedBox(height: 30),

                      // Level 1. Red Card
                      _buildGuideCard(
                        context,
                        level: "Level 1",
                        title: "Prompt (발화 유도)",
                        meaning: "아이를 멈추고 촉진한다",
                        color: const Color(0xFFFF5252), // Red Accent
                        icon: Icons.back_hand, // 멈춤 제스처 아이콘
                        when: "Delay 후에도 발화가 없을 때",
                        description: "발화를 위한 구체적인 질문 또는 환경을 조성합니다.",
                        // 예시 텍스트에 이름 적용
                        example: "엄마에게 뭐라고 말해야 물을 받을 수 있을까?\n$userName의 생각을 더 들려줄 수 있어?",
                      ),

                      const SizedBox(height: 20),

                      // Level 2. Yellow Card
                      _buildGuideCard(
                        context,
                        level: "Level 2",
                        title: "Delay (대기)",
                        meaning: "스스로 말하도록 기다린다",
                        color: const Color(0xFFE0BA21), // Amber Accent
                        icon: Icons.hourglass_bottom, // 기다림 아이콘
                        when: "아동의 행동 포착 직후",
                        description: "3~5초 간 대화 없이 아동의 자발적인 발화 시도(말, 제스처, 시선 등)를 기다립니다.",
                        example: "(3~5초간 아이와 눈을 맞추며 기다려주세요)",
                      ),

                      const SizedBox(height: 20),

                      // Level 3. Green Card
                      _buildGuideCard(
                        context,
                        level: "Level 3",
                        title: "Reinforce (강화)",
                        meaning: "성공을 칭찬하고 확장한다",
                        color: const Color(0xFF2AB646), // Green Accent
                        icon: Icons.thumb_up, // 칭찬 아이콘
                        when: "아동의 성공 발화 직후",
                        description: "아동의 성공적인 발화나 행동을 칭찬하고, 감정 표현을 확장하도록 유도합니다.",
                        // 예시 텍스트에 이름 적용
                        example: "우와, 우리 $userName ‘물 주세요’라고 정확하게 말했네! 참 잘했어!\n우리 $userName도 물을 같이 마셔볼까? 어때? 시원하지?",
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard(
      BuildContext context, {
        required String level,
        required String title,
        required String meaning,
        required Color color,
        required IconData icon,
        required String when,
        required String description,
        required String example,
        bool isItalicExample = false,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 (색상 배경)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level,
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          // 내용 본문
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 의미
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      meaning,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                // 시점 (When)
                _buildInfoRow("시점", when),
                const SizedBox(height: 12),

                // 지침 (Description)
                _buildInfoRow("지침", description),
                const SizedBox(height: 20),

                // 예시 박스
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text("예시",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        example,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontStyle: isItalicExample ? FontStyle.italic : FontStyle.normal,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}