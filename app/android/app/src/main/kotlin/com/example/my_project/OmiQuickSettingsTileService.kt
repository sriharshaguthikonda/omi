package com.friend.ios

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class OmiQuickSettingsTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        val sentToDart = TriggerActionBridge.sendTrigger(TRIGGER_SOURCE, TRIGGER_ACTION)
        if (!sentToDart) {
            launchAppWithTrigger()
        }
        updateTile()
    }

    private fun updateTile() {
        qsTile?.apply {
            label = getString(R.string.omi_qs_tile_label)
            state = Tile.STATE_INACTIVE
            // ponytail: recording state lives in Dart; keep tile state static until native gets a state mirror.
            updateTile()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun launchAppWithTrigger() {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(TRIGGER_SOURCE_EXTRA, TRIGGER_SOURCE)
            .putExtra(TRIGGER_ACTION_EXTRA, TRIGGER_ACTION)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            startActivityAndCollapse(intent)
        }
    }

    private companion object {
        const val TRIGGER_SOURCE = "qs_tile"
        const val TRIGGER_ACTION = "toggle"
        const val TRIGGER_SOURCE_EXTRA = "trigger_source"
        const val TRIGGER_ACTION_EXTRA = "trigger_action"
    }
}
