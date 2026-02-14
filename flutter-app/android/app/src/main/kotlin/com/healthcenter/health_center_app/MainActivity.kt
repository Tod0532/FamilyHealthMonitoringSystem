package com.healthcenter.health_center_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 确保通知服务在应用启动时被正确初始化
        // Flutter 侧的 ReminderService 会处理通知调度
    }

    override fun onResume() {
        super.onResume()
        // 应用从后台恢复时，确保通知权限仍然有效
    }
}
