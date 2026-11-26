import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'dice_face.dart';

/// 画师页顶部栏：标题 + 搜索 + 骰子。主页面与详情页浮动层共用同一组件，
/// 保证位置、骰子样式、动效、颜色完全一致。
class HeadBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final VoidCallback onSettings;
  final VoidCallback onRoll;
  final VoidCallback onSort;
  final int dice;
  final int diceTurns;
  final bool sortActive;
  /// 当前筛选结果数量，显示在「画师」标题右侧
  final int count;
  final GlobalKey? headKey;
  final ValueChanged<String>? onSearchChanged;

  const HeadBar({
    super.key,
    required this.searchCtrl,
    required this.onSettings,
    required this.onRoll,
    required this.onSort,
    required this.dice,
    required this.diceTurns,
    required this.sortActive,
    required this.count,
    this.headKey,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: headKey,
      color: T.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _titleRow(),
          _searchRow(),
        ],
      ),
    );
  }

  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('画师',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
              const SizedBox(width: 9),
              Text('$count 位',
                  style: const TextStyle(fontSize: 15, color: T.teal, fontWeight: FontWeight.w700)),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onSettings();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: T.surface,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(14),
                boxShadow: T.shadow1,
              ),
              child: const Icon(Icons.settings_outlined, size: 20, color: T.ink2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: _SearchBox(
              controller: searchCtrl,
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSort();
            },
            child: AnimatedContainer(
              duration: Motion.durFast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sortActive ? T.tealSoft : T.surface,
                border: Border.all(color: sortActive ? T.teal : T.line),
                borderRadius: BorderRadius.circular(14),
                boxShadow: T.shadow1,
              ),
              child: Icon(Icons.swap_vert, size: 21, color: sortActive ? T.teal : T.ink2),
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: onRoll,
            child: AnimatedContainer(
              duration: Motion.durFast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: T.surface,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(14),
                boxShadow: T.shadow1,
              ),
              child: AnimatedRotation(
                turns: diceTurns.toDouble(),
                duration: const Duration(milliseconds: 500),
                curve: Motion.curve,
                child: Center(child: DiceFace(value: dice, size: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索框：聚焦时青绿描边 + 柔和光晕，未聚焦时淡投影（对应预览 .search）。
class _SearchBox extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _SearchBox({required this.controller, this.onChanged});

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.dur,
      curve: Motion.curve,
      height: 47,
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: _focused ? T.tealB : T.line),
        borderRadius: BorderRadius.circular(15),
        boxShadow: _focused
            ? const [BoxShadow(color: T.tealSoft, spreadRadius: 3)]
            : T.shadow1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: _focused ? T.teal : T.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              decoration: const InputDecoration(
                hintText: '搜索姓名或标签',
                hintStyle: TextStyle(color: T.ink3, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15, color: T.ink),
            ),
          ),
        ],
      ),
    );
  }
}
