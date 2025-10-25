import 'package:flutter/material.dart';

class TopBubble extends StatelessWidget {
  final String text;
  const TopBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LeftTailBubblePainter(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class LeftTailBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const radius = 12.0;
    const tailWidth = 30.0;
    const tailHeight = 22.0;
    final tailX = size.width * 0.8;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final border = Paint()
      ..color = Colors.black26
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

    // 좌측 방향 꼬리
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

    // 좌하단으로 이어짐
    path.lineTo(radius, size.height - 2);
    path.quadraticBezierTo(0, size.height - 2, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    // 그림자 및 테두리
    canvas.drawShadow(path, Colors.black26, 3, false);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
