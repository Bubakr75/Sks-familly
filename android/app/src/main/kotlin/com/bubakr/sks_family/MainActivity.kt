package com.bubakr.sks_family

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sks.family/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTV") {
                    // Method 1: UiModeManager
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    val isTvMode = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION

                    // Method 2: ro.build.characteristics
                    val characteristics = try {
                        Build::class.java.getMethod("getString", String::class.java)
                            ?.invoke(null, "ro.build.characteristics") as? String ?: ""
                    } catch (e: Exception) {
                        try {
                            Runtime.getRuntime().exec("getprop ro.build.characteristics")
                                .inputStream.bufferedReader().readLine() ?: ""
                        } catch (e2: Exception) { "" }
                    }
                    val isTvBuild = characteristics.contains("tv", ignoreCase = true)

                    // Method 3: Leanback feature
                    val hasLeanback = packageManager.hasSystemFeature("android.software.leanback")

                    val isTV = isTvMode || isTvBuild || hasLeanback
                    android.util.Log.d("TVDetector", "isTvMode=$isTvMode isTvBuild=$isTvBuild hasLeanback=$hasLeanback => isTV=$isTV")
                    result.success(isTV)
                } else {
                    result.notImplemented()
                }
            }
    }
}
