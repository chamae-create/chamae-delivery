import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class ProductImage extends StatefulWidget {
  final String url;
  const ProductImage({super.key, required this.url});

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    _image = null;
    final url = widget.url;
    if (url.startsWith('data:image')) {
      try {
        _image = MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        // A malformed image must not take the catalog down.
      }
    } else if (['http', 'https'].contains(Uri.tryParse(url)?.scheme)) {
      _image = NetworkImage(url);
    }
  }

  Widget _placeholder({bool loading = false}) => Semantics(
      label: loading
          ? 'Carregando imagem do produto'
          : 'Imagem do produto indisponível',
      child: const ColoredBox(
        color: AppTheme.lightBg,
        child: Center(
            child: Icon(Icons.image_outlined,
                size: 44, color: AppColors.textSecondary)),
      ));

  @override
  Widget build(BuildContext context) {
    if (_image == null) return _placeholder();
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth
          ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
              .ceil()
              .clamp(1, 1600)
          : 720;
      return Image(
          image: ResizeImage.resizeIfNeeded(width, null, _image!),
          fit: BoxFit.contain,
          frameBuilder: (_, child, frame, sync) =>
              frame != null || sync ? child : _placeholder(loading: true),
          errorBuilder: (_, __, ___) => _placeholder());
    });
  }
}
