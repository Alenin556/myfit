package com.example.myfit

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.myfit/app_icon"
    private val aliasLight: ComponentName
        get() = ComponentName(this, "com.example.myfit.IconAliasLight")
    private val aliasDark: ComponentName
        get() = ComponentName(this, "com.example.myfit.IconAliasDark")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel,
        ).setMethodCallHandler { call, result ->
            if (call.method == "setIcon") {
                val map = call.arguments as? Map<*, *>
                val variant = map?.get("variant") as? String ?: "light"
                setLauncherIcon(useDark = variant == "dark")
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setLauncherIcon(useDark: Boolean) {
        val pm = packageManager
        val (enable, disable) = if (useDark) {
            aliasDark to aliasLight
        } else {
            aliasLight to aliasDark
        }
        pm.setComponentEnabledSetting(
            enable,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        pm.setComponentEnabledSetting(
            disable,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
