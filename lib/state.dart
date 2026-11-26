import 'package:flutter/foundation.dart';
import 'models.dart';
import 'db.dart';
import 'photo_store.dart';

class AppState extends ChangeNotifier {
  final Db _db = Db();
  List<AppTag> tags = [];
  List<Person> people = [];
  final Set<int> selectedTags = {};
  String search = '';
  bool loaded = false;

  int dice = 3;
  /// 骰子累计旋转圈数：每点一次 +1，只正转不倒转。
  int diceTurns = 0;

  String sortField = 'time';
  bool sortAsc = false;

  void setSort(String field, bool asc) {
    sortField = field;
    sortAsc = asc;
    notifyListeners();
  }

  void toggleSortDirection() {
    sortAsc = !sortAsc;
    notifyListeners();
  }

  void rollDice() {
    dice = 1 + (DateTime.now().microsecondsSinceEpoch % 6);
    diceTurns += 1;
    notifyListeners();
  }

  Future<void> load() async {
    tags = await _db.tags();
    people = await _db.allPeople();
    loaded = true;
    notifyListeners();
  }

  List<Person> get filtered {
    final q = search.trim().toLowerCase();
    final list = people.where((p) {
      final matchQ = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.tagIds.any((id) =>
              tags.where((t) => t.id == id).any((t) => t.name.toLowerCase().contains(q)));
      final matchT = selectedTags.every((t) => p.tagIds.contains(t));
      return matchQ && matchT;
    }).toList();

    int cmp(Person a, Person b) {
      switch (sortField) {
        case 'name':
          final c = a.name.compareTo(b.name);
          return c != 0 ? c : a.id.compareTo(b.id);
        case 'tags':
          final c = a.tagIds.length.compareTo(b.tagIds.length);
          return c != 0 ? c : a.id.compareTo(b.id);
        case 'photos':
          final c = a.photos.length.compareTo(b.photos.length);
          return c != 0 ? c : a.id.compareTo(b.id);
        case 'time':
        default:
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.id.compareTo(b.id);
      }
    }

    list.sort((a, b) {
      final c = cmp(a, b);
      return sortAsc ? c : -c;
    });
    return list;
  }

  String tagName(int id) => tags.where((t) => t.id == id).map((t) => t.name).firstOrNull ?? '?';

  void setSearch(String v) {
    search = v;
    notifyListeners();
  }

  void toggleTag(int id) {
    if (selectedTags.contains(id)) {
      selectedTags.remove(id);
    } else {
      selectedTags.add(id);
    }
    notifyListeners();
  }

  void clearFilter() {
    search = '';
    selectedTags.clear();
    notifyListeners();
  }

  Future<void> addTag(String name) async {
    await _db.addTag(name.trim());
    await load();
  }

  Future<void> deleteTag(int id) async {
    await _db.deleteTag(id);
    selectedTags.remove(id);
    await load();
  }

  Future<void> moveTag(int index, int dir) async {
    final j = index + dir;
    if (j < 0 || j >= tags.length) return;
    final item = tags.removeAt(index);
    tags.insert(j, item);
    await _db.reorderTags(List<AppTag>.from(tags));
    notifyListeners();
  }

  /// 忽略大小写、全角半角、空格差异后判重。excludeId 用于编辑时排除自身。
  bool isDuplicateName(String name, {int? excludeId}) {
    final key = normalizeName(name);
    if (key.isEmpty) return false;
    return people.any((p) => p.id != excludeId && normalizeName(p.name) == key);
  }

  /// 标签判重，口径与姓名一致（忽略大小写、全角半角、空格差异）。
  bool isDuplicateTag(String name) {
    final key = normalizeName(name);
    if (key.isEmpty) return false;
    return tags.any((t) => normalizeName(t.name) == key);
  }

  Future<Person> addPerson(String name, List<int> tagIds, List<String> photos) async {
    final maxId = people.isEmpty ? 0 : people.map((p) => p.id).reduce((a, b) => a > b ? a : b);
    final p = Person(
      id: maxId + 1,
      name: name.trim(),
      tagIds: List<int>.from(tagIds),
      photos: List<String>.from(photos),
      date: stampNow(),
      palette: people.length % 8,
    );
    await _db.addPerson(p);
    await load();
    return p;
  }

  /// 全库当前被引用的图片文件名集合
  Set<String> get referencedPhotos =>
      people.expand((p) => p.photos).toSet();

  Future<Person?> updatePerson(int id, String name, List<int> tagIds, List<String> photos) async {
    final idx = people.indexWhere((p) => p.id == id);
    if (idx < 0) return null;
    final old = people[idx];
    final updated = Person(
      id: old.id,
      name: name.trim(),
      tagIds: List<int>.from(tagIds),
      photos: List<String>.from(photos),
      date: old.date,
      palette: old.palette,
    );
    await _db.savePerson(updated);
    await load();
    await PhotoStore.gcUnreferenced(referencedPhotos);
    return people.where((p) => p.id == id).firstOrNull;
  }

  Future<void> deletePerson(int id) async {
    await _db.deletePerson(id);
    await load();
    await PhotoStore.gcUnreferenced(referencedPhotos);
  }

  /// 调整某位画师的图片顺序（只改顺序，不涉及文件增删）
  Future<void> reorderPhotos(int personId, List<String> photos) async {
    final idx = people.indexWhere((p) => p.id == personId);
    if (idx < 0) return;
    final old = people[idx];
    final updated = Person(
      id: old.id,
      name: old.name,
      tagIds: List<int>.from(old.tagIds),
      photos: List<String>.from(photos),
      date: old.date,
      palette: old.palette,
    );
    await _db.savePerson(updated);
    await load();
  }

  Future<List<int>> importNames(List<String> names) async {
    final r = await _db.importNames(names);
    await load();
    return r;
  }

  Future<void> replaceAll(List<AppTag> newTags, List<Person> newPeople) async {
    await _db.replaceAll(newTags, newPeople);
    selectedTags.clear();
    search = '';
    await load();
    // 恢复后清理：images already written by caller, drop orphans not in new data
    await PhotoStore.gcUnreferenced(referencedPhotos);
  }

}
