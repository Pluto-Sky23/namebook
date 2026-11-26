import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;
import 'models.dart';

/// 坚果云 WebDAV 备份：整包用用户密码派生密钥做 AES-256 加密。
class BackupService {
  static const defaultServer = 'https://dav.jianguoyun.com/dav/';
  static const defaultPath = '/namekeeper/namebook-backup.enc';

  /// 用密码派生 32 字节密钥（SHA256 迭代），保证任意长度密码可用。
  static enc.Key _key(String password) {
    List<int> bytes = utf8.encode(password);
    for (var i = 0; i < 1000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return enc.Key(Uint8List.fromList(bytes.take(32).toList()));
  }

  static String encryptJson(String plain, String password) {
    final iv = enc.IV.fromSecureRandom(16);
    final e = enc.Encrypter(enc.AES(_key(password), mode: enc.AESMode.cbc));
    final encrypted = e.encrypt(plain, iv: iv);
    // 格式: BASE64(IV):BASE64(cipher)
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decryptJson(String payload, String password) {
    final parts = payload.split(':');
    if (parts.length != 2) throw const FormatException('备份文件格式错误');
    final iv = enc.IV.fromBase64(parts[0]);
    final e = enc.Encrypter(enc.AES(_key(password), mode: enc.AESMode.cbc));
    return e.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
  }

  static Uri _url(String server, String remotePath) {
    final base = server.endsWith('/') ? server : '$server/';
    final rel = remotePath.startsWith('/') ? remotePath.substring(1) : remotePath;
    return Uri.parse(base + rel);
  }

  static String _basicAuth(String user, String password) {
    return 'Basic ${base64.encode(utf8.encode('$user:$password'))}';
  }

  /// 逐级创建备份路径的父目录（WebDAV MKCOL）。
  /// 坚果云要求父目录先存在，否则 PUT 文件会返回 409 AncestorsNotFound。
  /// 目录已存在时 MKCOL 返回 405，视为成功。
  static Future<void> ensureParentDirs({
    required String server,
    required String email,
    required String appPassword,
    required String remotePath,
  }) async {
    final base = server.endsWith('/') ? server : '$server/';
    final rel = remotePath.startsWith('/') ? remotePath.substring(1) : remotePath;
    final parts = rel.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return; // 路径没有父目录（例如 backup.enc）
    final client = http.Client();
    try {
      String cur = base;
      // 只建到倒数第二段（最后一段是文件名）
      for (var i = 0; i < parts.length - 1; i++) {
        cur += '${parts[i]}/';
        final req = http.Request('MKCOL', Uri.parse(cur))
          ..headers['Authorization'] = _basicAuth(email, appPassword);
        final resp = await client.send(req).timeout(const Duration(seconds: 30));
        await resp.stream.drain<void>();
        final code = resp.statusCode;
        // 201=新建成功；405=目录已存在；2xx 其它=服务端已接受
        if (code != 201 && code != 405 && (code < 200 || code >= 300)) {
          throw Exception('创建备份目录失败 ($cur) ($code)');
        }
      }
    } finally {
      client.close();
    }
  }

  /// 上传加密备份。password 为备份密码（建议用坚果云应用密码）。
  static Future<void> upload({
    required String server,
    required String email,
    required String appPassword,
    required String remotePath,
    required String payload,
  }) async {
    final url = _url(server, remotePath);
    final resp = await http
        .put(
          url,
          headers: {
            'Authorization': _basicAuth(email, appPassword),
            'Content-Type': 'application/octet-stream',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw Exception('备份失败 (${resp.statusCode})：${resp.body}');
  }

  /// 由加密备份路径派生同目录下的纯姓名 Excel 路径。
  /// 例：/namekeeper/namebook-backup.enc -> /namekeeper/namebook-backup-names.xlsx
  static String namesExcelPath(String remotePath) {
    final slash = remotePath.lastIndexOf('/');
    final dir = slash >= 0 ? remotePath.substring(0, slash + 1) : '';
    final name = slash >= 0 ? remotePath.substring(slash + 1) : remotePath;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    return '$dir$stem-names.xlsx';
  }

  /// 上传任意二进制文件到 WebDAV（用于纯姓名 Excel）。
  static Future<void> uploadBytes({
    required String server,
    required String email,
    required String appPassword,
    required String remotePath,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    final url = _url(server, remotePath);
    final resp = await http
        .put(
          url,
          headers: {
            'Authorization': _basicAuth(email, appPassword),
            'Content-Type': contentType,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw Exception('姓名表格上传失败 (${resp.statusCode})：${resp.body}');
  }

  /// 下载加密备份。
  static Future<String> download({
    required String server,
    required String email,
    required String appPassword,
    required String remotePath,
  }) async {
    final url = _url(server, remotePath);
    final resp = await http
        .get(url, headers: {'Authorization': _basicAuth(email, appPassword)})
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode >= 200 && resp.statusCode < 300) return resp.body;
    throw Exception('下载失败 (${resp.statusCode})：${resp.body}');
  }

  /// 打包为 JSON（图片按 base64 内嵌）。
  static String buildPayload(List<AppTag> tags, List<Person> people,
      Map<int, List<String>> photoBases) {
    final data = {
      'v': 1,
      'tags': tags.map((t) => t.toMap()).toList(),
      'people': people
          .map((p) => {
                ...p.toMap(),
                'photosBase64':
                    (photoBases[p.id] ?? <String>[]).map((f) => f).toList(),
              })
          .toList(),
    };
    return json.encode(data);
  }

  /// 从 JSON 还原（返回标签、画师、图片 base64 映射），由调用方写库/落盘。
  static Map<String, dynamic> parsePayload(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final tags = (data['tags'] as List)
        .map((e) => AppTag.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final people = (data['people'] as List)
        .map((e) => Person.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return {'tags': tags, 'people': people, 'raw': data};
  }
}
