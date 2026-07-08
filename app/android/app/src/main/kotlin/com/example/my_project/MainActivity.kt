package com.friend.ios

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import com.friend.ios.trigger.bt.BtLearnMode
import com.friend.ios.trigger.bt.BtMediaButtonTrigger
import com.friend.ios.trigger.bt.ButtonMapping
import com.friend.ios.trigger.bt.DeviceRegistry
import com.friend.ios.trigger.bt.TriggerConfigCodec
import com.friend.ios.trigger.bt.TriggerDb
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TRIGGER_ACTION_CHANNEL = "com.friend.ios/trigger_actions"
private const val TRIGGER_CONFIG_CHANNEL = "com.friend.ios/trigger_config"
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
    private var triggerConfigChannel: MethodChannel? = null

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
            when (call.method) {
                "drainPendingTriggers" -> result.success(TriggerActionBridge.drainPendingTriggers())
                "feedback" -> {
                    when (call.argument<String>("type")) {
                        "beepStart" -> TriggerFeedback.beepStart()
                        "beepStop" -> TriggerFeedback.beepStop()
                        "beepStillListening" -> TriggerFeedback.beepStillListening()
                        else -> {
                            result.error("invalid_feedback", "Unknown feedback type", null)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val configChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRIGGER_CONFIG_CHANNEL)
        triggerConfigChannel = configChannel
        val triggerDao = TriggerDb.get(applicationContext).triggerDao()
        val deviceRegistry = DeviceRegistry(applicationContext, triggerDao)
        configChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listDevices" -> result.success(
                    deviceRegistry.refreshConnectedDevices().map(TriggerConfigCodec::deviceToMap)
                )
                "setDeviceEnabled" -> {
                    val mac = call.argument<String>("mac")
                    val enabled = call.argument<Boolean>("enabled")
                    if (mac == null || enabled == null) {
                        result.error("invalid_args", "mac and enabled are required", null)
                        return@setMethodCallHandler
                    }
                    deviceRegistry.setEnabled(mac, enabled)
                    result.success(true)
                }
                "listMappings" -> result.success(triggerDao.listMappings().map(TriggerConfigCodec::mappingToMap))
                "upsertMapping" -> {
                    val eventKey = call.argument<String>("eventKey")
                    val action = call.argument<String>("action")
                    val attribution = call.argument<String>("attribution") ?: "AMBIGUOUS"
                    if (eventKey == null || action == null) {
                        result.error("invalid_args", "eventKey and action are required", null)
                        return@setMethodCallHandler
                    }
                    val id = call.argument<Number>("id")?.toLong() ?: 0L
                    val createdMs = call.argument<Number>("createdMs")?.toLong() ?: System.currentTimeMillis()
                    val mappingId = triggerDao.upsertMapping(
                        ButtonMapping(
                            id = id,
                            deviceMac = call.argument<String>("deviceMac"),
                            eventKey = eventKey,
                            action = action,
                            attribution = attribution,
                            createdMs = createdMs,
                        )
                    )
                    result.success(mappingId)
                }
                "deleteMapping" -> {
                    val id = call.argument<Number>("id")?.toLong()
                    if (id == null) {
                        result.error("invalid_args", "id is required", null)
                        return@setMethodCallHandler
                    }
                    triggerDao.deleteMapping(id)
                    result.success(true)
                }
                "startLearnMode" -> {
                    BtLearnMode.start { event ->
                        runOnUiThread {
                            configChannel.invokeMethod("onLearnEvent", TriggerConfigCodec.learnEventToMap(event))
                        }
                    }
                    result.success(true)
                }
                "stopLearnMode" -> {
                    BtLearnMode.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // P3 increment 1: no-op unless the user opted in (see BtMediaButtonTrigger doc).
        BtMediaButtonTrigger.start(this)

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
        BtMediaButtonTrigger.stop()
        BtLearnMode.stop()
        triggerActionChannel?.let { TriggerActionBridge.detach(it) }
        triggerActionChannel = null
        triggerConfigChannel?.setMethodCallHandler(null)
        triggerConfigChannel = null
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
