import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class Db {
  static final Db _i = Db._();
  factory Db() => _i;
  Db._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final p = await getDatabasesPath();
    _db = await openDatabase(
      join(p, 'namebook.db'),
      version: 1,
      onCreate: (d, v) async {
        await d.execute(
          'CREATE TABLE tags (id INTEGER PRIMARY KEY, name TEXT, sortOrder INTEGER)');
        await d.execute(
          'CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT, tagIds TEXT, photos TEXT, date TEXT, palette INTEGER)');
      },
    );
    return _db!;
  }

  Future<List<AppTag>> tags() async {
    final d = await db;
    final rows = await d.query('tags', orderBy: 'sortOrder ASC, id ASC');
    return rows.map((r) => AppTag.fromMap(r)).toList();
  }

  Future<int> addTag(String name) async {
    final d = await db;
    final list = await tags();
    final maxId = list.isEmpty ? 0 : list.map((t) => t.id).reduce((a, b) => a > b ? a : b);
    return d.insert('tags',
        AppTag(id: maxId + 1, name: name, sortOrder: list.length).toMap());
  }

  Future<void> updateTag(AppTag t) async {
    final d = await db;
    await d.update('tags', t.toMap(), where: 'id=?', whereArgs: [t.id]);
  }

  Future<void> deleteTag(int id) async {
    final d = await db;
    await d.delete('tags', where: 'id=?', whereArgs: [id]);
    final people = await allPeople();
    for (final p in people) {
      if (p.tagIds.contains(id)) {
        p.tagIds.removeWhere((x) => x == id);
        await savePerson(p);
      }
    }
  }

  Future<void> reorderTags(List<AppTag> list) async {
    final d = await db;
    final batch = d.batch();
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
      batch.update('tags', {'sortOrder': i}, where: 'id=?', whereArgs: [list[i].id]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Person>> allPeople() async {
    final d = await db;
    final rows = await d.query('people', orderBy: 'id DESC');
    return rows.map((r) => Person.fromMap(r)).toList();
  }

  Future<int> addPerson(Person p) async {
    final d = await db;
    return d.insert('people', p.toMap());
  }

  Future<void> savePerson(Person p) async {
    final d = await db;
    await d.update('people', p.toMap(), where: 'id=?', whereArgs: [p.id]);
  }

  Future<void> deletePerson(int id) async {
    final d = await db;
    await d.delete('people', where: 'id=?', whereArgs: [id]);
  }

  /// 无表头导入：第一列每个单元格一个姓名，去重、忽略空行，支持中英日韩。
  /// 返回 [导入数, 跳过重复数]。
  /// 时间语义：Excel 最上面的人算导入时间最早，越往下越晚（按行序递增 1 秒）。
  Future<List<int>> importNames(List<String> names) async {
    final existing = (await allPeople()).map((p) => normalizeName(p.name)).toSet();
    final seen = <String>{};
    var added = 0, skipped = 0;
    // 让最后一行刚好落在"现在"，其上面的行依次提前，整体保持按行序递增。
    final base = DateTime.now().subtract(Duration(seconds: names.length));
    for (var i = 0; i < names.length; i++) {
      final raw = names[i];
      final n = raw.trim();
      if (n.isEmpty) continue;
      final key = normalizeName(n);
      if (key.isEmpty || existing.contains(key) || seen.contains(key)) {
        skipped++;
        continue;
      }
      seen.add(key);
      final id = await _nextPersonId();
      await addPerson(Person(
        id: id,
        name: n,
        palette: added % 8,
        date: stampOf(base.add(Duration(seconds: i + 1))),
      ));
      added++;
    }
    return [added, skipped];
  }

  Future<int> _nextPersonId() async {
    final d = await db;
    final r = await d.rawQuery('SELECT MAX(id) AS m FROM people');
    final m = r.first['m'];
    return (m is int ? m : 0) + 1;
  }

  /// 事务化全量替换：删除与写入在同一事务内，任何一步失败都整体回滚，
  /// 避免"旧的已删、新的没写完"导致数据全丢。
  Future<void> replaceAll(List<AppTag> newTags, List<Person> newPeople) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('people');
      await txn.delete('tags');
      for (final t in newTags) {
        await txn.insert('tags', t.toMap());
      }
      for (final p in newPeople) {
        await txn.insert('people', p.toMap());
      }
    });
  }
}
