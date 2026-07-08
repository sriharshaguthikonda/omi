package com.friend.ios

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import kotlin.math.roundToInt

private const val DEFAULT_VOLUME = 25
private const val DEFAULT_FLOOR = 8
private const val DEFAULT_CEIL = 60
private const val SHORT_BEEP_MS = 80
private const val DOUBLE_BEEP_GAP_MS = 140L
private const val STILL_LISTENING_VOLUME_SCALE = 0.7
private const val SILENCE_BASE_SCALE = 0.4

fun rmsToVolume(rms: Double, base: Int, floor: Int, ceil: Int): Int {
    val minVolume = floor.coerceIn(0, 100)
    val maxVolume = ceil.coerceIn(minVolume, 100)
    val baseVolume = base.coerceIn(minVolume, maxVolume)
    val quietFloor = (baseVolume * SILENCE_BASE_SCALE).roundToInt().coerceIn(minVolume, maxVolume)
    val normalizedRms = rms.coerceIn(0.0, 1.0)
    val scaled = quietFloor + ((maxVolume - quietFloor) * normalizedRms)

    return scaled.roundToInt().coerceIn(minVolume, maxVolume)
}

object TriggerFeedback {
    private val handler = Handler(Looper.getMainLooper())
    private var toneGenerator: ToneGenerator? = null
    private var volume = DEFAULT_VOLUME
    private var hapticEnabled = false
    private var vibrator: Vibrator? = null

    @Synchronized
    fun beepStart() {
        beep(volume)
    }

    @Synchronized
    fun beepStop() {
        beep(volume)
        handler.postDelayed({ beep(volume) }, DOUBLE_BEEP_GAP_MS)
    }

    @Synchronized
    fun beepStillListening() {
        beep((volume * STILL_LISTENING_VOLUME_SCALE).roundToInt().coerceAtLeast(DEFAULT_FLOOR))
    }

    @Synchronized
    fun setVolume(v: Int) {
        volume = v.coerceIn(DEFAULT_FLOOR, DEFAULT_CEIL)
        toneGenerator?.release()
        toneGenerator = null
    }

    @Synchronized
    fun setHaptic(enabled: Boolean) {
        hapticEnabled = enabled
    }

    @Synchronized
    fun setVibrator(vibrator: Vibrator?) {
        this.vibrator = vibrator
    }

    @Synchronized
    fun release() {
        handler.removeCallbacksAndMessages(null)
        toneGenerator?.release()
        toneGenerator = null
        vibrator = null
    }

    private fun beep(toneVolume: Int) {
        val generator = toneGenerator ?: ToneGenerator(AudioManager.STREAM_NOTIFICATION, toneVolume.coerceIn(0, 100))
            .also { toneGenerator = it }
        generator.startTone(ToneGenerator.TONE_PROP_BEEP, SHORT_BEEP_MS)
        vibrate()
    }

    private fun vibrate() {
        if (!hapticEnabled) return
        val currentVibrator = vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            currentVibrator.vibrate(VibrationEffect.createOneShot(35, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            currentVibrator.vibrate(35)
        }
    }
}
