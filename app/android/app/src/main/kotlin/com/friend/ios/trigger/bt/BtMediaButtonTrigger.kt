package com.friend.ios.trigger.bt

import android.content.Context
import android.content.Intent
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.view.InputDevice
import android.view.KeyEvent
import com.friend.ios.TriggerActionBridge

private const val PREFS_NAME = "FlutterSharedPreferences"
private const val PREF_KEY = "flutter.btMediaButtonTriggerEnabled"
private const val TRIGGER_SOURCE = "bt_media_button"
private const val SESSION_TAG = "OmiBtMediaButtonTrigger"
private const val ATTRIBUTION_AMBIGUOUS = "AMBIGUOUS"
private const val ATTRIBUTION_INFERRED = "INFERRED"

/**
 * P3 increment 1: while the app is running and the user has opted in, holds a
 * MediaSessionCompat so a paired Bluetooth headset's play/pause button routes into
 * TriggerRouter (source "bt_media_button", action "toggle") instead of a music app.
 *
 * Default-off: claiming media-button focus steals play/pause from whatever music app the
 * user is actually running while this session is active. Increment 2 (learn-mode wizard)
 * will scope this per-device instead of a single global on/off switch.
 *
 * ponytail: a permanently-STATE_PAUSED session can lose media-button delivery priority to
 * the system after it stops looking "recently active" on some OEM/Android versions (see
 * docs/research/R3-android-media-button-reality.md). No re-activation workaround here —
 * Task 7's on-device compat matrix is where that gets characterized before we build one.
 */
object BtMediaButtonTrigger {
    private var session: MediaSessionCompat? = null

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getBoolean(PREF_KEY, false)

    fun start(context: Context) {
        if (!isEnabled(context)) return
        if (session != null) return

        val mediaSession = MediaSessionCompat(context.applicationContext, SESSION_TAG)
        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_STOP
                )
                // Placeholder state: this session never actually plays media, it only exists
                // to win media-button focus so KeyEvents route through onMediaButtonEvent.
                .setState(PlaybackStateCompat.STATE_PAUSED, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 0f)
                .build()
        )
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                val keyEvent = mediaButtonIntent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT) ?: return true
                if (keyEvent.action != KeyEvent.ACTION_DOWN || keyEvent.repeatCount != 0) return true
                val eventKey = mediaKeyEventKey(keyEvent.keyCode) ?: return true
                val attribution = attributionFor(keyEvent)
                BtLearnMode.emit(BtLearnEvent(eventKey = eventKey, deviceMac = null, attribution = attribution))

                val dao = TriggerDb.get(context.applicationContext).triggerDao()
                val action = MappingEngine(dao).resolve(eventKey, deviceMac = null)
                if (action != null) {
                    TriggerActionBridge.sendTrigger(TRIGGER_SOURCE, action)
                    return true
                }

                if (dao.mappingCount() == 0 && isLegacyToggleKey(keyEvent.keyCode)) {
                    TriggerActionBridge.sendTrigger(TRIGGER_SOURCE, "toggle")
                }
                return true
            }
        })
        mediaSession.isActive = true
        session = mediaSession
    }

    fun stop() {
        session?.isActive = false
        session?.release()
        session = null
    }

    private fun attributionFor(keyEvent: KeyEvent): String {
        if (keyEvent.deviceId < 0) return ATTRIBUTION_AMBIGUOUS
        return if (InputDevice.getDevice(keyEvent.deviceId) != null) ATTRIBUTION_INFERRED else ATTRIBUTION_AMBIGUOUS
    }
}

fun mediaKeyEventKey(keyCode: Int): String? =
    when (keyCode) {
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> "KEYCODE_MEDIA_PLAY_PAUSE"
        KeyEvent.KEYCODE_MEDIA_PLAY -> "KEYCODE_MEDIA_PLAY"
        KeyEvent.KEYCODE_MEDIA_PAUSE -> "KEYCODE_MEDIA_PAUSE"
        KeyEvent.KEYCODE_MEDIA_NEXT -> "KEYCODE_MEDIA_NEXT"
        KeyEvent.KEYCODE_MEDIA_PREVIOUS -> "KEYCODE_MEDIA_PREVIOUS"
        KeyEvent.KEYCODE_MEDIA_STOP -> "KEYCODE_MEDIA_STOP"
        else -> null
    }

private fun isLegacyToggleKey(keyCode: Int): Boolean =
    keyCode == KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE ||
        keyCode == KeyEvent.KEYCODE_MEDIA_PLAY ||
        keyCode == KeyEvent.KEYCODE_MEDIA_PAUSE
