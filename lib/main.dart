import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'theme.dart';
import 'state.dart';
import 'models.dart';
import 'photo_store.dart';
import 'backup.dart';
import 'config_store.dart';
import 'excel_import.dart';
import 'pages/people_page.dart';
import 'pages/settings_page.dart';
import 'pages/add_sheet.dart';
import 'pages/detail_sheet.dart';
import 'widgets/head_bar.dart';
import 'widgets/sort_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PhotoStore.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '画师册',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: T.teal),
        scaffoldBackgroundColor: T.bg,
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final state = AppState();
  int _page = 0;
  Person? _detail;
  final _serverCtrl = TextEditingController(text: BackupService.defaultServer);
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pathCtrl = TextEditingController(text: BackupService.defaultPath);
  final _searchCtrl = TextEditingController();
  final _headKey = GlobalKey();
  double _headH = 122;

  void _onHeadMeasured(double h) {
    if ((h - _headH).abs() > 0.5 && mounted) setState(() => _headH = h);
  }

  @override
  void initState() {
    super.initState();
    state.addListener(_onState);
    state.load();
    _loadBackupConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _headKey.currentContext;
      final size = ctx?.size;
      if (size != null && size.height > 0) _onHeadMeasured(size.height);
    });
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  /// 启动时读取坚果云配置，回填到输入框。异步完成后直接改 controller.text，
  /// TextEditingController 会自动通知 TextField 刷新，无需 setState。
  Future<void> _loadBackupConfig() async {
    final cfg = await BackupConfig.load();
    _serverCtrl.text = cfg[BackupConfig.kServer]!;
    _emailCtrl.text = cfg[BackupConfig.kEmail]!;
    _passCtrl.text = cfg[BackupConfig.kPass]!;
    _pathCtrl.text = cfg[BackupConfig.kPath]!;
  }

  /// 输入框变化时逐字段保存到本地，关闭应用后仍在。
  void _saveBackupConfig(String field, String value) {
    BackupConfig.save(field, value);
  }

  @override
  void dispose() {
    state.removeListener(_onState);
    super.dispose();
  }

  void _go(int page) {
    HapticFeedback.lightImpact();
    setState(() {
      _detail = null;
      _page = page;
    });
  }

  void _openDetail(Person p) {
    HapticFeedback.lightImpact();
    // 收起键盘并移除搜索框光标，避免新建/编辑保存后输入栏仍显示 "|"。
    // 延迟到下一帧，确保 bottom sheet 弹出后的焦点恢复不会再把焦点还给输入框。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    setState(() => _detail = p);
  }

  void _roll() {
    // 主页与详情页一致：点下随机立即切换，不等待骰子动画
    state.rollDice();
    _pickAndOpenDetail();
  }

  void _pickAndOpenDetail() {
    final list = state.filtered.where((p) => p.id != _detail?.id).toList();
    if (list.isNotEmpty) {
      list.shuffle();
      _openDetail(list.first);
    }
  }

  void _switchDetail(int delta) {
    final list = state.filtered;
    if (list.length < 2 || _detail == null) return;
    final idx = list.indexWhere((p) => p.id == _detail!.id);
    if (idx < 0) return;
    final next = idx + delta;
    if (next < 0 || next >= list.length) return;
    HapticFeedback.selectionClick();
    setState(() => _detail = list[next]);
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出画师册？'),
        content: const Text('确定要退出应用吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) SystemNavigator.pop();
  }

  Future<bool> _confirmDelete(Person p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除画师？'),
        content: Text('确定要删除「${p.name}」吗？删除后无法恢复。'),
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
    return ok == true;
  }

  Future<bool> _confirmDuplicate(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('名字可能重复'),
        content: Text('「$name」与已有画师同名（已忽略大小写、全角半角与空格差异）。\n\n仍要录入吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: T.teal),
            child: const Text('继续录入'),
          ),
        ],
      ),
    );
    return ok == true;
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

  void _showSort() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SortSheet(state: state),
    );
  }

  void _showEdit(Person p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => AddSheet(
        state: state,
        editing: p,
        onSave: (name, tags, photos) async {
          if (state.isDuplicateName(name, excludeId: p.id) &&
              !await _confirmDuplicate(name)) return;
          final updated = await state.updatePerson(p.id, name, tags, photos);
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          if (updated != null) _openDetail(updated);
        },
      ),
    );
  }

  void _showAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => AddSheet(
        state: state,
        onSave: (name, tags, photos) async {
          if (state.isDuplicateName(name) && !await _confirmDuplicate(name)) return;
          final p = await state.addPerson(name, tags, photos);
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          _openDetail(p);
        },
      ),
    );
  }

  void _showNewTag() {
    final c = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: T.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(ctx).viewInsets.bottom + 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: T.line, borderRadius: BorderRadius.circular(3)))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('新建标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
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
                controller: c, autofocus: true,
                style: const TextStyle(fontSize: 17, color: T.ink),
                decoration: InputDecoration(
                  hintText: '标签名称', hintStyle: const TextStyle(color: T.ink3),
                  filled: true, fillColor: T.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: T.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: T.line)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () async {
                  final n = c.text.trim();
                  if (n.isEmpty) return;
                  if (state.isDuplicateTag(n) && !await _confirmDuplicateTag(n)) return;
                  await state.addTag(n);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: T.teal, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: const Text('创建标签', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importExcel() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      final names = ExcelImport.readFirstColumn(path);
      if (names.isEmpty) {
        _toast('表格里没有读到姓名');
        return;
      }
      // 预览：按与入库一致的去重口径，预估新增/跳过数量
      final existing = state.people.map((p) => normalizeName(p.name)).toSet();
      final seen = <String>{};
      final willAdd = <String>[];
      var willSkip = 0;
      for (final raw in names) {
        final n = raw.trim();
        if (n.isEmpty) continue;
        final key = normalizeName(n);
        if (key.isEmpty || existing.contains(key) || seen.contains(key)) {
          willSkip++;
          continue;
        }
        seen.add(key);
        willAdd.add(n);
      }
      if (!mounted) return;
      final preview = willAdd.take(8).join('\n');
      final more = willAdd.length > 8 ? '\n… 还有 ${willAdd.length - 8} 位' : '';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认导入姓名？'),
          content: SingleChildScrollView(
            child: Text(
              '将导入 ${willAdd.length} 位，跳过 $willSkip 个重复或空行。\n\n'
              '前 ${willAdd.length > 8 ? 8 : willAdd.length} 位：\n$preview$more',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: T.teal),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final r = await state.importNames(names);
      if (mounted) _toast('导入 ${r[0]} 人，跳过 ${r[1]} 个重复');
    } catch (e) {
      if (mounted) _toast('导入失败：$e');
    }
  }

  Future<void> _backup() async {
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      if (email.isEmpty || pass.isEmpty) {
        _toast('请先填写坚果云邮箱和应用密码');
        return;
      }
      final photoBases = <int, List<String>>{};
      for (final p in state.people) {
        final bases = <String>[];
        for (final f in p.photos) {
          bases.add(await PhotoStore.toBase64(f));
        }
        photoBases[p.id] = bases;
      }
      final payload = BackupService.buildPayload(state.tags, state.people, photoBases);
      final encrypted = BackupService.encryptJson(payload, pass);
      final server = _serverCtrl.text.trim();
      final path = _pathCtrl.text.trim();
      // 坚果云要求父目录先存在，先逐级 MKCOL 建目录，避免 409 AncestorsNotFound
      await BackupService.ensureParentDirs(
        server: server,
        email: email,
        appPassword: pass,
        remotePath: path,
      );
      await BackupService.upload(
        server: server,
        email: email,
        appPassword: pass,
        remotePath: path,
        payload: encrypted,
      );
      // 额外备份一个只含所有人名字的 Excel（无表头，可直接再导入）
      // 按导入时间从早到晚写：最上面 = 最早，导回时顺序保持一致
      final ordered = List<Person>.from(state.people)
        ..sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      final names = ordered.map((p) => p.name).toList();
      final xlsx = ExcelImport.buildNamesXlsx(names);
      await BackupService.uploadBytes(
        server: server,
        email: email,
        appPassword: pass,
        remotePath: BackupService.namesExcelPath(path),
        bytes: xlsx,
        contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) _toast('备份成功（含姓名表格）');
    } catch (e) {
      if (mounted) _toast('备份失败：$e');
    }
  }

  Future<void> _restore() async {
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      if (email.isEmpty || pass.isEmpty) {
        _toast('请先填写坚果云邮箱和应用密码');
        return;
      }
      final encrypted = await BackupService.download(
        server: _serverCtrl.text.trim(),
        email: email,
        appPassword: pass,
        remotePath: _pathCtrl.text.trim(),
      );
      final jsonStr = BackupService.decryptJson(encrypted, pass);
      final data = BackupService.parsePayload(jsonStr);
      final tags = data['tags'] as List<AppTag>;
      final people = data['people'] as List<Person>;
      final raw = data['raw'] as Map<String, dynamic>;
      final rawPeople = raw['people'] as List;

      // 恢复前确认：先展示备份内容规模，明确会覆盖当前数据，避免误操作
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认恢复备份？'),
          content: Text(
            '云端备份：${people.length} 位画师、${tags.length} 个标签。\n\n'
            '恢复会清空并覆盖当前本机数据（现有 ${state.people.length} 位画师），此操作不可撤销。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: T.teal),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );
      if (ok != true) return;

      for (final p in people) {
        final entry = rawPeople.firstWhere((e) => e['id'] == p.id, orElse: () => {});
        final bases = (entry['photosBase64'] as List?) ?? [];
        for (var i = 0; i < bases.length && i < p.photos.length; i++) {
          await PhotoStore.writeBase64(p.photos[i], bases[i] as String);
        }
      }
      await state.replaceAll(tags, people);
      if (mounted) _toast('恢复成功');
    } catch (e) {
      if (mounted) _toast('恢复失败：$e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_detail != null) {
          setState(() => _detail = null);
        } else if (_page == 1) {
          _go(0);
        } else {
          _confirmExit();
        }
      },
      child: Scaffold(
      backgroundColor: T.bg,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Stack(
            children: [
              _page == 0
                  ? PeoplePage(
                      key: const ValueKey('people'),
                      state: state,
                      onOpenSettings: () => _go(1),
                      onOpenDetail: _openDetail,
                      onAdd: _showAdd,
                      onRoll: _roll,
                      onSort: _showSort,
                      searchCtrl: _searchCtrl,
                      headKey: _headKey,
                    )
                  : SettingsPage(
                      key: const ValueKey('settings'),
                      state: state,
                      onOpenPeople: () => _go(0),
                      onNewTag: _showNewTag,
                      onImportExcel: _importExcel,
                      onBackup: (_) => _backup(),
                      onRestore: (_) => _restore(),
                      onLoadBackupConfig: _loadBackupConfig,
                      onConfigChanged: _saveBackupConfig,
                      serverCtrl: _serverCtrl,
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      pathCtrl: _pathCtrl,
                    ),
              if (_detail != null)
                DetailSheet(
                  key: const ValueKey('detail_sheet'),
                  person: _detail!,
                  state: state,
                  topOffset: _headH,
                  onClose: () => setState(() => _detail = null),
                  onSwitch: _switchDetail,
                  onEdit: () => _showEdit(_detail!),
                  onDelete: (p) async {
                    if (!await _confirmDelete(p)) return;
                    await state.deletePerson(p.id);
                    if (mounted) setState(() => _detail = null);
                  },
                ),
              if (_detail != null && _page == 0) _floatingHead(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// 详情打开时浮在最上层的表头，与主页面共用同一组件，位置/骰子/动效完全一致。
  Widget _floatingHead() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: HeadBar(
        searchCtrl: _searchCtrl,
        onSettings: () => _go(1),
        onRoll: _roll,
        onSort: _showSort,
        dice: state.dice,
        diceTurns: state.diceTurns,
        sortActive: state.sortField != 'time' || state.sortAsc,
        count: state.filtered.length,
        onSearchChanged: (v) => state.setSearch(v),
      ),
    );
  }
}
