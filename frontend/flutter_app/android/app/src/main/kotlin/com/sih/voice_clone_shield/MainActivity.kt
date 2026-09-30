package com.sih.voice_clone_shield

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.sih.voice_clone_shield/native"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    // Implementation for starting the foreground service
                    result.success("Service started")
                }
                "checkOverlayPermission" -> {
                    // Implementation for SYSTEM_ALERT_WINDOW check
                    result.success(true)
                }
                "getTelephonyState" -> {
                    // Implementation for READ_PHONE_STATE check
                    result.success("IDLE")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
