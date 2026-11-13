import 'package:flutter/material.dart';

import '../core/theme.dart';

class ProductImage extends StatefulWidget {
  final String url;
  final bool darkPlaceholder;
  const ProductImage({
    super.key,
    required this.url,
    this.darkPlaceholder = false,
  });

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
    final url = widget.url.trim();
    if (url.startsWith('data:image/')) {
      try {
        final data = UriData.fromUri(Uri.parse(url));
        final bytes = data.contentAsBytes();
        if (bytes.isNotEmpty && bytes.length <= 8 * 1024 * 1024) {
          _image = MemoryImage(bytes);
        }
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
        child: ColoredBox(
          color: widget.darkPlaceholder ? Colors.transparent : AppTheme.lightBg,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: widget.darkPlaceholder ? 30 : 44,
              color: widget.darkPlaceholder
                  ? Colors.white54
                  : AppColors.textSecondary,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_image == null) return _placeholder();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil()
                .clamp(1, 1600)
            : 720;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal:
                constraints.maxWidth.isFinite ? constraints.maxWidth * .08 : 0,
            vertical: constraints.maxHeight.isFinite
                ? constraints.maxHeight * .08
                : 0,
          ),
          child: Image(
            image: ResizeImage.resizeIfNeeded(width, null, _image!),
            fit: BoxFit.contain,
            frameBuilder: (_, child, frame, sync) =>
                frame != null || sync ? child : _placeholder(loading: true),
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        );
      },
    );
  }
}
