import 'dart:convert';
import 'package:flutter/material.dart';

class ReportImage extends StatelessWidget {
  final String imageUrl;
  final String? imageBase64;
  final double height;

  const ReportImage({
    super.key,
    required this.imageUrl,
    this.imageBase64,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty && (imageBase64 == null || imageBase64!.isEmpty)) {
      return const SizedBox.shrink();
    }

    Widget imageWidget;

    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      final bytes = base64Decode(imageBase64!);
      imageWidget = Image.memory(bytes, fit: BoxFit.cover, height: height, width: double.infinity);
    } else {
      imageWidget = Image.network(imageUrl, fit: BoxFit.cover, height: height, width: double.infinity);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    );
  }
}
