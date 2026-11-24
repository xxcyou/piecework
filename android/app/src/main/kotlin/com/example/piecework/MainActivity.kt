package com.example.piecework

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 公共目录（/storage/emulated/0/...）读写桥。
 *
 * Android 10+ 不允许 App 直接按路径写公共目录，正规做法是让用户用系统
 * 文件选择器授权一个文件夹（SAF），App 拿到**持久化**的 URI 权限后，
 * 以后就能一直往那个文件夹里写文件 —— 这就是「先获取访问权限」。
 *
 * 对外方法（Dart 侧见 lib/data/services/public_folder.dart）：
 *   pickFolder()                  → {uri, label} | null
 *   hasPermission(uri)            → bool
 *   writeFile(uri, name, bytes)   → name
 *   listFiles(uri, prefix)        → [{name, size, modified}]
 *   readFile(uri, name)           → ByteArray
 *   deleteFile(uri, name)         → bool
 */
class MainActivity : FlutterActivity() {

    private val channelName = "piecework/public_storage"

    companion object {
        const val ACTION_INSTALL_RESULT = "com.example.piecework.INSTALL_RESULT"
    }
    private val requestPickFolder = 4711
    private var pendingPick: MethodChannel.Result? = null

    /**
     * 安装下载好的 APK，返回 {ok, via, error} 给 Dart 看。
     *
     * 三条路依次试，每一步都写 logcat（tag=piecework.install）：
     * 1) FileProvider + ACTION_VIEW —— 系统安装器直接弹
     * 2) PackageInstaller + 结果广播 —— 某些 ROM 不会自动弹安装界面，
     *    必须收到 STATUS_PENDING_USER_ACTION 后自己 startActivity(EXTRA_INTENT)；
     *    以前没接这个广播，表现就是「点了没反应」
     * 3) 都失败 → 把真实异常回给 Dart
     */
    private fun installApk(path: String, result: MethodChannel.Result) {
        val file = java.io.File(path)
        if (path.isEmpty() || !file.exists()) {
            result.success(mapOf("ok" to false, "via" to "none", "error" to "安装包不存在"))
            return
        }
        android.util.Log.i("piecework.install", "start path=$path size=${file.length()}")

        // 1) PackageInstaller 会话 —— 系统自己的安装流程，不依赖「谁被设成默认安装器」。
        //    关键：结果广播里 STATUS_PENDING_USER_ACTION 要自己 startActivity（见下方 Receiver），
        //    以前没接，表现就是「点了没反应」。
        try {
            val params = android.content.pm.PackageInstaller.SessionParams(
                android.content.pm.PackageInstaller.SessionParams.MODE_FULL_INSTALL,
            )
            val installer = packageManager.packageInstaller
            val sessionId = installer.createSession(params)
            installer.openSession(sessionId).use { session ->
                file.inputStream().use { input ->
                    session.openWrite("piecework.apk", 0, file.length()).use { out ->
                        input.copyTo(out)
                        session.fsync(out)
                    }
                }
                val intent = android.content.Intent(ACTION_INSTALL_RESULT)
                    .setPackage(packageName)
                val flags = if (android.os.Build.VERSION.SDK_INT >= 31) {
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_MUTABLE
                } else {
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pi = android.app.PendingIntent.getBroadcast(this, sessionId, intent, flags)
                session.commit(pi.intentSender)
            }
            android.util.Log.i("piecework.install", "PackageInstaller committed")
            result.success(mapOf("ok" to true, "via" to "session", "error" to ""))
            return
        } catch (e: Exception) {
            android.util.Log.i("piecework.install", "PackageInstaller failed: ${e.message}")
        }

        // 2) 兜底：FileProvider + ACTION_VIEW
        try {
            val uri = androidx.core.content.FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val handlers = packageManager.queryIntentActivities(intent, 0)
            android.util.Log.i("piecework.install", "ACTION_VIEW handlers=${handlers.size}")
            if (handlers.isNotEmpty()) {
                startActivity(intent)
                result.success(mapOf("ok" to true, "via" to "intent", "error" to ""))
                return
            }
            result.success(
                mapOf("ok" to false, "via" to "intent", "error" to "没有安装器能处理这个安装包"),
            )
        } catch (e: Exception) {
            android.util.Log.i("piecework.install", "ACTION_VIEW failed: ${e.message}")
            result.success(
                mapOf(
                    "ok" to false,
                    "via" to "intent",
                    "error" to (e.message ?: e.javaClass.simpleName),
                ),
            )
        }
    }

    /** 打开「安装未知应用」设置页（Dart 侧按钮用） */
    private fun openInstallSettings(result: MethodChannel.Result) {
        try {
            startActivity(
                android.content.Intent(
                    android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    android.net.Uri.parse("package:$packageName"),
                ),
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("no_settings", e.message, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installApk" -> {
                            // 应用内自动更新：把下载好的 APK 交给系统安装器
                            installApk(call.argument<String>("path") ?: "", result)
                        }
                        "openInstallSettings" -> openInstallSettings(result)
                        "deviceId" -> {
                            // 设备码来源：Android ID（卸载重装不变，刷机/换机会变）
                            val id = android.provider.Settings.Secure.getString(
                                contentResolver,
                                android.provider.Settings.Secure.ANDROID_ID,
                            ) ?: ""
                            result.success(id)
                        }
                        "openUrl" -> {
                            // 用系统浏览器打开链接（更新下载 / 项目主页）
                            val url = call.argument<String>("url") ?: ""
                            if (url.isEmpty()) {
                                result.error("empty", "url 为空", null)
                            } else {
                                startActivity(
                                    android.content.Intent(
                                        android.content.Intent.ACTION_VIEW,
                                        android.net.Uri.parse(url),
                                    ),
                                )
                                result.success(true)
                            }
                        }
                        "nativeLibDir" -> {
                            // proot 的可执行文件放在 nativeLibraryDir（lib*.so）
                            result.success(applicationInfo.nativeLibraryDir)
                        }
                        "pickFolder" -> pickFolder(result)
                        "hasPermission" -> {
                            val uri = Uri.parse(call.argument<String>("uri"))
                            result.success(hasWritePermission(uri))
                        }
                        "writeFile" -> {
                            val uri = Uri.parse(call.argument<String>("uri"))
                            val name = call.argument<String>("name")!!
                            val bytes = call.argument<ByteArray>("bytes")!!
                            writeFile(uri, name, bytes)
                            result.success(name)
                        }
                        "listFiles" -> {
                            val uri = Uri.parse(call.argument<String>("uri"))
                            val prefix = call.argument<String>("prefix") ?: ""
                            result.success(listFiles(uri, prefix))
                        }
                        "readFile" -> {
                            val uri = Uri.parse(call.argument<String>("uri"))
                            val name = call.argument<String>("name")!!
                            result.success(readFile(uri, name))
                        }
                        "deleteFile" -> {
                            val uri = Uri.parse(call.argument<String>("uri"))
                            val name = call.argument<String>("name")!!
                            result.success(deleteFile(uri, name))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("storage_error", e.message ?: e.toString(), null)
                }
            }
    }

    // ───────────────────────── 选择目录 ─────────────────────────

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "已经有一个选择框在等着了", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        startActivityForResult(intent, requestPickFolder)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == requestPickFolder) {
            val result = pendingPick
            pendingPick = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result?.success(null)
                return
            }
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (e: SecurityException) {
                result?.error("permission", "授权失败：${e.message}", null)
                return
            }
            result?.success(
                mapOf(
                    "uri" to uri.toString(),
                    "label" to folderLabel(uri)
                )
            )
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun folderLabel(uri: Uri): String {
        val docId = try {
            DocumentsContract.getTreeDocumentId(uri)
        } catch (e: Exception) {
            return uri.lastPathSegment ?: "已授权目录"
        }
        val parts = docId.split(":")
        val tail = parts.getOrNull(1)?.trim('/') ?: ""
        if (tail.isEmpty()) {
            return if (docId.startsWith("primary")) "内部存储根目录" else docId
        }
        return tail.substringAfterLast('/')
    }

    // ───────────────────────── 权限 ─────────────────────────

    private fun hasWritePermission(uri: Uri): Boolean {
        return contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isWritePermission
        }
    }

    // ───────────────────────── 文件操作 ─────────────────────────

    private fun treeDocumentUri(uri: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            uri,
            DocumentsContract.getTreeDocumentId(uri)
        )

    private fun childrenUri(uri: Uri): Uri =
        DocumentsContract.buildChildDocumentsUriUsingTree(
            uri,
            DocumentsContract.getTreeDocumentId(uri)
        )

    private data class Child(
        val docId: String,
        val name: String,
        val size: Long,
        val modified: Long
    )

    private fun listChildren(uri: Uri): List<Child> {
        val out = ArrayList<Child>()
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED
        )
        contentResolver.query(childrenUri(uri), projection, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    Child(
                        docId = c.getString(0),
                        name = c.getString(1) ?: "",
                        size = if (c.isNull(2)) 0L else c.getLong(2),
                        modified = if (c.isNull(3)) 0L else c.getLong(3)
                    )
                )
            }
        }
        return out
    }

    private fun findChild(uri: Uri, name: String): Child? =
        listChildren(uri).firstOrNull { it.name == name }

    private fun listFiles(uri: Uri, prefix: String): List<Map<String, Any>> =
        listChildren(uri)
            .filter { it.name.startsWith(prefix) }
            .map {
                mapOf(
                    "name" to it.name,
                    "size" to it.size,
                    "modified" to it.modified
                )
            }

    private fun writeFile(uri: Uri, name: String, bytes: ByteArray) {
        // 同名先删，避免 createDocument 自动加 (1) 后缀
        findChild(uri, name)?.let { old ->
            DocumentsContract.deleteDocument(
                contentResolver,
                DocumentsContract.buildDocumentUriUsingTree(uri, old.docId)
            )
        }
        val created = DocumentsContract.createDocument(
            contentResolver,
            treeDocumentUri(uri),
            "application/octet-stream",
            name
        ) ?: throw IllegalStateException("创建文件失败：$name")

        contentResolver.openOutputStream(created, "wt")?.use { it.write(bytes) }
            ?: throw IllegalStateException("打不开写入流：$name")
    }

    private fun readFile(uri: Uri, name: String): ByteArray {
        val child = findChild(uri, name)
            ?: throw IllegalStateException("文件不存在：$name")
        val docUri = DocumentsContract.buildDocumentUriUsingTree(uri, child.docId)
        return contentResolver.openInputStream(docUri)?.use { it.readBytes() }
            ?: throw IllegalStateException("打不开读取流：$name")
    }

    private fun deleteFile(uri: Uri, name: String): Boolean {
        val child = findChild(uri, name) ?: return false
        return DocumentsContract.deleteDocument(
            contentResolver,
            DocumentsContract.buildDocumentUriUsingTree(uri, child.docId)
        )
    }
}

/**
 * 安装结果广播：必须处理 STATUS_PENDING_USER_ACTION —— 这时系统把「安装确认界面」
 * 放在 EXTRA_INTENT 里，要我们自己 startActivity 才会弹出来。
 */
class InstallResultReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: android.content.Context, intent: android.content.Intent) {
        val status = intent.getIntExtra(
            android.content.pm.PackageInstaller.EXTRA_STATUS,
            android.content.pm.PackageInstaller.STATUS_FAILURE,
        )
        val msg = intent.getStringExtra(android.content.pm.PackageInstaller.EXTRA_STATUS_MESSAGE)
        android.util.Log.i("piecework.install", "result status=$status msg=$msg")
        when (status) {
            android.content.pm.PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = intent.getParcelableExtra<android.content.Intent>(
                    android.content.Intent.EXTRA_INTENT,
                )
                confirm?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                if (confirm != null) {
                    try {
                        context.startActivity(confirm)
                        android.util.Log.i("piecework.install", "started confirm activity")
                    } catch (e: Exception) {
                        android.util.Log.i("piecework.install", "confirm failed: ${e.message}")
                    }
                }
            }
        }
    }
}
