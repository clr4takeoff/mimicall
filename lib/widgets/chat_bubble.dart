import 'package:flutter/material.dart';
import 'dart:math';

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
    final screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;

    // 화면 너비에 따른 스케일 비율 계산
    final double scaleFactor = min(screenWidth / 360.0, 1.8);

    // 비율에 맞춰 폰트 크기 및 여백 설정
    final double fontSize = 12.0 * scaleFactor;
    final double paddingH = 25.0 * scaleFactor;
    final double paddingV = 12.0 * scaleFactor;

    return CustomPaint(
      painter: LeftTailBubblePainter(
        isFairyMode: isFairyMode,
        scale: scaleFactor,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        constraints: BoxConstraints(maxWidth: screenWidth * 0.85), // 화면의 85%까지 허용
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.4,
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
  final double scale;

  LeftTailBubblePainter({
    this.isFairyMode = false,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 비율을 적용하여 수치 계산
    final radius = 12.0 * scale;
    final tailWidth = 30.0 * scale;
    final tailHeight = 22.0 * scale;
    final tailX = size.width * 0.8;

    // 배경색 설정
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 테두리 설정
    final border = Paint()
      ..color = isFairyMode
          ? const Color(0xFFB39DDB)
          : Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;

    final path = Path();

    // 말풍선 본체 그리기
    path.moveTo(radius, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);

    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - radius * 0.7,
      size.height - (2 * scale),
    );

    // 꼬리 부분 그리기
    path.lineTo(tailX + tailWidth * 0.8, size.height - (2 * scale));
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
      size.height - (2 * scale),
    );

    path.lineTo(radius, size.height - (2 * scale));
    path.quadraticBezierTo(0, size.height - (2 * scale), 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    // 그림자, 채우기, 테두리 그리기
    canvas.drawShadow(path, Colors.black26, 3 * scale, false);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}