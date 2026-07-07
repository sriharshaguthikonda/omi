package com.friend.ios

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TRIGGER_ACTION_CHANNEL = "com.friend.ios/trigger_actions"
private const val TRIGGER_SOURCE_EXTRA = "trigger_source"
private const val TRIGGER_ACTION_EXTRA = "trigger_action"

object TriggerActionBridge {
    private var channel: MethodChannel? = null
    private val pendingTriggers = mutableListOf<Map<String, String>>()

    fun attach(channel: MethodChannel, launchIntent: Intent?) {
        this.channel = channel
        enqueueIntent(launchIntent)
    }

    fun detach(channel: MethodChannel) {
        if (this.channel == channel) {
            this.channel = null
        }
    }

    fun enqueueIntent(intent: Intent?) {
        val trigger = intent?.toTriggerMap() ?: return
        pendingTriggers.add(trigger)
    }

    fun drainPendingTriggers(): List<Map<String, String>> {
        val drained = pendingTriggers.toList()
        pendingTriggers.clear()
        return drained
    }

    fun sendTrigger(source: String, action: String): Boolean {
        val trigger = mapOf(TRIGGER_SOURCE_EXTRA to source, TRIGGER_ACTION_EXTRA to action)
        val currentChannel = channel ?: return false
        currentChannel.invokeMethod("triggerCapture", trigger)
        return true
    }

    private fun Intent.toTriggerMap(): Map<String, String>? {
        val source = getStringExtra(TRIGGER_SOURCE_EXTRA) ?: return null
        val action = getStringExtra(TRIGGER_ACTION_EXTRA) ?: return null
        return mapOf(TRIGGER_SOURCE_EXTRA to source, TRIGGER_ACTION_EXTRA to action)
    }
}

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.friend.ios/notifyOnKill"
    private val NATIVE_BLE_TRANSCRIPT_CHANNEL = "com.friend.ios/native_ble_transcript"
    private var bleHostApiImpl: BleHostApiImpl? = null
    private var triggerActionChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register WiFi Network Plugin
        WifiNetworkPlugin.registerWith(flutterEngine, this)

        // Register Phone Calls Plugin
        PhoneCallsPlugin.registerWith(flutterEngine, this)

        // Register on-device Moonshine STT bridge
        MoonshineSttPlugin.registerWith(flutterEngine, applicationContext)

        // Register Native BLE Pigeon APIs
        OmiBleManager.initialize(application)
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.nativeBleForegroundReady", false)
            .apply()
        OmiBleManager.isFlutterAlive = true
        OmiBleManager.instance.flutterApi = BleFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        val hostApi = BleHostApiImpl { this }
        hostApi.initCompanionManager(this)
        bleHostApiImpl = hostApi
        BleHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, hostApi)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_BLE_TRANSCRIPT_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "drain") {
                result.success(OmiBackgroundAudioStreamer.drainCachedTranscriptMessages())
            } else {
                result.notImplemented()
            }
        }

        val triggerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRIGGER_ACTION_CHANNEL)
        triggerActionChannel = triggerChannel
        TriggerActionBridge.attach(triggerChannel, intent)
        triggerChannel.setMethodCallHandler { call, result ->
            if (call.method == "drainPendingTriggers") {
                result.success(TriggerActionBridge.drainPendingTriggers())
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if(call.method == "setNotificationOnKillService"){
                 val title = call.argument<String>("title")
                val description = call.argument<String>("description")

                val serviceIntent = Intent(this, NotificationOnKillService::class.java)

                serviceIntent.putExtra("title", title)
                serviceIntent.putExtra("description", description)

                startService(serviceIntent)
                result.success(true)
            }else{
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val source = intent.getStringExtra(TRIGGER_SOURCE_EXTRA) ?: return
        val action = intent.getStringExtra(TRIGGER_ACTION_EXTRA) ?: return
        if (!TriggerActionBridge.sendTrigger(source, action)) {
            TriggerActionBridge.enqueueIntent(intent)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        // Handle CompanionDeviceManager chooser result
        val address = bleHostApiImpl?.onActivityResult(requestCode, resultCode, data)
        if (address != null) {
            // Device selected — start foreground service (Dart will call manageDevice)
            OmiBleForegroundService.startService(this, address, caller = "MainActivity.onActivityResult")
        }
    }

    override fun onResume() {
        super.onResume()
        OmiBleManager.isAppForeground = true
    }

    override fun onPause() {
        OmiBleManager.isAppForeground = false
        super.onPause()
    }

    override fun onDestroy() {
        triggerActionChannel?.let { TriggerActionBridge.detach(it) }
        triggerActionChannel = null
        if (isFinishing) {
            OmiBleManager.isFlutterAlive = false
            // With Background Mode on, the foreground service keeps the pendant connected and
            // transcribing after a task close. With it off (default), tear it down so the device
            // disconnects when the app is closed.
            if (!OmiBleForegroundService.isBackgroundModeEnabled(this)) {
                OmiBleForegroundService.stopService(this)
            }
        }
        super.onDestroy()
    }
}
