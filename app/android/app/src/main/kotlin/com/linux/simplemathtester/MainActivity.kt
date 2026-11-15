package com.linux.simplemathtester

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // Flutter's HapticFeedback calls View.performHapticFeedback, which Android
    // skips when the system "touch feedback" setting is off. The vibrator
    // (VIBRATE permission) follows the app's own Vibration switch instead.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simplemathtester/vibrate")
            .setMethodCallHandler { call, result ->
                val ms = (call.arguments as? Int)?.toLong()
                if (call.method != "vibrate" || ms == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val vibrator = getSystemService(Vibrator::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(ms)
                }
                result.success(null)
            }
    }
}
