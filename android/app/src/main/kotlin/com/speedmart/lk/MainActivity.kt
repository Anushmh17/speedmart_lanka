package com.speedmart.lk

import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.speedmart.lk/system_ui"
    private var insetsController: WindowInsetsControllerCompat? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        insetsController = WindowInsetsControllerCompat(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        // Re-hide nav bar every time Android applies new insets (e.g. after IME hide)
        window.decorView.setOnApplyWindowInsetsListener { view, insets ->
            val result = view.onApplyWindowInsets(insets)
            val navVisible = WindowInsetsCompat.toWindowInsetsCompat(insets)
                .isVisible(WindowInsetsCompat.Type.navigationBars())
            val imeVisible = WindowInsetsCompat.toWindowInsetsCompat(insets)
                .isVisible(WindowInsetsCompat.Type.ime())
            if (navVisible && !imeVisible) {
                // Nav bar was re-shown by Android (not by keyboard) — hide it again
                insetsController?.hide(WindowInsetsCompat.Type.navigationBars())
            }
            result
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "hideNavBar") {
                    hideNavBar()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideNavBar()
    }

    private fun hideNavBar() {
        insetsController?.hide(WindowInsetsCompat.Type.navigationBars())
    }
}
