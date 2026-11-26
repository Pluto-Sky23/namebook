/// 固定 23 位时间字符串，字典序 == 时间先后，可直接用于 compareTo 排序。
/// 格式：YYYY-MM-DD HH:MM:SS.mmm
String stampOf(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
      '${t.millisecond.toString().padLeft(3, '0')}';
}

/// 当前时刻的时间戳。
String stampNow() => stampOf(DateTime.now());

/// 姓名规范化：全角 ASCII 转半角、全角空格转普通空格、忽略所有空白、统一小写。
/// 用于判重——忽略大小写、全角半角、空格差异后仍相同即视为同名。
String normalizeName(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    var c = r;
    if (c == 0x3000) {
      c = 0x20; // 全角空格 -> 普通空格
    } else if (c >= 0xFF01 && c <= 0xFF5E) {
      c -= 0xFEE0; // 全角 ASCII -> 半角
    }
    if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
      continue; // 忽略空格/制表/换行差异
    }
    b.writeCharCode(c);
  }
  return b.toString().toLowerCase();
}

class AppTag {
  final int id;
  String name;
  int sortOrder;

  AppTag({required this.id, required this.name, this.sortOrder = 0});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sortOrder': sortOrder,
      };

  factory AppTag.fromMap(Map<String, dynamic> m) => AppTag(
        id: m['id'] as int,
        name: m['name'] as String,
        sortOrder: m['sortOrder'] as int? ?? 0,
      );
}

class Person {
  final int id;
  String name;
  List<int> tagIds;
  List<String> photos;
  String date;
  int palette;

  Person({
    required this.id,
    required this.name,
    List<int>? tagIds,
    List<String>? photos,
    String? date,
    this.palette = 0,
  })  : tagIds = tagIds ?? <int>[],
        photos = photos ?? <String>[],
        date = date ?? '';

  String get initial => name.isEmpty ? '?' : name.substring(0, 1);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'tagIds': tagIds.join(','),
        'photos': photos.join('\n'),
        'date': date,
        'palette': palette,
      };

  factory Person.fromMap(Map<String, dynamic> m) => Person(
        id: m['id'] as int,
        name: m['name'] as String,
        tagIds: (m['tagIds'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
        photos: (m['photos'] as String? ?? '')
            .split('\n')
            .where((s) => s.isNotEmpty)
            .toList(),
        date: m['date'] as String? ?? '',
        palette: m['palette'] as int? ?? 0,
      );

  Person copy() => Person(
        id: id,
        name: name,
        tagIds: List<int>.from(tagIds),
        photos: List<String>.from(photos),
        date: date,
        palette: palette,
      );
}
