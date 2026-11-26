import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PhotoStore {
  static final ImagePicker _picker = ImagePicker();

  static Future<Directory> get dir async {
    final app = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(app.path, 'photos'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// 选一张图片，复制到应用目录，返回相对文件名。
  static Future<String?> pickAndSave() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return null;
    final d = await dir;
    final name = 'img_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final dest = File(p.join(d.path, name));
    await dest.writeAsBytes(await File(x.path).readAsBytes());
    return name;
  }

  static File file(String name) => File(p.join(_dirPath, name));

  /// dir 的同步版本（用于已知目录已创建的场景）
  static String get dirPathSync => _dirPath;
  static String _dirPath = '';
  static Future<void> init() async => _dirPath = (await dir).path;

  static Future<String> toBase64(String name) async {
    final f = File(p.join(_dirPath, name));
    if (!await f.exists()) return '';
    return base64.encode(await f.readAsBytes());
  }

  static Future<void> writeBase64(String name, String b64) async {
    final f = File(p.join(_dirPath, name));
    await f.writeAsBytes(base64.decode(b64));
  }

  /// 回收没有任何画师引用的图片文件。
  /// 在删除画师 / 编辑移除图片 / 恢复覆盖后调用，避免 photos 目录垃圾堆积。
  static Future<int> gcUnreferenced(Set<String> referenced) async {
    final d = await dir;
    var removed = 0;
    await for (final entity in d.list()) {
      if (entity is File && !referenced.contains(p.basename(entity.path))) {
        try {
          await entity.delete();
          removed++;
        } catch (_) {
          // 文件被占用等，忽略，下次再回收
        }
      }
    }
    return removed;
  }
}
