import 'dart:convert';
import 'package:flutter/material.dart';

class ReportImage extends StatelessWidget {
  final String imageUrl;
  final String? imageBase64;
  final double size; // 정사각형이므로 height 대신 size로 통일

  const ReportImage({
    super.key,
    required this.imageUrl,
    this.imageBase64,
    this.size = 220, // 살짝 크게 설정
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty && (imageBase64 == null || imageBase64!.isEmpty)) {
      return const SizedBox.shrink();
    }

    Widget imageWidget;

    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      final bytes = base64Decode(imageBase64!);
      imageWidget = Image.memory(
        bytes,
        fit: BoxFit.cover, // 꽉 채우되 둥근 모서리로 클리핑됨
        width: size,
        height: size,
      );
    } else {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20), // 끝부분 둥글게
      child: Container(
        width: size,
        height: size,
        color: Colors.grey[200], // 이미지 로딩 전 배경
        child: imageWidget,
      ),
    );
  }
}
