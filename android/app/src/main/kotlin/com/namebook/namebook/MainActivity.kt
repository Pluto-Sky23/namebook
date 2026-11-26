package com.namebook.namebook

import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "namebook/launcher"
        private const val BREEZE_PACKAGE = "com.zephyr.breeze"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "launchBreezeWithName") {
                    val name = call.argument<String>("name") ?: ""
                    result.success(launchBreeze(name))
                } else {
                    result.notImplemented()
                }
            }
    }

    /// 先尝试用 ACTION_SEND 把姓名文本分享给 Breeze；
    /// 若 Breeze 未注册文本接收，则回退到仅拉起应用主界面。
    private fun launchBreeze(name: String): String {
        return try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                setPackage(BREEZE_PACKAGE)
                putExtra(Intent.EXTRA_TEXT, name)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val resolved = packageManager.resolveActivity(
                sendIntent,
                PackageManager.MATCH_DEFAULT_ONLY
            )
            if (resolved != null) {
                startActivity(sendIntent)
                "shared"
            } else {
                val launchIntent = packageManager.getLaunchIntentForPackage(BREEZE_PACKAGE)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launchIntent)
                    "launched"
                } else {
                    "not_installed"
                }
            }
        } catch (e: Exception) {
            "error: ${e.message ?: e.javaClass.simpleName}"
        }
    }
}
