package com.linux.simplemathtester

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_math_tester/device_settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Android drops HapticFeedback when the phone's touch feedback is off.
                    "touchFeedbackEnabled" -> result.success(
                        Settings.System.getInt(contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) != 0
                    )
                    "openVibrationSettings" -> result.success(
                        openFirst(
                            Intent("android.settings.VIBRATION_SETTINGS"),
                            Intent().setComponent(ComponentName(
                                "com.android.settings",
                                "com.android.settings.Settings\$VibrationSettingsActivity"
                            )),
                            Intent(Settings.ACTION_SOUND_SETTINGS),
                            Intent(Settings.ACTION_SETTINGS),
                        )
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /** Starts the first intent that opens; startActivity is tried directly, since
     *  package visibility can hide settings screens from resolveActivity. */
    private fun openFirst(vararg intents: Intent): Boolean = intents.any {
        try {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }
}
