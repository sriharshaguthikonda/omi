package com.friend.ios.trigger.bt

typealias TriggerAction = String

class MappingEngine(
    private val reader: ButtonMappingReader,
) {
    fun resolve(eventKey: String, deviceMac: String?): TriggerAction? {
        val normalizedEventKey = eventKey.trim()
        if (normalizedEventKey.isEmpty()) return null

        if (!deviceMac.isNullOrBlank()) {
            reader.findDeviceMapping(normalizedEventKey, deviceMac)?.let { return it.action }
        }

        return reader.findGlobalMapping(normalizedEventKey)?.action
    }
}
