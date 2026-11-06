package com.xunji.checkin.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * 桌面卡片渲染器。
 *
 * 为什么用整张 Bitmap 而不是 RemoteViews 行布局：
 * - 尺寸跨度大（2×1 到 4×4），行布局很难同时保证不溢出；
 * - Canvas 可以精确控制文字截断、圆环、热力格；
 * - 整张卡片只有一个 ImageView，点击事件也最简单。
 *
 * 颜色算法与 App 的 AppTheme.heatColor 保持一致：
 * 固定色相，只让饱和度随完成率线性升高，100% 时拉满。
 *
 * 卡片只读：不响应任务点击，整张卡片点击由 Provider 设置的 PendingIntent
 * 打开 App，具体打卡仍在 App 内完成。
 */
object WidgetRenderer {

    private const val BG_DARK = 0xFF0B1220.toInt()
    private const val BG_LIGHT = 0xFFFFFFFF.toInt()
    private const val TEXT_DARK = 0xFFF1F5FF.toInt()
    private const val TEXT_LIGHT = 0xFF111827.toInt()

    private fun dateFormatter(lang: String): DateTimeFormatter {
        val locale = when (lang) {
            "en" -> Locale.ENGLISH
            "ja" -> Locale.JAPANESE
            "fr" -> Locale.FRENCH
            "es" -> Locale.forLanguageTag("es")
            else -> Locale.CHINA
        }
        val pattern = if (lang == "zh") "M月d日 · E" else "MMM d · E"
        return DateTimeFormatter.ofPattern(pattern, locale)
    }

    private data class WidgetStrings(
        val today: String,
        val todayCheckin: String,
        val noTasks: String,
        val notAdded: String,
        val todayNoTasks: String,
        val addPrompt: String,
        val footerIdle: String,
        val footerActive: String,
        val clickAdd: String,
        val recent4: String,
        val recent8: String,
        val monthAvg: String,
        val rateFade: String,
        val taskFallback: String,
    )

    private fun strings(lang: String): WidgetStrings = when (lang) {
        "en" -> WidgetStrings(
            "Today", "Today's check-in", "No tasks yet", "No tasks added",
            "No tasks today", "Tap the card to add today's tasks in the app",
            "A new day — open the app to begin", "Offline · tap to return to Today",
            "Tap the card to open the app", "Last 4 weeks", "Last 8 weeks",
            "Monthly avg ", "Lighter means lower completion", "Task",
        )
        "ja" -> WidgetStrings(
            "今日", "今日のチェックイン", "タスクはまだありません", "タスク未追加",
            "今日のタスクはありません", "カードをタップしてアプリで追加",
            "新しい一日。アプリで開始", "オフライン・タップで今日へ",
            "カードをタップしてアプリを開く", "直近4週間", "直近8週間",
            "月平均 ", "薄いほど達成率が低い", "タスク",
        )
        "fr" -> WidgetStrings(
            "Aujourd’hui", "Pointage du jour", "Aucune tâche", "Aucune tâche ajoutée",
            "Aucune tâche aujourd’hui", "Touchez la carte pour ajouter des tâches",
            "Nouveau jour — ouvrez l’app", "Hors ligne · toucher pour revenir",
            "Touchez la carte pour ouvrir l’app", "4 dernières semaines", "8 dernières semaines",
            "Moyenne ", "Plus clair = taux plus bas", "Tâche",
        )
        "es" -> WidgetStrings(
            "Hoy", "Registro de hoy", "Sin tareas", "Sin tareas añadidas",
            "Sin tareas hoy", "Toca la tarjeta para añadir tareas",
            "Nuevo día: abre la app", "Sin conexión · toca para volver",
            "Toca la tarjeta para abrir la app", "Últimas 4 semanas", "Últimas 8 semanas",
            "Media ", "Más claro = menor tasa", "Tarea",
        )
        else -> WidgetStrings(
            "今日", "今日打卡", "还没有任务", "还没添加任务",
            "今天还没有任务", "点击卡片，去 App 添加今日任务",
            "新的一天，打开 App 开始打卡", "纯离线 · 点击卡片回到今日",
            "点击卡片，打开 App", "最近 4 周", "最近 8 周",
            "月均 ", "完成率越低越淡", "任务",
        )
    }

    // ---------------------------------------------------------------------
    // 打卡任务卡片
    // ---------------------------------------------------------------------

    /**
     * 1×1 迷你卡片：只显示今日完成率，保持只读。
     * 不解析任务列表，避免小尺寸下文字溢出。
     */
    fun renderMini(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        rawJson: String?,
    ): Bitmap {
        val width = dp(context, widthDp.coerceAtLeast(48).toFloat())
        val height = dp(context, heightDp.coerceAtLeast(48).toFloat())
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val json = try {
            JSONObject(rawJson ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        val hue = json.optDouble("hue", 220.0)
        val dark = json.optBoolean("dark", true)
        val lang = json.optString("lang", "zh")
        val percent = json.optInt("percent", 0).coerceIn(0, 100)
        val palette = palette(hue.toFloat(), dark)
        drawCardBackground(canvas, width, height, palette)

        val center = width / 2f
        val ringRadius = min(width, height) * 0.34f
        val ringTop = height / 2f - ringRadius - height * 0.04f
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = width * 0.045f
            color = palette.track
        }
        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = width * 0.045f
            color = heatColor(hue.toFloat(), percent / 100.0, dark)
        }
        val oval = RectF(
            center - ringRadius,
            ringTop,
            center + ringRadius,
            ringTop + ringRadius * 2,
        )
        canvas.drawArc(oval, 0f, 360f, false, track)
        canvas.drawArc(oval, -90f, 360f * percent / 100f, false, arc)

        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.text
            textAlign = Paint.Align.CENTER
            textSize = width * 0.24f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.sub
            textAlign = Paint.Align.CENTER
            textSize = width * 0.11f
        }
        val baseY = ringTop + ringRadius + text.textSize * 0.34f
        canvas.drawText("$percent%", center, baseY, text)
        canvas.drawText(strings(lang).today, center, baseY + label.textSize * 1.5f, label)
        return bitmap
    }

    fun renderCheckin(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        rawJson: String?,
    ): Bitmap {
        val width = dp(context, widthDp.coerceAtLeast(70).toFloat())
        val height = dp(context, heightDp.coerceAtLeast(36).toFloat())
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val data = parseCheckin(rawJson)
        val palette = palette(data.hue, data.dark)
        drawCardBackground(canvas, width, height, palette)
        when {
            // 2×1 在部分 ROM 上会报到 70–100dp，按高度识别，
            // 只展示圆环和完成度，绝不渲染任务列表。
            heightDp < 100 -> drawCheckinStrip(context, canvas, width, height, data, palette)
            // 2×2 与 4×2 高度接近，按宽高比区分：
            // 2×2 只放圆环 + 3 条任务；4×2 放圆环 + 最多 6 条任务。
            heightDp < 215 && widthDp < heightDp * 1.4f ->
                drawCheckinCompact(context, canvas, width, height, data, palette)
            heightDp < 215 -> drawCheckinWide(context, canvas, width, height, data, palette)
            else -> drawCheckinFull(context, canvas, width, height, data, palette)
        }
        return bitmap
    }

    private fun drawCheckinStrip(
        context: Context,
        canvas: Canvas,
        width: Int,
        height: Int,
        data: CheckinData,
        palette: Palette,
    ) {
        val s = strings(data.lang)
        val pad = dp(context, 10f).toFloat()
        val radius = min(height * 0.30f, dp(context, 14f).toFloat())
        val cx = pad + radius + dp(context, 2f)
        val cy = height / 2f
        drawRing(context, canvas, cx, cy, radius, data.rate, data.percent, palette, 11f)

        val textX = cx + radius + dp(context, 8f)
        val titlePaint = textPaint(context, 12f, palette.text, bold = true)
        canvas.drawText(s.todayCheckin, textX, cy - dp(context, 1f), titlePaint)
        val sub = if (data.total == 0) s.noTasks else "${data.done}/${data.total}"
        val subPaint = textPaint(context, 10f, palette.sub)
        canvas.drawText(sub, textX, cy + dp(context, 12f), subPaint)

    }

    private fun drawCheckinCompact(
        context: Context,
        canvas: Canvas,
        width: Int,
        height: Int,
        data: CheckinData,
        palette: Palette,
    ) {
        val s = strings(data.lang)
        val pad = dp(context, 11f).toFloat()
        val titlePaint = textPaint(context, 13f, palette.text, bold = true)
        canvas.drawText(s.todayCheckin, pad, pad + dp(context, 11f), titlePaint)

        val countPaint = textPaint(context, 10f, palette.sub)
        val count = "${data.done}/${data.total}"
        canvas.drawText(
            count,
            width - pad - countPaint.measureText(count),
            pad + dp(context, 11f),
            countPaint,
        )

        val radius = min(width * 0.20f, height * 0.19f)
        val cx = pad + radius
        val cy = pad + dp(context, 18f) + radius
        if (!data.minimal) {
            drawRing(context, canvas, cx, cy, radius, data.rate, data.percent, palette, 13f)
        }

        val listX = if (data.minimal) pad else cx + radius + dp(context, 8f)
        val maxWidth = (width - listX - pad).coerceAtLeast(dp(context, 20f).toFloat())
        val listTop = pad + dp(context, 30f)
        val rows = if (data.tasks.isEmpty()) emptyList() else data.tasks.take(3)
        if (rows.isEmpty()) {
            val empty = textPaint(context, 9.5f, palette.sub)
            drawEllipsized(canvas, s.notAdded, listX, listTop + dp(context, 6f), maxWidth, empty)
        } else {
            // 2×2 只有 3 行，按可用高度均分，避免全部挤在标题下面。
            val step = ((height - listTop - pad) / 3f)
                .coerceIn(dp(context, 18f).toFloat(), dp(context, 34f).toFloat())
            rows.forEachIndexed { index, task ->
                drawTaskRow(
                    context = context,
                    canvas = canvas,
                    task = task,
                    x = listX,
                    y = listTop + step * index + step * 0.72f,
                    maxWidth = maxWidth,
                    textSize = 10.5f,
                    palette = palette,
                    checkboxRadius = 4.8f,
                )
            }
        }
    }

    private fun drawCheckinWide(
        context: Context,
        canvas: Canvas,
        width: Int,
        height: Int,
        data: CheckinData,
        palette: Palette,
    ) {
        val s = strings(data.lang)
        val pad = dp(context, 12f).toFloat()
        val titlePaint = textPaint(context, 13f, palette.text, bold = true)
        canvas.drawText(s.todayCheckin, pad, pad + dp(context, 12f), titlePaint)

        val subPaint = textPaint(context, 9.5f, palette.sub)
        val status = if (data.total == 0) "0%" else "${data.done}/${data.total} · ${data.percent}%"
        val statusPaint = textPaint(context, 10.5f, palette.accent, bold = true)
        canvas.drawText(
            status,
            width - pad - statusPaint.measureText(status),
            pad + dp(context, 12f),
            statusPaint,
        )

        val radius = min(height * 0.22f, dp(context, 22f).toFloat())
        val cx = pad + radius
        val cy = pad + dp(context, 22f) + radius
        if (!data.minimal) {
            drawRing(context, canvas, cx, cy, radius, data.rate, data.percent, palette, 13f)
        }

        val listX = if (data.minimal) pad else cx + radius + dp(context, 8f)
        val totalWidth = (width - listX - pad).coerceAtLeast(dp(context, 40f).toFloat())
        val rows = data.tasks.take(if (data.minimal) 8 else 6)
        if (rows.isEmpty()) {
            drawEllipsized(canvas, s.todayNoTasks, listX, pad + dp(context, 25f), totalWidth, subPaint)
        } else if (totalWidth >= dp(context, 150f) && rows.size > 3) {
            // 4×2 横向空间充足：3+3 两列，并把三行均匀铺满可用高度，
            // 避免上半部分挤在一起、下半部分大片留白。
            val gap = dp(context, 10f).toFloat()
            val colWidth = ((totalWidth - gap) / 2f).coerceAtLeast(dp(context, 60f).toFloat())
            val listTop = pad + dp(context, 28f)
            val bottom = height - pad
            val step = ((bottom - listTop) / 3f).coerceIn(dp(context, 16f).toFloat(), dp(context, 34f).toFloat())
            rows.take(3).forEachIndexed { index, task ->
                val y = listTop + step * index + step * 0.72f
                drawTaskRow(context, canvas, task, listX, y, colWidth, 10.5f, palette, 4.8f)
            }
            rows.drop(3).take(3).forEachIndexed { index, task ->
                val y = listTop + step * index + step * 0.72f
                drawTaskRow(
                    context, canvas, task, listX + colWidth + gap, y,
                    colWidth, 10.5f, palette, 4.8f,
                )
            }
        } else {
            val listTop = pad + dp(context, 28f)
            val bottom = height - pad
            val step = ((bottom - listTop) / rows.size).coerceAtLeast(dp(context, 15f).toFloat())
            rows.forEachIndexed { index, task ->
                val y = listTop + step * index + step * 0.72f
                drawTaskRow(context, canvas, task, listX, y, totalWidth, 10.5f, palette, 4.8f)
            }
        }
    }

    private fun drawCheckinFull(
        context: Context,
        canvas: Canvas,
        width: Int,
        height: Int,
        data: CheckinData,
        palette: Palette,
    ) {
        val s = strings(data.lang)
        val pad = dp(context, 18f).toFloat()

        // 4×4 信息密度最高：顶部只放标题/日期和右侧圆环，下面全部留任务列表。
        val titlePaint = textPaint(context, 17f, palette.text, bold = true)
        canvas.drawText(s.todayCheckin, pad, pad + dp(context, 14f), titlePaint)

        val datePaint = textPaint(context, 11f, palette.sub)
        canvas.drawText(data.dateLabel, pad, pad + dp(context, 33f), datePaint)

        val radius = dp(context, 27f).toFloat()
        val cx = width - pad - radius
        val cy = pad + radius + dp(context, 2f)
        if (!data.minimal) {
            drawRing(context, canvas, cx, cy, radius, data.rate, data.percent, palette, 15f)
        }

        // 圆环占右侧，进度条只铺左侧；极简模式隐藏圆环后铺满整行。
        val barWidth = if (data.minimal) {
            width - pad * 2
        } else {
            (width - pad * 2 - radius * 2 - dp(context, 22f))
                .coerceAtLeast(dp(context, 64f).toFloat())
        }
        val barTop = pad + dp(context, 48f)
        drawProgressBar(context, canvas, pad, barTop, barWidth, data.rate, palette)

        val status = if (data.total == 0) s.todayNoTasks else "${data.done}/${data.total} · ${data.percent}%"
        val statusPaint = textPaint(context, 11f, palette.accent, bold = true)
        drawEllipsized(canvas, status, pad, barTop + dp(context, 19f), barWidth, statusPaint)

        // 状态文字在进度条下方；任务列表必须从状态文字之后开始，避免重叠。
        val listTop = barTop + dp(context, 32f)
        var y = listTop
        val listWidth = width - pad * 2
        val rowHeight = dp(context, 30f)
        // 底部预留页脚空间，防止最后一行压到 footer。
        val maxRows = ((height - listTop - dp(context, 34f)) / rowHeight).toInt()
            .coerceAtLeast(0)
        val rows = data.tasks.take(maxRows)
        if (rows.isEmpty()) {
            drawEllipsized(canvas, s.addPrompt, pad, y + dp(context, 8f), listWidth, datePaint)
        } else {
            rows.forEach { task ->
                drawTaskRow(
                    context = context,
                    canvas = canvas,
                    task = task,
                    x = pad,
                    y = y,
                    maxWidth = listWidth,
                    textSize = 13.5f,
                    palette = palette,
                    checkboxRadius = 5.8f,
                )
                y += rowHeight
            }
        }

        val footer = textPaint(context, 9.5f, palette.sub)
        val footerText = if (data.total == 0) s.footerIdle else s.footerActive
        drawEllipsized(canvas, footerText, pad, height - dp(context, 8f).toFloat(), listWidth, footer)
    }

    /**
     * 2×2 紧凑热力图：最近 4 周、7 行；只保留标题和方格。
     */
    private fun drawHeatmapCompact(
        context: Context,
        canvas: Canvas,
        width: Int,
        height: Int,
        data: HeatmapData,
        palette: Palette,
    ) {
        val s = strings(data.lang)
        val pad = dp(context, 11f).toFloat()
        val titlePaint = textPaint(context, 11.5f, palette.text, bold = true)
        canvas.drawText(s.recent4, pad, pad + dp(context, 10f), titlePaint)

        val avg = textPaint(context, 9f, palette.accent, bold = true)
        val text = if (data.activeAverage <= 0.0) "0%" else
            "${(data.activeAverage * 100).roundToInt()}%"
        canvas.drawText(
            text,
            width - pad - avg.measureText(text),
            pad + dp(context, 10f),
            avg,
        )

        val top = pad + dp(context, 18f)
        val gap = dp(context, 1.5f).toFloat()
        // 2×2 采用 4 列（周）× 7 行（星期）的竖向日历，避免按 7 列排布时
        // 高度被裁掉。格子取宽高共同约束后的最小值，并整体居中。
        val availableW = width - pad * 2 - gap * 3
        val availableH = height - top - pad - gap * 6
        val cell = min(availableW / 4f, availableH / 7f)
        val gridW = cell * 4 + gap * 3
        val gridH = cell * 7 + gap * 6
        val startX = pad + (width - pad * 2 - gridW) / 2f
        val startY = top + (availableH - gridH) / 2f

        val dateMap = data.days.associateBy { it.date }
        val today = LocalDate.now()
        val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
        val startDate = monday.minusWeeks(3)
        for (i in 0 until 28) {
            val date = startDate.plusDays(i.toLong())
            val existing = dateMap[date.toString()]
            val future = date.isAfter(today)
            val rate = if (future) 0.0 else existing?.rate ?: 0.0
            val row = i % 7
            val col = i / 7
            val x = startX + col * (cell + gap)
            val y = startY + row * (cell + gap)
            val rect = RectF(x, y, x + cell, y + cell)
            val radius = min(cell * 0.16f, dp(context, 2f).toFloat())
            canvas.drawRoundRect(
                rect,
                radius,
                radius,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (future) palette.future else heatColor(data.hue, rate, data.dark)
                    style = Paint.Style.FILL
                },
            )
            if (date == today) {
                canvas.drawRoundRect(
                    RectF(x - 1, y - 1, x + cell + 1, y + cell + 1),
                    radius + 1,
                    radius + 1,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = palette.accent
                        style = Paint.Style.STROKE
                        strokeWidth = dp(context, 1.2f).toFloat()
                    },
                )
            }
        }
    }

    // ---------------------------------------------------------------------
    // 热力日历卡片
    // ---------------------------------------------------------------------

    fun renderHeatmap(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        rawJson: String?,
    ): Bitmap {
        val width = dp(context, widthDp.coerceAtLeast(108).toFloat())
        val height = dp(context, heightDp.coerceAtLeast(90).toFloat())
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val data = parseHeatmap(rawJson)
        val palette = palette(data.hue, data.dark)
        drawCardBackground(canvas, width, height, palette)

        if (widthDp < 200 && heightDp < 200) {
            drawHeatmapCompact(context, canvas, width, height, data, palette)
            return bitmap
        }

        val s = strings(data.lang)
        val pad = dp(context, 13f).toFloat()
        val titlePaint = textPaint(context, 13f, palette.text, bold = true)
        canvas.drawText(s.recent8, pad, pad + dp(context, 11f), titlePaint)

        val avg = if (data.activeAverage <= 0.0) "${s.monthAvg}0%" else {
            "${s.monthAvg}${(data.activeAverage * 100).roundToInt()}%"
        }
        val avgPaint = textPaint(context, 10.5f, palette.accent, bold = true)
        canvas.drawText(
            avg,
            width - pad - avgPaint.measureText(avg),
            pad + dp(context, 11f),
            avgPaint,
        )

        val headerBottom = pad + dp(context, 20f)
        val gap = dp(context, if (heightDp >= 180) 3.2f else 1.8f).toFloat()
        val availableW = width - pad * 2 - gap * 7
        val availableH = height - headerBottom - pad - gap * 6
        val cell = min(availableW / 8f, availableH / 7f)
        val gridW = cell * 8 + gap * 7
        val startX = pad + (width - pad * 2 - gridW) / 2f
        val startY = headerBottom + (availableH - (cell * 7 + gap * 6)) / 2f

        val dateMap = data.days.associateBy { it.date }
        val today = LocalDate.now()
        val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
        val startDate = monday.minusWeeks(7)

        var activeDays = 0
        var rateSum = 0.0
        for (i in 0 until 56) {
            val date = startDate.plusDays(i.toLong())
            val existing = dateMap[date.toString()]
            val isFuture = date.isAfter(today)
            val rate = if (isFuture) 0.0 else existing?.rate ?: 0.0
            if (!isFuture && (existing?.total ?: 0) > 0) {
                activeDays++
                rateSum += rate
            }

            val row = i % 7
            val col = i / 7
            val x = startX + col * (cell + gap)
            val y = startY + row * (cell + gap)
            val isToday = date == today
            val color = heatColor(data.hue, rate, data.dark)
            val rect = RectF(x, y, x + cell, y + cell)
            val radius = min(cell * 0.16f, dp(context, 2.5f).toFloat())
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = if (isFuture) palette.future else color
                style = Paint.Style.FILL
            }
            canvas.drawRoundRect(rect, radius, radius, fill)

            if (rate >= 0.999 && !isFuture) {
                val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.color = if (data.dark) Color.WHITE else Color.BLACK
                    style = Paint.Style.STROKE
                    strokeWidth = dp(context, 1.1f).toFloat()
                    this.alpha = 210
                }
                canvas.drawRoundRect(rect, radius, radius, border)
            }
            if (isToday) {
                val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.color = palette.accent
                    style = Paint.Style.STROKE
                    strokeWidth = dp(context, 1.4f).toFloat()
                }
                canvas.drawRoundRect(
                    RectF(x - 1, y - 1, x + cell + 1, y + cell + 1),
                    radius + 1,
                    radius + 1,
                    border,
                )
            }
        }

        // 4×4 时再显示日期范围/说明；4×2 只保留标题与网格，避免拥挤。
        if (heightDp >= 180) {
            val footer = textPaint(context, 9f, palette.sub)
            val footerText = if (data.lang == "zh") {
                "${startDate.monthValue}月${startDate.dayOfMonth}日 — " +
                    "${today.monthValue}月${today.dayOfMonth}日"
            } else {
                "${startDate.monthValue}/${startDate.dayOfMonth} — " +
                    "${today.monthValue}/${today.dayOfMonth}"
            }
            canvas.drawText(footerText, pad, height - pad + dp(context, 2f), footer)
            val unit = s.rateFade
            canvas.drawText(
                unit,
                width - pad - footer.measureText(unit),
                height - pad + dp(context, 2f),
                footer,
            )
        }

        data.averageDisplay = if (activeDays == 0) 0.0 else rateSum / activeDays
        return bitmap
    }

    // ---------------------------------------------------------------------
    // 数据解析
    // ---------------------------------------------------------------------

    private data class CheckinTask(val title: String, val done: Boolean)

    private data class CheckinData(
        val date: String,
        val dateLabel: String,
        val hue: Float,
        val dark: Boolean,
        val thenPercent: Int,
        val tasks: List<CheckinTask>,
        val total: Int,
        val done: Int,
        val minimal: Boolean = false,
        val lang: String = "zh",
    ) {
        val rate: Float get() = if (total <= 0) 0f else (done.toFloat() / total).coerceIn(0f, 1f)
        val percent: Int get() = (rate * 100).roundToInt()
    }

    private data class HeatDay(
        val date: String,
        val total: Int,
        val done: Int,
        val rate: Double,
    )

    private data class HeatmapData(
        val hue: Float,
        val dark: Boolean,
        val days: List<HeatDay>,
        val average: Double,
        val lang: String = "zh",
    ) {
        var averageDisplay: Double = average
        val activeAverage: Double get() = averageDisplay
    }

    private fun parseCheckin(rawJson: String?): CheckinData {
        val todayKey = LocalDate.now().toString()
        try {
            val json = JSONObject(rawJson ?: "{}")
            val payloadDate = json.optString("date", todayKey)
            val stale = payloadDate != todayKey
            val hue = json.optDouble("hue", 220.0).toFloat()
            val dark = json.optBoolean("dark", false)
            val minimal = json.optBoolean("minimal", false)
            val lang = json.optString("lang", "zh")
            val formatter = dateFormatter(lang)
            val dateLabel = if (stale) {
                LocalDate.now().format(formatter)
            } else {
                json.optString("date_label", LocalDate.now().format(formatter))
            }

            val tasks = mutableListOf<CheckinTask>()

            if (!stale) {
                // 正常路径：使用 App 已经算好的今日明细。
                val array = json.optJSONArray("tasks") ?: JSONArray()
                for (i in 0 until array.length()) {
                    val item = array.optJSONObject(i) ?: continue
                    tasks.add(
                        CheckinTask(
                            title = item.optString("title", "任务"),
                            done = item.optBoolean("done", false),
                        )
                    )
                }
                return CheckinData(
                    date = payloadDate,
                    dateLabel = dateLabel,
                    hue = hue,
                    dark = dark,
                    thenPercent = json.optInt("percent", 0),
                    tasks = tasks,
                    total = json.optInt("total", tasks.size),
                    done = json.optInt("done", tasks.count { it.done }),
                    minimal = minimal,
                    lang = lang,
                )
            }

            // 跨天路径：卡片在零点被闹钟唤醒，但 App 可能没启动。
            // 用上次同步的“每日任务 + 未完成待办”重建今天：
            // 每日任务全部视为未打卡，昨日已完成的待办不再出现。
            val daily = json.optJSONArray("daily")
            val pending = json.optJSONArray("pending")
            if (daily != null) {
                for (i in 0 until daily.length()) {
                    val item = daily.optJSONObject(i) ?: continue
                    tasks.add(CheckinTask(item.optString("title", "任务"), false))
                }
            }
            if (pending != null) {
                for (i in 0 until pending.length()) {
                    val item = pending.optJSONObject(i) ?: continue
                    tasks.add(CheckinTask(item.optString("title", "任务"), false))
                }
            }
            return CheckinData(
                date = todayKey,
                dateLabel = dateLabel,
                hue = hue,
                dark = dark,
                thenPercent = 0,
                tasks = tasks,
                total = tasks.size,
                done = 0,
                minimal = minimal,
                lang = lang,
            )
        } catch (_: Exception) {
            return CheckinData(
                date = todayKey,
                dateLabel = LocalDate.now().format(dateFormatter("zh")),
                hue = 220f,
                dark = false,
                thenPercent = 0,
                tasks = emptyList(),
                total = 0,
                done = 0,
                lang = "zh",
            )
        }
    }

    private fun parseHeatmap(rawJson: String?): HeatmapData {
        val today = LocalDate.now()
        try {
            val json = JSONObject(rawJson ?: "{}")
            val hue = json.optDouble("hue", 220.0).toFloat()
            val dark = json.optBoolean("dark", false)
            val lang = json.optString("lang", "zh")
            val array = json.optJSONArray("days") ?: JSONArray()
            val days = mutableListOf<HeatDay>()
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue
                days.add(
                    HeatDay(
                        date = item.optString("date", ""),
                        total = item.optInt("total", 0),
                        done = item.optInt("done", 0),
                        rate = item.optDouble("rate", 0.0).coerceIn(0.0, 1.0),
                    )
                )
            }
            val payloadToday = json.optString("today", today.toString())
            val average = json.optDouble("average", 0.0)
            // 若日期已跨天，保留旧数据里的历史日期，今天补 0；
            // 实际平均值在 renderHeatmap 中按 56 天窗口重算。
            return HeatmapData(
                hue = hue,
                dark = dark,
                days = if (payloadToday == today.toString()) days else days,
                average = average,
                lang = lang,
            )
        } catch (_: Exception) {
            return HeatmapData(
                hue = 220f,
                dark = false,
                days = emptyList(),
                average = 0.0,
                lang = "zh",
            )
        }
    }

    // ---------------------------------------------------------------------
    // 基础绘制
    // ---------------------------------------------------------------------

    private data class Palette(
        val background: Int,
        val surface: Int,
        val text: Int,
        val sub: Int,
        val track: Int,
        val accent: Int,
        val future: Int,
        val dark: Boolean,
    )

    private fun palette(hue: Float, dark: Boolean): Palette {
        val accent = Color.HSVToColor(floatArrayOf(hue, 1f, 1f))
        return if (dark) {
            Palette(
                background = BG_DARK,
                surface = 0xFF141D30.toInt(),
                text = TEXT_DARK,
                sub = 0xFFA9B6CE.toInt(),
                track = 0xFF2A364D.toInt(),
                accent = accent,
                future = 0xFF1B2436.toInt(),
                dark = true,
            )
        } else {
            Palette(
                background = BG_LIGHT,
                surface = 0xFFF5F7FC.toInt(),
                text = TEXT_LIGHT,
                sub = 0xFF5B6B85.toInt(),
                track = 0xFFE2E8F2.toInt(),
                accent = accent,
                future = 0xFFEFF3F9.toInt(),
                dark = false,
            )
        }
    }

    private fun drawCardBackground(canvas: Canvas, width: Int, height: Int, palette: Palette) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.background
            style = Paint.Style.FILL
        }
        val radius = dpFloat(22f)
        canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)

        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (palette.dark) 0x22FFFFFF else 0x14000000
            style = Paint.Style.STROKE
            strokeWidth = dpFloat(1f)
        }
        canvas.drawRoundRect(
            RectF(0.5f, 0.5f, width - 0.5f, height - 0.5f),
            radius,
            radius,
            border,
        )
    }

    private fun drawRing(
        context: Context,
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        rate: Float,
        percent: Int,
        palette: Palette,
        textSizeDp: Float,
    ) {
        val stroke = radius * 0.22f
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.track
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawArc(rect, -90f, 360f, false, track)

        val progress = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.accent
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawArc(rect, -90f, 360f * rate.coerceIn(0f, 1f), false, progress)

        val text = textPaint(context, textSizeDp, palette.text, bold = true)
        val label = "$percent%"
        val tw = text.measureText(label)
        canvas.drawText(label, cx - tw / 2f, cy + fixedTextSize(context, textSizeDp) * 0.36f, text)
    }

    private fun drawProgressBar(
        context: Context,
        canvas: Canvas,
        x: Float,
        y: Float,
        width: Float,
        rate: Float,
        palette: Palette,
    ) {
        val height = dp(context, 5f).toFloat()
        val radius = height / 2f
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = palette.track }
        canvas.drawRoundRect(RectF(x, y, x + width, y + height), radius, radius, track)
        if (rate > 0f) {
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = palette.accent }
            canvas.drawRoundRect(
                RectF(x, y, x + width * rate.coerceIn(0f, 1f), y + height),
                radius,
                radius,
                fill,
            )
        }
    }

    private fun drawTaskRow(
        context: Context,
        canvas: Canvas,
        task: CheckinTask,
        x: Float,
        y: Float,
        maxWidth: Float,
        textSize: Float,
        palette: Palette,
        checkboxRadius: Float,
    ) {
        val cx = x + checkboxRadius
        val cy = y + dp(context, 5f)
        val circle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(context, 1.2f).toFloat()
            color = if (task.done) palette.accent else palette.sub
        }
        canvas.drawCircle(cx, cy, checkboxRadius, circle)

        if (task.done) {
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = palette.accent
                style = Paint.Style.FILL
            }
            canvas.drawCircle(cx, cy, checkboxRadius - dp(context, 0.4f), fill)
            val check = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (palette.dark) Color.BLACK else Color.WHITE
                style = Paint.Style.STROKE
                strokeWidth = dp(context, 1.3f).toFloat()
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }
            val path = Path().apply {
                moveTo(cx - checkboxRadius * 0.45f, cy)
                lineTo(cx - checkboxRadius * 0.05f, cy + checkboxRadius * 0.38f)
                lineTo(cx + checkboxRadius * 0.48f, cy - checkboxRadius * 0.38f)
            }
            canvas.drawPath(path, check)
        }

        val textPaint = textPaint(context, textSize, if (task.done) palette.sub else palette.text)
        val textX = cx + checkboxRadius + dp(context, 6f)
        val textY = y + dp(context, 8.5f)
        drawEllipsized(canvas, task.title, textX, textY, maxWidth - (textX - x), textPaint)
    }

    private fun drawEllipsized(
        canvas: Canvas,
        text: String,
        x: Float,
        y: Float,
        maxWidth: Float,
        paint: TextPaint,
    ) {
        if (maxWidth <= 0f) return
        val value = TextUtils.ellipsize(text, paint, maxWidth, TextUtils.TruncateAt.END).toString()
        canvas.drawText(value, x, y, paint)
    }

    /**
     * 与 App 的 `AppTheme.heatColor` 保持同一口径：
     * 固定色相，0% 用浅底色；0~100% 用同一个高饱和色，
     * 只让不透明度线性上升；100% 完全不透明并叠加高亮描边。
     */
    private fun heatColor(hue: Float, rate: Double, dark: Boolean): Int {
        val clamped = rate.coerceIn(0.0, 1.0)
        if (clamped <= 0.0) {
            return if (dark) 0xFF1B2436.toInt() else 0xFFE7ECF5.toInt()
        }
        val saturated = Color.HSVToColor(floatArrayOf(hue, 1f, 1f))
        val alpha = (if (dark) 0.16 + 0.84 * clamped else 0.10 + 0.90 * clamped)
            .coerceIn(0.0, 1.0)
        // Canvas 上直接铺半透明色会和卡片背景二次混合，颜色偏深；
        // 这里先按 App 的底色算出最终不透明色，保证两端观感一致。
        val base = if (dark) 0xFF1B2436.toInt() else 0xFFE7ECF5.toInt()
        fun blend(channel: Int): Int =
            (Color.red(channel) * alpha + Color.red(base) * (1 - alpha)).toInt()
        fun blendGreen(channel: Int): Int =
            (Color.green(channel) * alpha + Color.green(base) * (1 - alpha)).toInt()
        fun blendBlue(channel: Int): Int =
            (Color.blue(channel) * alpha + Color.blue(base) * (1 - alpha)).toInt()
        return Color.rgb(
            blend(saturated),
            blendGreen(saturated),
            blendBlue(saturated),
        )
    }

    private fun textPaint(
        context: Context,
        sizeDp: Float,
        color: Int,
        bold: Boolean = false,
    ): TextPaint {
        return TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            // 卡片使用固定 dp 字号，不跟随系统“字体大小/显示大小”缩放，
            // 否则大字号会把任务行和热力网格撑出卡片。
            textSize = fixedTextSize(context, sizeDp)
            typeface = Typeface.create(
                "sans-serif",
                if (bold) Typeface.BOLD else Typeface.NORMAL,
            )
        }
    }

    private fun dp(context: Context, value: Float): Int =
        (value * context.resources.displayMetrics.density).roundToInt()

    private fun fixedTextSize(context: Context, valueDp: Float): Float =
        valueDp * context.resources.displayMetrics.density

    private fun dpFloat(value: Float): Float =
        value * android.content.res.Resources.getSystem().displayMetrics.density
}
