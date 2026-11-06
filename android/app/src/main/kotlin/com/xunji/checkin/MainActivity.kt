package com.xunji.checkin

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.hardware.display.DisplayManager
import android.net.Uri
import android.os.Build
import android.view.Display
import android.os.PowerManager
import android.provider.DocumentsContract
import android.provider.Settings
import com.xunji.checkin.reminder.ReminderScheduler
import com.xunji.checkin.widget.CheckinWidgetProvider
import com.xunji.checkin.widget.HeatmapWidgetProvider
import com.xunji.checkin.widget.WidgetRenderer
import com.xunji.checkin.widget.WidgetUpdateScheduler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import android.app.LocaleManager
import android.os.LocaleList
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets

/**
 * Flutter 与 Android 原生之间唯一的桥。
 *
 * 职责：
 * 1. 刷新桌面卡片（显式广播，兼容部分国产桌面）；
 * 2. 查询桌面是否支持一键添加；
 * 3. 查询/打开电池优化设置（不申请任何权限）；
 * 4. 打开自启动管理页，失败回退应用详情；
 * 5. 通过 SAF 导出 JSON（不申请存储权限）；
 * 6. 返回厂商名，供设置页展示针对性引导。
 *
 * 这里没有网络、存储、定位、开机广播、精确闹钟权限。
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.xunji.checkin/platform"
    private var pendingExport: MethodChannel.Result? = null
    private var pendingExportJson: String? = null
    private var pendingImport: MethodChannel.Result? = null
    private var pendingDirectory: MethodChannel.Result? = null
    private var pendingImage: MethodChannel.Result? = null
    private var pendingImageBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setLanguage" -> {
                        applyAppLanguage(
                            call.argument<String>("language") ?: "system",
                        )
                        result.success(true)
                    }

                    "refreshWidgets" -> {
                        WidgetUpdateScheduler.refreshAll(this)
                        result.success(true)
                    }

                    "isRequestPinSupported" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        result.success(
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                manager.isRequestPinAppWidgetSupported
                        )
                    }

                    "isIgnoringBatteryOptimizations" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }

                    "openBatteryOptimizationSettings" -> {
                        result.success(openBatterySettings())
                    }

                    "openAutoStartSettings" -> {
                        result.success(openAutoStartSettings())
                    }

                    "openAppSettings" -> {
                        result.success(openAppSettings())
                    }

                    "openEmail" -> {
                        result.success(
                            openEmail(call.argument<String>("email").orEmpty())
                        )
                    }

                    "exportJson" -> exportJson(call, result)
                    "importJson" -> importJson(result)
                    "chooseBackupDirectory" -> chooseBackupDirectory(result)
                    "writeBackup" -> writeBackup(call, result)
                    "pruneBackups" -> pruneBackups(call, result)
                    "saveImage" -> saveImage(call, result)

                    "syncReminders" -> {
                        val reminders = call.argument<List<Map<String, Any?>>>("reminders")
                            ?: emptyList()
                        ReminderScheduler.ensureChannel(this)
                        ReminderScheduler.sync(this, reminders)
                        result.success(true)
                    }

                    "areNotificationsEnabled" -> {
                        val manager = getSystemService(NOTIFICATION_SERVICE)
                            as NotificationManager
                        result.success(manager.areNotificationsEnabled())
                    }

                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_REQUEST_CODE,
                            )
                        }
                        result.success(true)
                    }

                    "deviceBrand" -> result.success(Build.MANUFACTURER ?: "")

                    else -> result.notImplemented()
                }
            }
    }

    // ---------------------------------------------------------------------
    // 设置页入口
    // ---------------------------------------------------------------------

    private fun openBatterySettings(): Boolean {
        return try {
            // 只跳系统设置页，不调用 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS，
            // 因此不需要申请任何权限。
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        } catch (_: Exception) {
            openAppSettings()
        }
    }

    private fun openAppSettings(): Boolean {
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openEmail(email: String): Boolean {
        if (email.isBlank()) return false
        return try {
            // mailto 只填充收件人；不代写正文、不读取任何本地数据。
            startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$email")))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 常见国产 ROM 的自启动管理页。组件名不存在时抛
     * ActivityNotFoundException，继续尝试下一个，最后回退应用详情。
     * 这些页面都由系统/安全中心提供，不需要额外权限。
     */
    private fun openAutoStartSettings(): Boolean {
        val candidates = listOf(
            // 小米 / Redmi
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            ),
            // 华为
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            ),
            // 荣耀
            ComponentName(
                "com.hihonor.systemmanager",
                "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            ),
            // OPPO / realme
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.startupapp.StartupAppListActivity"
            ),
            ComponentName(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity"
            ),
            // vivo / iQOO
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
            ),
            // 一加
            ComponentName(
                "com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
            ),
            // 魅族
            ComponentName(
                "com.meizu.safe",
                "com.meizu.safe.security.SecureSafeMainActivity"
            ),
            // 三星
            ComponentName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            ),
        )

        for (component in candidates) {
            try {
                startActivity(
                    Intent().apply {
                        this.component = component
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
                return true
            } catch (_: Exception) {
                // 当前 ROM 没有这个页面，继续尝试。
            }
        }
        return openAppSettings()
    }

    // ---------------------------------------------------------------------
    // SAF JSON 导出
    // ---------------------------------------------------------------------

    /**
     * Android 13+ 的 per-app language。切换后系统会重建 Activity，
     * 应用名、通知渠道、桌面小组件资源都跟着 App 语言走，而不是系统语言。
     * Android 8–12 没有该 API，保留系统语言资源兜底。
     */
    private fun applyAppLanguage(code: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val localeManager = getSystemService(LocaleManager::class.java) ?: return
        localeManager.applicationLocales =
            if (code == "system" || code.isBlank()) {
                LocaleList.getEmptyLocaleList()
            } else {
                LocaleList.forLanguageTags(code)
            }
    }

    private fun exportJson(call: MethodCall, result: MethodChannel.Result) {
        if (pendingExport != null) {
            result.error("busy", "已有导出任务正在进行", null)
            return
        }

        val json = call.argument<String>("json")
        if (json.isNullOrEmpty()) {
            result.error("empty_json", "导出内容为空", null)
            return
        }
        val fileName = call.argument<String>("fileName") ?: "xunji-checkin.json"
        val mimeType = call.argument<String>("mimeType") ?: "application/json"

        pendingExport = result
        pendingExportJson = json

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, EXPORT_REQUEST_CODE)
        } catch (error: Exception) {
            pendingExport = null
            pendingExportJson = null
            result.error("no_picker", error.message ?: "无法打开系统文件选择器", null)
        }
    }

    // ---------------------------------------------------------------------
    // 自动备份：用户通过 SAF 选择一个长期目录，之后定时写入并清理旧文件。
    // 目录授权会持久化；不申请存储权限。
    // ---------------------------------------------------------------------

    private fun chooseBackupDirectory(result: MethodChannel.Result) {
        if (pendingDirectory != null) {
            result.error("busy", "已有目录选择任务正在进行", null)
            return
        }
        pendingDirectory = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        try {
            startActivityForResult(intent, DIRECTORY_REQUEST_CODE)
        } catch (error: Exception) {
            pendingDirectory = null
            result.error("no_picker", error.message ?: "无法打开目录选择器", null)
        }
    }

    private fun writeBackup(call: MethodCall, result: MethodChannel.Result) {
        val dirUri = call.argument<String>("dirUri")
        val fileName = call.argument<String>("fileName")
        val json = call.argument<String>("json")
        if (dirUri.isNullOrEmpty() || fileName.isNullOrEmpty() || json.isNullOrEmpty()) {
            result.error("empty_backup", "备份参数不完整", null)
            return
        }
        Thread {
            try {
                val tree = Uri.parse(dirUri)
                val parent = DocumentsContract.buildDocumentUriUsingTree(
                    tree,
                    DocumentsContract.getTreeDocumentId(tree)
                )
                val document = DocumentsContract.createDocument(
                    contentResolver,
                    parent,
                    "application/json",
                    fileName
                ) ?: throw IllegalStateException("无法创建备份文件")
                contentResolver.openOutputStream(document, "wt")?.use { stream ->
                    stream.write(json.toByteArray(StandardCharsets.UTF_8))
                    stream.flush()
                } ?: throw IllegalStateException("文件流打开失败")
                runOnUiThread { result.success(document.toString()) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("backup_failed", error.message ?: "写入失败", null)
                }
            }
        }.start()
    }

    private fun pruneBackups(call: MethodCall, result: MethodChannel.Result) {
        val dirUri = call.argument<String>("dirUri")
        val keep = call.argument<Int>("keep") ?: 10
        if (dirUri.isNullOrEmpty()) {
            result.success(0)
            return
        }
        Thread {
            var deleted = 0
            try {
                val tree = Uri.parse(dirUri)
                val children = DocumentsContract.buildChildDocumentsUriUsingTree(
                    tree,
                    DocumentsContract.getTreeDocumentId(tree)
                )
                val files = mutableListOf<Triple<String, String, Long>>()
                contentResolver.query(
                    children,
                    arrayOf(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                        DocumentsContract.Document.COLUMN_LAST_MODIFIED
                    ),
                    null,
                    null,
                    null
                )?.use { cursor: Cursor ->
                    while (cursor.moveToNext()) {
                        val name = cursor.getString(1) ?: continue
                        if (!name.startsWith("xunji-auto-")) continue
                        files += Triple(
                            cursor.getString(0),
                            name,
                            cursor.getLong(2)
                        )
                    }
                }
                files.sortByDescending { it.third }
                for (old in files.drop(keep.coerceAtLeast(1))) {
                    val document = DocumentsContract.buildDocumentUriUsingTree(
                        tree,
                        old.first
                    )
                    if (DocumentsContract.deleteDocument(contentResolver, document)) {
                        deleted++
                    }
                }
                runOnUiThread { result.success(deleted) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("prune_failed", error.message ?: "清理失败", null)
                }
            }
        }.start()
    }

    private fun handleDirectoryResult(resultCode: Int, data: Intent?) {
        val result = pendingDirectory ?: return
        pendingDirectory = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.error("no_uri", "没有拿到目录位置", null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: SecurityException) {
            // 个别 ROM 不允许持久化；本次仍可写入，下次重新选择即可。
        }
        result.success(uri.toString())
    }

    private fun saveImage(call: MethodCall, result: MethodChannel.Result) {
        if (pendingImage != null) {
            result.error("busy", "已有图片保存任务正在进行", null)
            return
        }
        val bytes = call.argument<ByteArray>("bytes")
        val fileName = call.argument<String>("fileName") ?: "xunji-heatmap.png"
        if (bytes == null || bytes.isEmpty()) {
            result.error("empty_image", "图片内容为空", null)
            return
        }
        pendingImage = result
        pendingImageBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/png"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, IMAGE_REQUEST_CODE)
        } catch (error: Exception) {
            pendingImage = null
            pendingImageBytes = null
            result.error("no_picker", error.message ?: "无法打开系统文件选择器", null)
        }
    }

    private fun handleImageResult(resultCode: Int, data: Intent?) {
        val result = pendingImage ?: return
        val bytes = pendingImageBytes
        pendingImage = null
        pendingImageBytes = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null || bytes == null) {
            result.error("no_uri", "没有拿到可写入的文件位置", null)
            return
        }
        Thread {
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                } ?: throw IllegalStateException("文件流打开失败")
                runOnUiThread { result.success(uri.toString()) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("image_failed", error.message ?: "保存失败", null)
                }
            }
        }.start()
    }

    private fun importJson(result: MethodChannel.Result) {
        if (pendingImport != null) {
            result.error("busy", "已有导入任务正在进行", null)
            return
        }
        pendingImport = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
        }
        try {
            startActivityForResult(intent, IMPORT_REQUEST_CODE)
        } catch (error: Exception) {
            pendingImport = null
            result.error("no_picker", error.message ?: "无法打开系统文件选择器", null)
        }
    }

    @Deprecated("FlutterActivity 仍通过 onActivityResult 返回 SAF 结果")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            EXPORT_REQUEST_CODE -> handleExportResult(resultCode, data)
            IMPORT_REQUEST_CODE -> handleImportResult(resultCode, data)
            DIRECTORY_REQUEST_CODE -> handleDirectoryResult(resultCode, data)
            IMAGE_REQUEST_CODE -> handleImageResult(resultCode, data)
        }
    }

    private fun handleExportResult(resultCode: Int, data: Intent?) {
        val result = pendingExport ?: return
        val json = pendingExportJson
        pendingExport = null
        pendingExportJson = null

        if (resultCode != Activity.RESULT_OK) {
            // 用户取消不是错误，Flutter 侧据此提示“已取消”。
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null || json == null) {
            result.error("no_uri", "没有拿到可写入的文件位置", null)
            return
        }

        // JSON 很小，但仍然放到后台线程写，避免阻塞 UI。
        Thread {
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                    stream.write(json.toByteArray(StandardCharsets.UTF_8))
                    stream.flush()
                } ?: throw IllegalStateException("文件流打开失败")
                runOnUiThread { result.success(uri.toString()) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("export_failed", error.message ?: "写入失败", null)
                }
            }
        }.start()
    }

    private fun handleImportResult(resultCode: Int, data: Intent?) {
        val result = pendingImport ?: return
        pendingImport = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.error("no_uri", "没有拿到可读取的文件位置", null)
            return
        }
        Thread {
            try {
                val text = contentResolver.openInputStream(uri)?.use { stream ->
                    val bytes = stream.readBytes()
                    if (bytes.size > MAX_IMPORT_BYTES) {
                        throw IllegalStateException("备份文件过大")
                    }
                    String(bytes, StandardCharsets.UTF_8)
                } ?: throw IllegalStateException("文件流打开失败")
                runOnUiThread { result.success(text) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("import_failed", error.message ?: "读取失败", null)
                }
            }
        }.start()
    }

    /**
     * 尽量选择与当前分辨率一致的最高刷新率模式。
     *
     * 部分高刷屏默认给普通应用 60Hz，只声明支持并不会自动切到 120/144/180Hz；
     * 这里在 Activity 创建时显式请求 Display 支持的最高模式。若高刷模式只
     * 存在于更低分辨率，则保留系统当前模式，避免为了刷新率牺牲清晰度。
     */
    private fun applyMaxRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        runCatching {
            val manager = getSystemService(DisplayManager::class.java)
            val display = manager.getDisplay(Display.DEFAULT_DISPLAY) ?: return
            val current = display.mode ?: return
            val sameResolution = display.supportedModes.filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            val best = sameResolution.maxByOrNull { it.refreshRate } ?: return
            if (best.modeId != current.modeId) {
                window.attributes = window.attributes.apply {
                    preferredDisplayModeId = best.modeId
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        applyMaxRefreshRate()
        // App 启动时重新安排下一次零点刷新；不申请开机广播，重启后
        // 打开一次 App 就能恢复。
        WidgetUpdateScheduler.scheduleNext(this)
        // 仅调试包：一次性渲染全部尺寸的桌面卡片，供真机像素级验收。
        val debuggable = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (debuggable) {
            renderDebugWidgetSamples()
        }
    }

    private fun renderDebugWidgetSamples() {
        val dir = java.io.File(filesDir, "widget_samples").apply { mkdirs() }
        val tasks = org.json.JSONArray()
        val titles = listOf("早起喝水", "阅读 20 分钟", "运动打卡", "冥想", "整理书桌", "给家里打电话", "写日报")
        titles.forEachIndexed { i, title ->
            tasks.put(
                org.json.JSONObject()
                    .put("id", i + 1)
                    .put("title", title)
                    .put("type", if (i == 5) "todo" else "daily")
                    .put("done", i < 3)
            )
        }
        val checkin = org.json.JSONObject()
            .put("date", "2026-11-06")
            .put("date_label", "11月6日 · 星期五")
            .put("total", 7).put("done", 3).put("percent", 43)
            .put("hue", 220).put("dark", true).put("lang", "zh")
            .put("tasks", tasks)
            .toString()

        val days = org.json.JSONArray()
        for (i in 0 until 56) {
            days.put(
                org.json.JSONObject()
                    .put("date", "2026-09-%02d".format((i % 28) + 1))
                    .put("total", 5).put("done", (i * 3) % 6)
                    .put("rate", ((i * 3) % 6) / 5.0)
            )
        }
        val heatmap = org.json.JSONObject()
            .put("today", "2026-11-06").put("hue", 220).put("dark", true)
            .put("average", 0.62).put("lang", "zh").put("days", days).toString()

        fun save(name: String, bitmap: android.graphics.Bitmap) {
            java.io.FileOutputStream(java.io.File(dir, "$name.png")).use {
                bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)
            }
            bitmap.recycle()
        }
        val checkinSizes = listOf("2x1" to (180 to 90), "2x2" to (180 to 180), "4x2" to (360 to 180), "4x4" to (360 to 360))
        checkinSizes.forEach { (name, size) ->
            save("checkin_$name", WidgetRenderer.renderCheckin(this, size.first, size.second, checkin))
        }
        val heatSizes = listOf("2x2" to (180 to 180), "4x2" to (360 to 180), "4x4" to (360 to 360))
        heatSizes.forEach { (name, size) ->
            save("heatmap_$name", WidgetRenderer.renderHeatmap(this, size.first, size.second, heatmap))
        }
        val mini = org.json.JSONObject().put("percent", 43).put("hue", 220).put("dark", true).put("lang", "zh").toString()
        save("mini_1x1", WidgetRenderer.renderMini(this, 90, 90, mini))
    }

    override fun onResume() {
        super.onResume()
        // 从后台回到前台时补一次显式刷新，避免桌面宿主缓存旧 Bitmap。
        WidgetUpdateScheduler.refreshAll(this)
        WidgetUpdateScheduler.scheduleNext(this)
    }

    /** 仅供 WidgetUpdateScheduler 使用，避免重复写 ComponentName。 */
    companion object {
        private const val EXPORT_REQUEST_CODE = 4101
        private const val IMPORT_REQUEST_CODE = 4102
        private const val NOTIFICATION_REQUEST_CODE = 4103
        private const val DIRECTORY_REQUEST_CODE = 4104
        private const val IMAGE_REQUEST_CODE = 4105
        private const val MAX_IMPORT_BYTES = 8 * 1024 * 1024

        fun providerComponents(): List<ComponentName> = listOf(
            ComponentName(
                "com.xunji.checkin",
                CheckinWidgetProvider::class.java.name
            ),
            ComponentName(
                "com.xunji.checkin",
                HeatmapWidgetProvider::class.java.name
            )
        )
    }
}
