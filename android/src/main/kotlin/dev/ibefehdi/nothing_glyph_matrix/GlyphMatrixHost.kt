package dev.ibefehdi.nothing_glyph_matrix

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.util.Log
import com.nothing.ketchum.Common
import com.nothing.ketchum.Glyph
import com.nothing.ketchum.GlyphMatrixFrame
import com.nothing.ketchum.GlyphMatrixManager
import com.nothing.ketchum.GlyphMatrixObject
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel host for the Nothing Glyph Matrix SDK (in-app [setAppMatrixFrame]).
 */
internal class GlyphMatrixHost(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var manager: GlyphMatrixManager? = null
    private var connected = false
    private var pending: Pending? = null
    private var cachedMatrixLength: Int? = null

    private val callback =
        object : GlyphMatrixManager.Callback {
            override fun onServiceConnected(name: ComponentName?) {
                registerDevice()
                connected = true
                flushPending()
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                connected = false
            }
        }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "register" -> runCatching(result, "register_failed") { connect() }
            "showImage" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null) {
                    result.error("invalid_args", "Expected PNG bytes", null)
                    return
                }
                runCatching(result, "show_image_failed") {
                    present(Pending.Image(bytes))
                }
            }
            "showText" -> {
                val text = call.arguments as? String
                if (text.isNullOrBlank()) {
                    result.error("invalid_args", "Expected non-empty text", null)
                    return
                }
                runCatching(result, "show_text_failed") {
                    present(Pending.Text(text))
                }
            }
            "showProgress" -> {
                val fraction =
                    when (val raw = call.arguments) {
                        is Double -> raw
                        is Float -> raw.toDouble()
                        is Int -> raw.toDouble()
                        is Long -> raw.toDouble()
                        else -> null
                    }
                if (fraction == null) {
                    result.error("invalid_args", "Expected progress fraction", null)
                    return
                }
                runCatching(result, "show_progress_failed") {
                    present(Pending.Progress(fraction.toFloat().coerceIn(0f, 1f)))
                }
            }
            "clear" ->
                runCatching(result, "clear_failed") {
                    pending = null
                    closeMatrix()
                }
            "dispose" -> runCatching(result, "dispose_failed") { dispose() }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        pending = null
        closeMatrix()
        try {
            manager?.unInit()
        } catch (_: Exception) {
        }
        manager = null
        connected = false
        cachedMatrixLength = null
        channel.setMethodCallHandler(null)
    }

    private fun runCatching(
        result: MethodChannel.Result,
        code: String,
        block: () -> Unit,
    ) {
        try {
            block()
            result.success(null)
        } catch (e: Exception) {
            result.error(code, e.message, null)
        }
    }

    private fun isSupported(): Boolean =
        Build.MANUFACTURER.equals("Nothing", ignoreCase = true)

    private fun connect() {
        if (manager != null) return
        manager =
            try {
                GlyphMatrixManager.getInstance(context)?.also { it.init(callback) }
            } catch (e: Throwable) {
                Log.w(TAG, "GlyphMatrixManager unavailable", e)
                null
            }
    }

    private fun present(content: Pending) {
        connect()
        if (connected) {
            pending = null
            draw(content)
        } else {
            pending = content
        }
    }

    private fun flushPending() {
        val content = pending ?: return
        pending = null
        draw(content)
    }

    private fun draw(content: Pending) {
        val bitmap =
            when (content) {
                is Pending.Image -> decodeImage(content.bytes) ?: return
                is Pending.Text -> renderTextBitmap(content.value)
                is Pending.Progress -> renderProgressBitmap(content.fraction)
            }
        drawBitmap(bitmap)
    }

    private fun decodeImage(bytes: ByteArray): Bitmap? {
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val size = matrixLength()
        val software =
            if (decoded.config == Bitmap.Config.HARDWARE) {
                val copy = decoded.copy(Bitmap.Config.ARGB_8888, false) ?: decoded
                if (copy !== decoded) decoded.recycle()
                copy
            } else {
                decoded
            }
        if (software.width == size && software.height == size) return software
        val scaled = Bitmap.createScaledBitmap(software, size, size, true)
        if (scaled !== software) software.recycle()
        return scaled
    }

    private fun drawBitmap(bitmap: Bitmap) {
        val mgr =
            manager ?: run {
                bitmap.recycle()
                return
            }
        val obj =
            GlyphMatrixObject.Builder()
                .setImageSource(bitmap)
                .setPosition(0, 0)
                .setScale(100)
                .setBrightness(255)
                .build()
        val frame =
            GlyphMatrixFrame.Builder()
                .addTop(obj)
                .build(context)
        try {
            mgr.setAppMatrixFrame(frame.render())
        } catch (e: Exception) {
            Log.w(TAG, "setAppMatrixFrame failed", e)
        }
        bitmap.recycle()
    }

    private fun renderTextBitmap(text: String): Bitmap {
        val size = matrixLength()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.BLACK)

        val paint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
                textSize =
                    (if (text.length <= 2) size * 0.72f else size * 0.42f) - 1f
            }
        val x = size / 2f
        val y = size / 2f - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(text, x, y, paint)
        return bitmap
    }

    private fun renderProgressBitmap(fraction: Float): Bitmap {
        val size = matrixLength()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.BLACK)

        val pad = 2f
        val stroke = 2f
        val rect = RectF(pad, pad, size - pad, size - pad)

        val track =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                color = Color.argb(70, 255, 255, 255)
            }
        val fill =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
                color = Color.WHITE
            }

        canvas.drawArc(rect, -90f, 360f, false, track)
        canvas.drawArc(rect, -90f, 360f * fraction.coerceIn(0f, 1f), false, fill)
        return bitmap
    }

    private fun matrixLength(): Int {
        cachedMatrixLength?.let { return it }
        val length =
            try {
                Common.getDeviceMatrixLength()
            } catch (_: Exception) {
                25
            }.coerceAtLeast(1)
        cachedMatrixLength = length
        return length
    }

    private fun registerDevice() {
        val mgr = manager ?: return
        for (target in DEVICE_TARGETS) {
            try {
                mgr.register(target)
                return
            } catch (e: Exception) {
                Log.d(TAG, "register($target) failed: ${e.message}")
            }
        }
    }

    private fun closeMatrix() {
        try {
            manager?.closeAppMatrix()
        } catch (_: Exception) {
        }
    }

    private sealed class Pending {
        data class Image(
            val bytes: ByteArray,
        ) : Pending()

        data class Text(
            val value: String,
        ) : Pending()

        data class Progress(
            val fraction: Float,
        ) : Pending()
    }

    companion object {
        const val CHANNEL_NAME = "nothing_glyph_matrix"
        private const val TAG = "GlyphMatrixHost"
        private val DEVICE_TARGETS =
            listOf(
                Glyph.DEVICE_23112,
                Glyph.DEVICE_25111p,
            )
    }
}
