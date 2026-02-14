package com.healthcenter.health_center_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

/**
 * 启动完成后重新安排通知的 BroadcastReceiver
 * 当设备重启或快速启动时，系统会发送 BOOT_COMPLETED 广播
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val action = intent.action
        Log.d(TAG, "Received broadcast: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON") {

            Log.d(TAG, "Device boot completed, rescheduling notifications...")

            // 检查通知权限
            val notificationManager = NotificationManagerCompat.from(context)
            if (notificationManager.areNotificationsEnabled()) {
                Log.d(TAG, "Notifications are enabled")

                // 启动 Flutter 应用以重新安排通知
                // Flutter 应用的 main 函数会被调用，ReminderService 会自动加载并重新安排通知
                val packageManager = context.packageManager
                val launchIntent = packageManager.getLaunchIntentForPackage(context.packageName)

                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(launchIntent)
                    Log.d(TAG, "Launched app to reschedule notifications")
                } else {
                    Log.e(TAG, "Could not find launch intent for package")
                }
            } else {
                Log.w(TAG, "Notifications are disabled")
            }
        }
    }
}
