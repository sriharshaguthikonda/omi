package com.friend.ios

import ai.moonshine.voice.JNI
import ai.moonshine.voice.Transcriber
import ai.moonshine.voice.TranscriberOption
import ai.moonshine.voice.TranscriptEvent
import ai.moonshine.voice.TranscriptEventListener
import ai.moonshine.voice.TranscriptLine
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import okhttp3.OkHttpClient
import okhttp3.Request

class MoonshineSttPlugin private constructor(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val httpClient = OkHttpClient()
    private val transcriptVisitor = MoonshineListener()
    private var transcriber: Transcriber? = null
    private var sampleRate: Int = DEFAULT_SAMPLE_RATE
    private var running = false

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "appendPcm16" -> appendPcm16(call, result)
            "stop" -> stop(result)
            "dispose" -> dispose(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            result.error(
                "moonshine_android_version",
                "Moonshine Voice Android currently requires Android 15 / API 35 or newer.",
                null,
            )
            return
        }

        val modelName = call.argument<String>("model") ?: "moonshine-streaming-tiny"
        val language = call.argument<String>("language") ?: "en"
        val requestedSampleRate = call.argument<Int>("sampleRate") ?: DEFAULT_SAMPLE_RATE
        val revisionWindowMs = call.argument<Int>("revisionWindowMs") ?: 0
        val model = modelSpec(modelName, language)
        if (model == null) {
            result.error("moonshine_model", "Unsupported Moonshine model: $modelName ($language)", null)
            return
        }

        executor.execute {
            try {
                stopLocked(sendClosed = false)
                sampleRate = requestedSampleRate
                // First run downloads the model (~tens of MB) from the Moonshine CDN into filesDir,
                // mirroring how the existing on-device Whisper path fetches its model at runtime.
                // ponytail: not bundled in-APK/git (no Git LFS here, ~79 MB tiny model); download-once + cache.
                val modelDir = ensureModelDownloaded(model.modelId)
                val options = arrayListOf(
                    TranscriberOption("identify_speakers", "false"),
                    TranscriberOption("return_audio_data", "false"),
                )
                if (revisionWindowMs > 0) {
                    // ponytail: Moonshine 0.0.65 parse_transcriber_options accepts `vad_window_duration`
                    // in seconds; README Transcriber Options documents it as the VAD averaging window.
                    // Source enforces no min/max, so Flutter clamps the override to 500-8000ms; 0 omits it.
                    options.add(TranscriberOption("vad_window_duration", (revisionWindowMs / 1000.0).toString()))
                }
                val nextTranscriber = Transcriber(options)
                nextTranscriber.loadFromFiles(modelDir.absolutePath, model.arch)
                nextTranscriber.addListener { event: TranscriptEvent ->
                    event.accept(transcriptVisitor)
                }
                nextTranscriber.start()
                transcriber = nextTranscriber
                running = true
                success(result, true)
            } catch (t: Throwable) {
                Log.e(TAG, "Moonshine initialize failed", t)
                transcriber = null
                running = false
                error(result, "moonshine_initialize", t.message ?: "Moonshine initialize failed")
            }
        }
    }

    private fun appendPcm16(call: MethodCall, result: MethodChannel.Result) {
        val pcm16 = call.argument<ByteArray>("pcm16")
        if (pcm16 == null || pcm16.isEmpty()) {
            result.success(null)
            return
        }

        executor.execute {
            try {
                val activeTranscriber = transcriber
                if (activeTranscriber != null && running) {
                    activeTranscriber.addAudio(pcm16ToFloat(pcm16), sampleRate)
                }
                success(result, null)
            } catch (t: Throwable) {
                Log.e(TAG, "Moonshine appendPcm16 failed", t)
                invokeFlutter("onError", t.message ?: "Moonshine audio append failed")
                error(result, "moonshine_append", t.message ?: "Moonshine audio append failed")
            }
        }
    }

    private fun stop(result: MethodChannel.Result) {
        executor.execute {
            try {
                stopLocked(sendClosed = true)
                success(result, null)
            } catch (t: Throwable) {
                Log.e(TAG, "Moonshine stop failed", t)
                error(result, "moonshine_stop", t.message ?: "Moonshine stop failed")
            }
        }
    }

    private fun dispose(result: MethodChannel.Result) {
        executor.execute {
            try {
                stopLocked(sendClosed = true)
                transcriber = null
                success(result, null)
            } catch (t: Throwable) {
                Log.e(TAG, "Moonshine dispose failed", t)
                error(result, "moonshine_dispose", t.message ?: "Moonshine dispose failed")
            }
        }
    }

    private fun stopLocked(sendClosed: Boolean) {
        val activeTranscriber = transcriber
        if (activeTranscriber != null && running) {
            activeTranscriber.stop()
        }
        activeTranscriber?.removeAllListeners()
        running = false
        if (sendClosed) {
            invokeFlutter("onClosed", null)
        }
    }

    /**
     * Downloads the streaming model's component files into `filesDir/moonshine_models/<modelId>` on
     * first use, then reuses the cached copy. Each file is written to a `.part` sidecar and renamed
     * so an interrupted download never leaves a truncated file that looks complete.
     */
    private fun ensureModelDownloaded(modelId: String): File {
        val dir = File(context.filesDir, "moonshine_models/$modelId")
        dir.mkdirs()
        val base = "$MODEL_CDN/$modelId/quantized"
        for (component in MODEL_COMPONENTS) {
            val target = File(dir, component)
            if (target.exists() && target.length() > 0L) {
                continue
            }
            downloadTo("$base/$component", target)
        }
        return dir
    }

    private fun downloadTo(url: String, target: File) {
        val request = Request.Builder().url(url).build()
        httpClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IllegalStateException("Moonshine model download failed (${response.code}) for $url")
            }
            val body = response.body ?: throw IllegalStateException("Empty response body for $url")
            val part = File(target.parentFile, "${target.name}.part")
            body.byteStream().use { input ->
                part.outputStream().use { output -> input.copyTo(output) }
            }
            if (!part.renameTo(target)) {
                part.copyTo(target, overwrite = true)
                part.delete()
            }
        }
    }

    private fun pcm16ToFloat(pcm16: ByteArray): FloatArray {
        val sampleCount = pcm16.size / BYTES_PER_SAMPLE
        val buffer = ByteBuffer.wrap(pcm16).order(ByteOrder.LITTLE_ENDIAN)
        return FloatArray(sampleCount) {
            buffer.getShort().toFloat() / Short.MAX_VALUE.toFloat()
        }
    }

    private fun emitTranscript(line: TranscriptLine, isFinal: Boolean) {
        val text = line.text?.trim().orEmpty()
        if (text.isEmpty()) {
            return
        }
        invokeFlutter(
            "onTranscript",
            mapOf(
                "text" to text,
                "start" to line.startTime.toDouble(),
                "end" to (line.startTime + line.duration).toDouble(),
                "isFinal" to isFinal,
            ),
        )
    }

    private fun invokeFlutter(method: String, arguments: Any?) {
        mainHandler.post {
            channel.invokeMethod(method, arguments)
        }
    }

    private fun success(result: MethodChannel.Result, value: Any?) {
        mainHandler.post {
            result.success(value)
        }
    }

    private fun error(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post {
            result.error(code, message, null)
        }
    }

    private inner class MoonshineListener : TranscriptEventListener() {
        override fun onLineTextChanged(event: TranscriptEvent.LineTextChanged) {
            emitTranscript(event.line, isFinal = false)
        }

        override fun onLineCompleted(event: TranscriptEvent.LineCompleted) {
            emitTranscript(event.line, isFinal = true)
        }

        override fun onError(event: TranscriptEvent.Error) {
            invokeFlutter("onError", event.cause.message ?: "Moonshine transcription error")
        }
    }

    private data class ModelSpec(
        val modelId: String,
        val arch: Int,
    )

    companion object {
        private const val CHANNEL = "com.omi/moonshine_stt"
        private const val TAG = "MoonshineSttPlugin"
        private const val DEFAULT_SAMPLE_RATE = 16000
        private const val BYTES_PER_SAMPLE = 2
        private const val MODEL_CDN = "https://download.moonshine.ai/model"
        private val MODEL_COMPONENTS = listOf(
            "adapter.ort",
            "cross_kv.ort",
            "decoder_kv.ort",
            "decoder_kv_with_attention.ort",
            "encoder.ort",
            "frontend.ort",
            "streaming_config.json",
            "tokenizer.bin",
        )

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(MoonshineSttPlugin(context.applicationContext, channel))
        }

        private fun modelSpec(model: String, language: String): ModelSpec? {
            val normalizedLanguage = language.lowercase().substringBefore("-").substringBefore("_")
            if (normalizedLanguage != "en") {
                return null
            }
            return when (model) {
                "moonshine-streaming-tiny", "tiny-streaming-en" -> ModelSpec(
                    modelId = "tiny-streaming-en",
                    arch = JNI.MOONSHINE_MODEL_ARCH_TINY_STREAMING,
                )
                "moonshine-streaming-small", "small-streaming-en" -> ModelSpec(
                    modelId = "small-streaming-en",
                    arch = JNI.MOONSHINE_MODEL_ARCH_SMALL_STREAMING,
                )
                "moonshine-streaming-medium", "medium-streaming-en" -> ModelSpec(
                    modelId = "medium-streaming-en",
                    arch = JNI.MOONSHINE_MODEL_ARCH_MEDIUM_STREAMING,
                )
                else -> null
            }
        }
    }
}
