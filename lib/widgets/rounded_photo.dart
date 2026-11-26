import 'dart:io';
import 'package:flutter/material.dart';
import '../photo_store.dart';

/// 按图片真实宽高比显示并裁圆角。
/// 解决固定比例 + BoxFit.contain 时留白导致圆角不贴图片的问题。
class RoundedPhoto extends StatefulWidget {
  final String fileName;
  final double radius;
  final Widget placeholder;
  const RoundedPhoto({
    super.key,
    required this.fileName,
    required this.radius,
    required this.placeholder,
  });

  @override
  State<RoundedPhoto> createState() => _RoundedPhotoState();
}

class _RoundedPhotoState extends State<RoundedPhoto> {
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RoundedPhoto old) {
    super.didUpdateWidget(old);
    if (old.fileName != widget.fileName) {
      _aspect = null;
      _load();
    }
  }

  void _load() {
    final provider = FileImage(File(PhotoStore.file(widget.fileName).path));
    final stream = provider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, _) {
      if (!mounted) return;
      final a = info.image.width / info.image.height;
      if (a > 0) setState(() => _aspect = a);
    }, onError: (_, __) {}));
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect;
    return AspectRatio(
      // 真实比例未读出前用默认竖版比例占位，避免首帧尺寸跳变
      aspectRatio: aspect ?? 474 / 609,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: aspect == null
            ? widget.placeholder
            : Image.file(
                File(PhotoStore.file(widget.fileName).path),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => widget.placeholder,
              ),
      ),
    );
  }
}
