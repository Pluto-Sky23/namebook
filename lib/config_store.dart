import 'package:shared_preferences/shared_preferences.dart';
import 'backup.dart';

/// 坚果云备份配置持久化。字段少，直接用 SharedPreferences 单键存储。
class BackupConfig {
  static const kServer = 'server';
  static const kEmail = 'email';
  static const kPass = 'pass';
  static const kPath = 'path';

  static const _prefix = 'backup_';

  /// 读取配置，缺省值回落到内置默认。
  static Future<Map<String, String>> load() async {
    final p = await SharedPreferences.getInstance();
    return {
      kServer: p.getString(_prefix + kServer) ?? BackupService.defaultServer,
      kEmail: p.getString(_prefix + kEmail) ?? '',
      kPass: p.getString(_prefix + kPass) ?? '',
      kPath: p.getString(_prefix + kPath) ?? BackupService.defaultPath,
    };
  }

  /// 单字段写入，输入时逐字段保存，避免整表覆盖。
  static Future<void> save(String field, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefix + field, value);
  }
}
