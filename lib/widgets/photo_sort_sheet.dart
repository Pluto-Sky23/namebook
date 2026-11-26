import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../photo_store.dart';

/// 图片排序面板：长按拖动调整某位画师的图片顺序，点保存写回。
class PhotoSortSheet extends StatefulWidget {
  final List<String> photos;
  const PhotoSortSheet({super.key, required this.photos});

  @override
  State<PhotoSortSheet> createState() => _PhotoSortSheetState();
}

class _PhotoSortSheetState extends State<PhotoSortSheet> {
  late final List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.photos);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: T.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: T.line, borderRadius: BorderRadius.circular(3))),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('整理图片顺序', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close, size: 16, color: T.ink2)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('长按右侧手柄拖动排序', style: TextStyle(fontSize: 12, color: T.ink3)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                final name = _items[i];
                return Container(
                  key: ValueKey(name),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: T.surface,
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        alignment: Alignment.center,
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: T.ink2, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44, height: 56,
                          child: Image.file(
                            File(PhotoStore.file(name).path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: T.surface2, child: const Icon(Icons.image, color: T.ink3)),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.reorder, size: 20, color: T.ink3),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, List<String>.from(_items));
            },
            child: Container(
              height: 46,
              decoration: BoxDecoration(gradient: T.tealGradient, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: const Text('保存顺序', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
