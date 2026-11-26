import 'package:flutter/services.dart';

/// 拉起外部应用。当前目标：漫画客户端 Breeze（com.zephyr.breeze）。
class AppLauncher {
  static const MethodChannel _ch = MethodChannel('namebook/launcher');

  /// 复制姓名后拉起 Breeze，并尝试把名字作为文本分享给它。
  /// 返回 shared（已分享文本）/ launched（仅拉起）/ not_installed / error:xxx
  static Future<String> launchBreezeWithName(String name) async {
    try {
      final res = await _ch.invokeMethod<String>(
        'launchBreezeWithName',
        {'name': name},
      );
      return res ?? 'error:empty result';
    } on PlatformException catch (e) {
      return 'error:${e.message ?? e.code}';
    } catch (e) {
      return 'error:$e';
    }
  }
}
