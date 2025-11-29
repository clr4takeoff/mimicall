import 'package:flutter/material.dart';

class HiddenTouchLayer extends StatelessWidget {
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;
  final double height;
  final double topPadding;

  const HiddenTouchLayer({
    super.key,
    required this.onLeftTap,
    required this.onRightTap,
    this.height = 150.0,
    this.topPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      height: height,
      child: Row(
        children: [
          // 왼쪽 영역
          Expanded(
            child: GestureDetector(
              onTap: onLeftTap,
              behavior: HitTestBehavior.translucent, // 투명해도 터치 인식
              child: Container(
                color: Colors.transparent, // 시각적으로는 보이지 않음
                // 영역 확인하려면 아래 주석 해제하면 됨
                // color: Colors.red.withOpacity(0.3),
              ),
            ),
          ),
          // 오른쪽 영역
          Expanded(
            child: GestureDetector(
              onTap: onRightTap,
              behavior: HitTestBehavior.translucent, // 투명해도 터치 인식
              child: Container(
                color: Colors.transparent,
                // 영역 확인하려면 아래 주석 해제하면 됨
                // color: Colors.blue.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}