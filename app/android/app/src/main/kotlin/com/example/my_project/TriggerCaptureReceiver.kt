package com.friend.ios

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Exported entry point for external senders (Tasker, other automation apps) to
 * start/stop/toggle capture via an explicit broadcast intent:
 *   am broadcast -a com.friend.ios.TRIGGER_CAPTURE --es trigger_action toggle
 * Security gate (default OFF) lives on the Dart side in TriggerRouter — this
 * receiver only forwards the action, it does not decide whether to honor it.
 */
class TriggerCaptureReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TRIGGER_CAPTURE_ACTION) return
        val action = intent.getStringExtra(TRIGGER_ACTION_EXTRA) ?: TRIGGER_ACTION

        if (TriggerActionBridge.sendTrigger(TRIGGER_SOURCE, action)) return

        val launchIntent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(TRIGGER_SOURCE_EXTRA, TRIGGER_SOURCE)
            .putExtra(TRIGGER_ACTION_EXTRA, action)
        context.startActivity(launchIntent)
    }

    private companion object {
        const val TRIGGER_CAPTURE_ACTION = "com.friend.ios.TRIGGER_CAPTURE"
        const val TRIGGER_SOURCE = "external_intent"
        const val TRIGGER_ACTION = "toggle"
        const val TRIGGER_SOURCE_EXTRA = "trigger_source"
        const val TRIGGER_ACTION_EXTRA = "trigger_action"
    }
}
