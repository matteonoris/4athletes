package com.matteonoris.app4athletes

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.*

/** On-device OCR. Render one page at a time and never upload the document. */
object WorkoutDocumentReader {
    fun register(context: Context, messenger: BinaryMessenger) {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        var busy = false
        MethodChannel(messenger, "com.4athletes/workout_document").setMethodCallHandler { call, result ->
            if (call.method != "recognize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null || busy) {
                result.error("UNAVAILABLE", "Lettura non disponibile. Riprova.", null)
                return@setMethodCallHandler
            }
            busy = true
            scope.launch {
                try {
                    val pages = withContext(Dispatchers.IO) {
                        read(context, File(path), call.argument<Boolean>("isPdf") == true)
                    }
                    result.success(pages)
                } catch (e: Exception) {
                    result.error("READ_FAILED", e.message ?: "Documento non leggibile.", null)
                } finally {
                    busy = false
                }
            }
        }
    }

    private fun read(context: Context, file: File, isPdf: Boolean): List<List<Map<String, Any>>> {
        require(file.isFile && file.length() in 1..(15L * 1024 * 1024)) {
            "Scegli un documento di massimo 15 MB."
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        fun recognize(image: InputImage): List<Map<String, Any>> {
            val text = Tasks.await(recognizer.process(image), 30, TimeUnit.SECONDS)
            return text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                line.boundingBox?.let { box ->
                    mapOf("text" to line.text, "left" to box.left.toDouble(),
                        "top" to box.top.toDouble(), "width" to box.width().toDouble(),
                        "height" to box.height().toDouble(),
                        "words" to line.elements.mapNotNull { element ->
                            element.boundingBox?.let { bounds ->
                                mapOf("text" to element.text, "left" to bounds.left.toDouble(),
                                    "top" to bounds.top.toDouble(), "width" to bounds.width().toDouble(),
                                    "height" to bounds.height().toDouble())
                            }
                        })
                }
            }
        }
        try {
            if (!isPdf) {
                // ImageDecoder respects EXIF orientation and limits decoded memory on API 28+.
                if (android.os.Build.VERSION.SDK_INT >= 28) {
                    val decoded = ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
                        val scale = minOf(1.0, 2400.0 / maxOf(info.size.width, info.size.height))
                        decoder.setTargetSize(maxOf(1, (info.size.width * scale).toInt()),
                            maxOf(1, (info.size.height * scale).toInt()))
                        decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    }
                    // OCR consumes RGB. Transparent PNG backgrounds otherwise
                    // become black, making black text completely unreadable.
                    val bitmap = Bitmap.createBitmap(decoded.width, decoded.height, Bitmap.Config.ARGB_8888)
                    Canvas(bitmap).apply {
                        drawColor(Color.WHITE)
                        drawBitmap(decoded, 0f, 0f, null)
                    }
                    decoded.recycle()
                    try { return listOf(recognize(InputImage.fromBitmap(bitmap, 0))) }
                    finally { bitmap.recycle() }
                }
                return listOf(recognize(InputImage.fromFilePath(context, android.net.Uri.fromFile(file))))
            }
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                PdfRenderer(descriptor).use { pdf ->
                    require(pdf.pageCount in 1..6) { "Scegli un PDF di massimo 6 pagine." }
                    return (0 until pdf.pageCount).map { index ->
                        pdf.openPage(index).use { page ->
                            val scale = minOf(3.0, 2400.0 / maxOf(page.width, page.height))
                            val bitmap = Bitmap.createBitmap(maxOf(1, (page.width * scale).toInt()),
                                maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                            try {
                                bitmap.eraseColor(Color.WHITE)
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                recognize(InputImage.fromBitmap(bitmap, 0))
                            } finally { bitmap.recycle() }
                        }
                    }
                }
            }
        } finally { recognizer.close() }
    }
}
