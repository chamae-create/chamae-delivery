import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class ProductImage extends StatelessWidget {
  final String url;
  const ProductImage({super.key, required this.url});

  Widget get placeholder => const ColoredBox(
        color: AppTheme.lightBg,
        child: Center(
            child: Icon(Icons.local_drink_outlined,
                size: 44, color: AppColors.textSecondary)),
      );

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(url.split(',').last),
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
      } catch (_) {
        return placeholder;
      }
    }
    if (Uri.tryParse(url)?.hasScheme != true) return placeholder;
    return Image.network(url,
        fit: BoxFit.contain,
        frameBuilder: (_, child, frame, sync) =>
            frame != null || sync ? child : placeholder,
        errorBuilder: (_, __, ___) => placeholder);
  }
}
