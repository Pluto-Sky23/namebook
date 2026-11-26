import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../state.dart';
import '../models.dart';
import '../photo_store.dart';

class AddSheet extends StatefulWidget {
  final AppState state;
  final Future<void> Function(String name, List<int> tags, List<String> photos) onSave;
  final Person? editing;
  const AddSheet({super.key, required this.state, required this.onSave, this.editing});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  late final TextEditingController _name;
  final _newTag = TextEditingController();
  final Set<int> _selected = {};
  final List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    final p = widget.editing;
    _name = TextEditingController(text: p?.name ?? '');
    if (p != null) {
      _selected.addAll(p.tagIds);
      _photos.addAll(p.photos);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _newTag.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final name = await PhotoStore.pickAndSave();
    if (name != null) setState(() => _photos.add(name));
  }

  Future<void> _createTag() async {
    final n = _newTag.text.trim();
    if (n.isEmpty) return;
    if (widget.state.isDuplicateTag(n) && !await _confirmDuplicateTag(n)) return;
    await widget.state.addTag(n);
    final added = widget.state.tags.where((t) => t.name == n).firstOrNull;
    if (added != null) setState(() => _selected.add(added.id));
    _newTag.clear();
  }

  Future<bool> _confirmDuplicateTag(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('标签可能重复'),
        content: Text('已有「$name」或名称相近的标签（已忽略大小写、全角半角与空格差异）。\n\n仍要创建吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: T.teal),
            child: const Text('继续创建'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          color: T.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 26),
        child: SingleChildScrollView(
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
                  Text(widget.editing == null ? '添加画师' : '编辑画师',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 30, height: 30,
                        decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.close, size: 16, color: T.ink2)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: TextField(
                  controller: _name,
                  style: const TextStyle(fontSize: 17, color: T.ink),
                  decoration: InputDecoration(
                    hintText: '姓名',
                    hintStyle: const TextStyle(color: T.ink3),
                    filled: true, fillColor: T.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: T.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: T.line)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('照片（可多张）', style: TextStyle(fontSize: 12, color: T.ink2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, crossAxisSpacing: 9, mainAxisSpacing: 9, childAspectRatio: 474 / 609),
                itemCount: _photos.length + 1,
                itemBuilder: (context, i) {
                  if (i == _photos.length) {
                    return GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        decoration: BoxDecoration(
                          color: T.surface,
                          border: Border.all(color: T.line, style: BorderStyle.solid, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 22, color: T.ink3),
                            SizedBox(height: 3),
                            Text('添加', style: TextStyle(fontSize: 10, color: T.ink3)),
                          ],
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(File(PhotoStore.file(_photos[i]).path), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('标签（可多选，可现场新建）', style: TextStyle(fontSize: 12, color: T.ink2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.state.tags.map((t) {
                  final on = _selected.contains(t.id);
                  return GestureDetector(
                    onTap: () => setState(() => on ? _selected.remove(t.id) : _selected.add(t.id)),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: on ? T.teal : T.surface,
                        gradient: on ? T.tealGradient : null,
                        border: Border.all(color: on ? Colors.transparent : T.line),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: T.shadow1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.name,
                              style: TextStyle(fontSize: 13, color: on ? Colors.white : T.ink2)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _newTag,
                        style: const TextStyle(fontSize: 14, color: T.ink),
                        decoration: InputDecoration(
                          hintText: '新标签名称',
                          filled: true, fillColor: T.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: T.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: T.line)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64, height: 40,
                    child: TextButton(
                      onPressed: _createTag,
                      style: TextButton.styleFrom(backgroundColor: T.tealSoft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                      child: const Text('创建', style: TextStyle(color: T.teal, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                height: 47,
                decoration: BoxDecoration(
                  gradient: T.tealGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: T.teal.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    BoxShadow(color: Colors.white.withOpacity(0.2), spreadRadius: -2),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    if (_name.text.trim().isEmpty) return;
                    await widget.onSave(_name.text.trim(), _selected.toList(), List<String>.from(_photos));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
