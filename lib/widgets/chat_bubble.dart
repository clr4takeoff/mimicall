import 'package:flutter/material.dart';

class TopBubble extends StatelessWidget {
  final String text;
  final bool isFairyMode;

  const TopBubble({
    super.key,
    required this.text,
    this.isFairyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LeftTailBubblePainter(isFairyMode: isFairyMode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            // 요정 모드일 때 글자색 & 폰트 강조
            color: isFairyMode ? const Color(0xFF6A1B9A) : Colors.black87,
            fontFamily: isFairyMode ? 'ComicNeue' : null,
          ),
        ),
      ),
    );
  }
}

class LeftTailBubblePainter extends CustomPainter {
  final bool isFairyMode;

  LeftTailBubblePainter({this.isFairyMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 12.0;
    const tailWidth = 30.0;
    const tailHeight = 22.0;
    final tailX = size.width * 0.8;

    // 내부 배경색
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 요정 모드일 때만 테두리 색 변경
    final border = Paint()
      ..color = isFairyMode
          ? const Color(0xFFB39DDB) // 요정모드: 보라색 테두리
          : Colors.black26 // 기본: 연회색 테두리
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();

    // 좌상단 → 우상단
    path.moveTo(radius, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);

    // 우하단
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - radius * 0.7,
      size.height - 2,
    );

    // 좌측 꼬리 부분
    path.lineTo(tailX + tailWidth * 0.8, size.height - 2);
    path.quadraticBezierTo(
      tailX - tailWidth * 0.1,
      size.height + tailHeight * 0.9,
      tailX - tailWidth * 0.5,
      size.height + tailHeight,
    );
    path.quadraticBezierTo(
      tailX + tailWidth * 0.0,
      size.height + tailHeight * 0.5,
      tailX,
      size.height - 2,
    );

    // 좌하단
    path.lineTo(radius, size.height - 2);
    path.quadraticBezierTo(0, size.height - 2, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    // 그림자 + 채우기 + 테두리
    canvas.drawShadow(path, Colors.black26, 3, false);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
