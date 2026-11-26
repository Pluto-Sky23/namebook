import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../state.dart';
import '../models.dart';
import '../photo_store.dart';
import '../widgets/head_bar.dart';

class PeoplePage extends StatefulWidget {
  final AppState state;
  final VoidCallback onOpenSettings;
  final void Function(Person p) onOpenDetail;
  final VoidCallback onAdd;
  final VoidCallback onRoll;
  final VoidCallback onSort;
  final TextEditingController searchCtrl;
  final GlobalKey headKey;
  const PeoplePage({
    super.key,
    required this.state,
    required this.onOpenSettings,
    required this.onOpenDetail,
    required this.onAdd,
    required this.onRoll,
    required this.onSort,
    required this.searchCtrl,
    required this.headKey,
  });

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final st = widget.state;
        final list = st.filtered;
        return Stack(
          children: [
            Column(
              children: [
                HeadBar(
                  headKey: widget.headKey,
                  searchCtrl: widget.searchCtrl,
                  onSettings: widget.onOpenSettings,
                  onRoll: widget.onRoll,
                  onSort: widget.onSort,
                  dice: st.dice,
                  diceTurns: st.diceTurns,
                  sortActive: st.sortField != 'time' || st.sortAsc,
                  count: list.length,
                  onSearchChanged: (v) => st.setSearch(v),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    children: [
                      _chips(st),
                      const SizedBox(height: 12),
                      ...List.generate(list.length, (i) => _card(list[i], i)),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Text('没有符合条件的人',
                                style: TextStyle(color: T.ink3, fontSize: 13)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 24,
              child: _fab(),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: on ? Colors.white : T.ink2,
                  fontWeight: on ? FontWeight.w500 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _chips(AppState st) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...st.tags.map((t) {
          final on = st.selectedTags.contains(t.id);
          return _chip(t.name, on, () {
            HapticFeedback.selectionClick();
            st.toggleTag(t.id);
          });
        }),
        if (st.selectedTags.isNotEmpty)
          _chip('清除 ×', false, () {
            widget.searchCtrl.clear();
            st.clearFilter();
          }),
      ],
    );
  }

  Widget _card(Person p, int i) {
    final colors = T.palette(p.palette);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.dur,
      curve: Motion.curve,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 14),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onOpenDetail(p);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: T.surface,
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(18),
            boxShadow: T.shadow2,
          ),
          child: Row(
            children: [
              _avatar(p, colors),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: p.tagIds
                          .where((id) => widget.state.tags.any((t) => t.id == id))
                          .map((id) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: T.surface2,
                                  border: Border.all(color: T.line),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(widget.state.tagName(id),
                                    style: const TextStyle(fontSize: 11, color: T.ink2)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: T.ink3, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(Person p, List<Color> colors) {
    final hasPhoto = p.photos.isNotEmpty;
    return Container(
      width: 62,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: hasPhoto
            ? null
            : LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.18), spreadRadius: -1),
          ...T.shadow1,
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasPhoto)
            Positioned.fill(
              child: Image.file(
                File(PhotoStore.file(p.photos.first).path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(p.initial,
                      style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700)),
                ),
              ),
            )
          else
            Text(p.initial,
                style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700)),
          if (hasPhoto)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x9E101910),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('${p.photos.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fab() {
    return GestureDetector(
      onTap: widget.onAdd,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: T.tealGradient,
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(color: T.teal.withOpacity(0.42), blurRadius: 26, offset: const Offset(0, 12)),
            BoxShadow(color: Colors.white.withOpacity(0.2), spreadRadius: -2),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
