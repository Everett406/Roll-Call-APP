package com.example.roll_call_app

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.roll_call_app/update"
    private var downloadId: Long = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadAndInstall" -> {
                    val url = call.argument<String>("url") ?: ""
                    val title = call.argument<String>("title") ?: "下载更新"
                    downloadAndInstall(url, title, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun downloadAndInstall(url: String, title: String, result: MethodChannel.Result) {
        try {
            val request = DownloadManager.Request(Uri.parse(url))
            request.setTitle(title)
            request.setDescription("正在下载更新包...")
            request.setMimeType("application/vnd.android.package-archive")
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)

            // Android 10+ 使用应用专属目录
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                request.setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "update.apk")
            } else {
                request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "roll_call_update.apk")
            }

            val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            downloadId = dm.enqueue(request)

            // 注册下载完成广播
            val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
            registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
                    if (id == downloadId) {
                        // 下载完成，触发安装
                        installApk(dm, id)
                        context.unregisterReceiver(this)
                    }
                }
            }, filter)

            result.success(true)
        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message, null)
        }
    }

    private fun installApk(dm: DownloadManager, id: Long) {
        try {
            val query = DownloadManager.Query().setFilterById(id)
            val cursor = dm.query(query)
            if (cursor.moveToFirst()) {
                val uriIndex = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI)
                val uriString = cursor.getString(uriIndex)
                cursor.close()

                val intent = Intent(Intent.ACTION_VIEW)
                intent.setDataAndType(Uri.parse(uriString), "application/vnd.android.package-archive")
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } else {
                cursor.close()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
