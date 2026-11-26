import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../state.dart';

class SettingsPage extends StatelessWidget {
  /// 版本号：每次升级手动改这里即可。
  static const String appVersion = 'v1.7.8';

  final AppState state;
  final VoidCallback onOpenPeople;
  final VoidCallback onNewTag;
  final Future<void> Function() onImportExcel;
  final Future<void> Function(String value) onBackup;
  final Future<void> Function(String value) onRestore;
  final Future<void> Function() onLoadBackupConfig;
  final void Function(String field, String value) onConfigChanged;
  final TextEditingController serverCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController pathCtrl;

  const SettingsPage({
    super.key,
    required this.state,
    required this.onOpenPeople,
    required this.onNewTag,
    required this.onImportExcel,
    required this.onBackup,
    required this.onRestore,
    required this.onLoadBackupConfig,
    required this.onConfigChanged,
    required this.serverCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.pathCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
        children: [
          _header(),
          _tagCard(context),
          const SizedBox(height: 4),
          _importCard(),
          const SizedBox(height: 14),
          _backupCard(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('设置', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
              SizedBox(width: 9),
              Text(appVersion, style: TextStyle(fontSize: 15, color: T.teal, fontWeight: FontWeight.w700)),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onOpenPeople();
            },
            child: Container(
              width: 40, height: 40,
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

  Widget _tagCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: T.shadow2,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('我的标签', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                GestureDetector(
                  onTap: onNewTag,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: T.tealSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.add, size: 18, color: T.teal),
                  ),
                ),
              ],
            ),
          ),
          if (state.tags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('还没有标签，点右上角 + 新建',
                  style: TextStyle(color: T.ink3, fontSize: 13)),
            )
          else
            ...List.generate(state.tags.length, (i) => _tagItem(context, state.tags[i], i)),
        ],
      ),
    );
  }

  Widget _tagItem(BuildContext context, dynamic tag, int i) {
    final count = state.people.where((p) => p.tagIds.contains(tag.id)).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.line2, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(tag.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: T.surface2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count 人', style: const TextStyle(fontSize: 12, color: T.ink2)),
          ),
          const SizedBox(width: 10),
          _mini(Icons.keyboard_arrow_up, () => state.moveTag(i, -1), T.ink2),
          const SizedBox(width: 8),
          _mini(Icons.keyboard_arrow_down, () => state.moveTag(i, 1), T.ink2),
          const SizedBox(width: 8),
          _mini(Icons.delete_outline, () => _confirmDeleteTag(context, tag.name, tag.id, count), T.danger),
        ],
      ),
    );
  }

  /// 只有没有任何画师使用的标签才能删除，避免误删导致画师标签被连带移除
  Future<void> _confirmDeleteTag(BuildContext context, String name, int id, int count) async {
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法删除标签'),
          content: Text('「$name」正在被 $count 位画师使用。\n\n请先从这些画师身上移除该标签，再删除标签。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签？'),
        content: Text('确定要删除「$name」吗？该标签目前无人使用。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: T.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) await state.deleteTag(id);
  }

  Widget _mini(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: T.surface,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(9),
          boxShadow: T.shadow1,
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  Widget _importCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: T.shadow2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: T.tealSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.description_outlined, size: 22, color: T.teal),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('从 Excel 导入姓名', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('无表头，第一列每一行就是一个姓名；自动去重、忽略空行。支持中文 / English / 日本語 / 한국어',
                        style: TextStyle(fontSize: 11, color: T.ink2, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
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
            child: ElevatedButton.icon(
              onPressed: () => onImportExcel(),
              icon: const Icon(Icons.file_upload_outlined, size: 17),
              label: const Text('选择 Excel 文件'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupCard() {
    return Container(
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: T.shadow2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text('云备份', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          _statusHead(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _field('WebDAV 服务器', serverCtrl, field: 'server'),
                _field('坚果云邮箱', emailCtrl, field: 'email'),
                _field('应用密码', passCtrl, field: 'pass', obscure: true),
                _field('备份文件名', pathCtrl, field: 'path'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                          onPressed: () => onBackup('backup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text('立即备份', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 47,
                        child: OutlinedButton(
                          onPressed: () => onRestore('restore'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: T.ink,
                            side: const BorderSide(color: T.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('恢复', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.line2))),
            child: Column(
              children: [
                _toggle('自动备份', '变更时自动上传到网盘', false, (v) {}),
                _toggle('仅 WiFi 下备份', '避免消耗移动流量', true, (v) {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusHead() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(gradient: T.tealGradient),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('上次备份', style: TextStyle(fontSize: 14, color: Colors.white70)),
          SizedBox(height: 6),
          Text('—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
          SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: Colors.white70),
              SizedBox(width: 5),
              Text('AES-256 加密', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? field, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: const TextStyle(fontSize: 12, color: T.ink2, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            height: 44,
            child: TextField(
              controller: ctrl,
              obscureText: obscure,
              onChanged: field == null ? null : (v) => onConfigChanged(field, v),
              style: const TextStyle(fontSize: 14, color: T.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: T.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: T.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: T.line),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String title, String sub, bool initial, Function(bool) onChange) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool on = initial;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(sub, style: const TextStyle(fontSize: 11, color: T.ink2)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => on = !on);
                  onChange(on);
                },
                child: AnimatedContainer(
                  duration: Motion.durFast,
                  width: 44, height: 26,
                  decoration: BoxDecoration(
                    color: on ? T.tealB : T.line,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedAlign(
                    duration: Motion.durFast,
                    curve: Motion.spring,
                    alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 20, height: 20, margin: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
