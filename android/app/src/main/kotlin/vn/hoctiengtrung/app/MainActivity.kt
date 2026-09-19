package vn.hoctiengtrung.app

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Khớp với ExportService.nativeChannel bên Dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.hoctiengtrung.app/export")
            .setMethodCallHandler { call, result ->
                if (call.method != "exportFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes")
                val share = call.argument<Boolean>("share") ?: false
                if (name == null || bytes == null) {
                    result.error("ARGS", "Thiếu tên file hoặc dữ liệu", null)
                    return@setMethodCallHandler
                }
                // Android 10+ ghi vào Tải xuống qua MediaStore, không cần quyền bộ nhớ.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                try {
                    val (uri, savedName) = saveToDownloads(name, mime, bytes)
                    result.success(savedName)
                    if (share) shareFile(uri, mime)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }
    }

    private fun saveToDownloads(name: String, mime: String, bytes: ByteArray): Pair<Uri, String> {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Không tạo được file")
        resolver.openOutputStream(uri)?.use { it.write(bytes) }
            ?: throw IllegalStateException("Không ghi được file")
        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        // MediaStore có thể tự đổi tên nếu trùng, đọc lại tên thật
        var savedName = name
        resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) savedName = c.getString(0)
        }
        return Pair(uri, savedName)
    }

    private fun shareFile(uri: Uri, mime: String) {
        try {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(send, "Chia sẻ báo cáo"))
        } catch (e: Exception) {
            // Không có app nào nhận chia sẻ — file vẫn đã nằm trong Tải xuống.
        }
    }
}
