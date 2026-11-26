import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../state.dart';

const _fields = [
  ('time', '时间'),
  ('name', '姓名'),
  ('tags', '标签数量'),
  ('photos', '图片数量'),
];

/// 排序方式底部面板：四字段单选 + 正序/倒序切换，选择即时生效。
class SortSheet extends StatelessWidget {
  final AppState state;
  const SortSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Container(
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
                const Text('排序方式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 30, height: 30,
                      decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.close, size: 16, color: T.ink2)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ..._fields.map((f) => _fieldRow(f.$1, f.$2)),
            const SizedBox(height: 10),
            _directionRow(),
            const SizedBox(height: 22),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.teal, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: const Text('完成', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(String key, String label) {
    final on = state.sortField == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        state.setSort(key, state.sortAsc);
      },
      child: Container(
        height: 50,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: on ? T.teal : T.line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: on ? T.teal : T.ink,
                fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
            const Spacer(),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? T.teal : T.ink3, width: 1.5),
              ),
              child: on ? const Center(child: Icon(Icons.check, size: 13, color: T.teal)) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionRow() {
    return Row(
      children: [
        const Text('顺序', style: TextStyle(fontSize: 13, color: T.ink2)),
        const Spacer(),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            state.toggleSortDirection();
          },
          child: AnimatedContainer(
            duration: Motion.durFast,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: T.tealSoft,
              border: Border.all(color: T.teal),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(state.sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: T.teal),
                const SizedBox(width: 6),
                Text(state.sortAsc ? '正序' : '倒序',
                    style: const TextStyle(fontSize: 14, color: T.teal, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.swap_horiz, size: 14, color: T.teal),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
