package com.friend.ios.trigger.bt

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

class DeviceRegistry(
    private val context: Context,
    private val dao: TriggerDao = TriggerDb.get(context).triggerDao(),
    private val clockMs: () -> Long = { System.currentTimeMillis() },
) {
    fun listDevices(): List<BtDevice> = dao.listDevices()

    fun setEnabled(mac: String, enabled: Boolean) {
        dao.setDeviceEnabled(mac, enabled)
    }

    @SuppressLint("MissingPermission")
    fun refreshConnectedDevices(): List<BtDevice> {
        if (!hasBluetoothConnectPermission()) return dao.listDevices()
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return dao.listDevices()
        val seen = linkedMapOf<String, BtDevice>()

        collectConnected(bluetoothManager, BluetoothProfile.A2DP, "A2DP", seen)
        collectConnected(bluetoothManager, BluetoothProfile.HEADSET, "A2DP", seen)
        collectConnected(bluetoothManager, BluetoothProfile.GATT, "BLE_CUSTOM", seen)

        seen.values.forEach { device ->
            dao.upsertSeenDevice(
                mac = device.mac,
                name = device.name,
                kind = device.kind,
                lastSeenMs = device.lastSeenMs,
            )
        }
        return dao.listDevices()
    }

    @SuppressLint("MissingPermission")
    private fun collectConnected(
        bluetoothManager: BluetoothManager,
        profile: Int,
        kind: String,
        output: MutableMap<String, BtDevice>,
    ) {
        val devices = try {
            bluetoothManager.getConnectedDevices(profile)
        } catch (_: RuntimeException) {
            emptyList()
        }
        devices.forEach { device ->
            val mac = device.safeAddress() ?: return@forEach
            output[mac] = BtDevice(
                mac = mac,
                name = device.safeName() ?: "Bluetooth device",
                kind = kind,
                lastSeenMs = clockMs(),
                enabled = true,
            )
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    private fun BluetoothDevice.safeName(): String? =
        try {
            name
        } catch (_: SecurityException) {
            null
        }

    @SuppressLint("MissingPermission")
    private fun BluetoothDevice.safeAddress(): String? =
        try {
            address
        } catch (_: SecurityException) {
            null
        }
}
