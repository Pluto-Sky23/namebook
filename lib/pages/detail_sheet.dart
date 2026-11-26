import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models.dart';
import '../state.dart';
import '../app_launcher.dart';
import '../widgets/photo_sort_sheet.dart';
import '../widgets/rounded_photo.dart';

const double imgRatio = 474 / 609;

class DetailSheet extends StatefulWidget {
  final Person person;
  final AppState state;
  final double topOffset;
  final VoidCallback onClose;
  final void Function(int delta) onSwitch;
  final VoidCallback onEdit;
  final Function(Person) onDelete;
  const DetailSheet({
    super.key,
    required this.person,
    required this.state,
    required this.topOffset,
    required this.onClose,
    required this.onSwitch,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<DetailSheet>
    with SingleTickerProviderStateMixin {
  late final PageController _ctrl;
  late final AnimationController _enter;
  late final AnimationController _switchAnim;
  bool _copied = false;
  double _dragY = 0;
  int _switchDir = 1;
  /// 图片排序后的本地顺序覆盖；person 变化时清空，回退到 person.photos
  List<String>? _orderOverride;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.6, initialPage: 0);
    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _switchAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    // 首次进入不做切换动画，保持完全不透明
    _switchAnim.value = 1;
    _enter.forward();
  }

  /// 上下滑只用于判定方向，不再让整个页面（尤其图片轮播）跟着手指平移。
  /// 换人时用一次轻微的淡入 + 小幅位移收尾，避免图片上下跳动。
  void _requestSwitch(int dir) {
    _switchDir = dir;
    widget.onSwitch(dir);
    _switchAnim.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant DetailSheet old) {
    super.didUpdateWidget(old);
    // 换人、或编辑画师导致图片增删时，都要清掉本地排序覆盖，
    // 否则 _orderOverride 会指向已被移除的图片文件。
    if (old.person.id != widget.person.id ||
        !_samePhotos(old.person.photos, widget.person.photos)) {
      _copied = false;
      _orderOverride = null;
      if (_ctrl.hasClients) _ctrl.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _enter.dispose();
    _switchAnim.dispose();
    super.dispose();
  }

  static bool _samePhotos(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<String> get photos => _orderOverride ?? widget.person.photos;

  /// 长按图片进入排序面板，保存后写库并本地刷新到新顺序
  Future<void> _openSort() async {
    if (photos.length < 2) return;
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoSortSheet(photos: photos),
    );
    if (result == null || !mounted) return;
    setState(() => _orderOverride = result);
    await widget.state.reorderPhotos(widget.person.id, result);
    if (_ctrl.hasClients) _ctrl.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = T.palette(widget.person.palette);
    return Positioned.fill(
      top: widget.topOffset,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (d) {
          // 仅累积位移用于判定方向，不驱动页面平移（图片保持静止）
          setState(() {
            _dragY = (_dragY + d.delta.dy).clamp(-240.0, 240.0);
          });
        },
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (_dragY < -56 || (v < -420 && _dragY < -14)) {
            _requestSwitch(1);
          } else if (_dragY > 56 || (v > 420 && _dragY > 14)) {
            _requestSwitch(-1);
          }
          _dragY = 0;
        },
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _switchAnim]),
        builder: (context, _) {
          final enterE = Curves.easeOut.transform(_enter.value).clamp(0.0, 1.0);
          final se = Curves.easeOut.transform(_switchAnim.value).clamp(0.0, 1.0);
          // 换人：淡入 + 14px 轻微滑入，方向跟手，幅度很小不牵动图片跳动
          final switchFade = 0.6 + 0.4 * se;
          final switchY = (1 - se) * 10 * _switchDir;
          // 背景层始终实心不透明、固定不动：淡入/位移只作用于内部内容。
          // 这样切换时不会把整个详情页变透明而透出下层主页（闪现标签页）。
          return Container(
            color: T.bg,
            child: ClipRect(
              child: Opacity(
                opacity: switchFade,
                child: Transform.translate(
                  offset: Offset(0, (1 - enterE) * 8 + switchY),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                    child: Column(
                      children: [
                        _hero(colors),
                        const SizedBox(height: 18),
                        _stagger(0, Text(widget.person.name,
                            style: const TextStyle(
                                fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.6))),
                        const SizedBox(height: 10),
                        _stagger(1, _tags()),
                        const SizedBox(height: 18),
                        _stagger(2, _actions()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          },
        ),
      ),
    );
  }

  Widget _stagger(int order, Widget child) {
    final delay = 0.04 * order;
    final p = ((_enter.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    final e = Curves.easeOut.transform(p);
    return Opacity(
      opacity: e,
      child: Transform.translate(offset: Offset(0, (1 - e) * 14), child: child),
    );
  }

  Widget _hero(List<Color> colors) {
    final count = photos.isEmpty ? 1 : photos.length;
    return Container(
      height: 322,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const RadialGradient(
          colors: [Color(0xFFE9F2ED), Color(0xFFDFEAE4)],
          center: Alignment.topCenter,
          radius: 1.1,
        ),
        boxShadow: [
          ...T.shadow2,
          BoxShadow(color: Colors.white.withOpacity(0.6), spreadRadius: -2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: PageView.builder(
        controller: _ctrl,
        itemCount: count,
        itemBuilder: (context, i) {
          final hasPhoto = photos.isNotEmpty;
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              double dist = 0;
              if (_ctrl.hasClients) {
                final page = _ctrl.page ?? i.toDouble();
                dist = (page - i).abs();
              }
              final scale = 1 - (dist.clamp(0.0, 1.0)) * 0.14;
              final opacity = 1 - (dist.clamp(0.0, 1.0)) * 0.55;
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Center(
                    child: GestureDetector(
                      onLongPress: hasPhoto ? _openSort : null,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x38103026),
                              blurRadius: 26,
                              offset: Offset(0, 10),
                            )
                          ],
                        ),
                        child: hasPhoto
                            ? RoundedPhoto(
                                fileName: photos[i],
                                radius: 16,
                                placeholder: _placeholder(colors),
                              )
                            : AspectRatio(
                                aspectRatio: imgRatio,
                                child: _placeholder(colors),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeholder(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Text(widget.person.initial,
            style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _tags() {
    final names = widget.person.tagIds
        .where((id) => widget.state.tags.any((t) => t.id == id))
        .map((id) => widget.state.tagName(id))
        .toList();
    if (names.isEmpty) {
      return const Text('暂无标签', style: TextStyle(fontSize: 12, color: T.ink3));
    }
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: names
          .map((n) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: T.surface2,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(n, style: const TextStyle(fontSize: 11, color: T.ink2)),
              ))
          .toList(),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          flex: 14,
          child: AnimatedContainer(
            duration: Motion.durFast,
            curve: Motion.spring,
            decoration: BoxDecoration(
              gradient: _copied ? null : T.tealGradient,
              color: _copied ? T.tealB : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: T.teal.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                BoxShadow(color: Colors.white.withOpacity(0.2), spreadRadius: -2),
              ],
            ),
            child: SizedBox(
              height: 47,
              child: ElevatedButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 17),
                label: Text(_copied ? '已复制' : '复制姓名'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 10,
          child: SizedBox(
            height: 47,
            child: OutlinedButton(
              onPressed: widget.onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: T.ink,
                side: const BorderSide(color: T.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('编辑'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 10,
          child: SizedBox(
            height: 47,
            child: OutlinedButton(
              onPressed: () => widget.onDelete(widget.person),
              style: OutlinedButton.styleFrom(
                foregroundColor: T.danger,
                side: const BorderSide(color: T.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('删除'),
            ),
          ),
        ),
      ],
    );
  }

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.person.name));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
    // 复制后自动拉起 Breeze，并尝试把姓名作为文本分享给它
    await AppLauncher.launchBreezeWithName(widget.person.name);
  }
}
