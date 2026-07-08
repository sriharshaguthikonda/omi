package com.friend.ios.trigger.bt

object TriggerConfigCodec {
    fun deviceToMap(device: BtDevice): Map<String, Any?> =
        mapOf(
            "mac" to device.mac,
            "name" to device.name,
            "kind" to device.kind,
            "lastSeenMs" to device.lastSeenMs,
            "enabled" to device.enabled,
        )

    fun mappingToMap(mapping: ButtonMapping): Map<String, Any?> =
        mapOf(
            "id" to mapping.id,
            "deviceMac" to mapping.deviceMac,
            "eventKey" to mapping.eventKey,
            "action" to mapping.action,
            "attribution" to mapping.attribution,
            "createdMs" to mapping.createdMs,
        )

    fun learnEventToMap(event: BtLearnEvent): Map<String, Any?> =
        mapOf(
            "eventKey" to event.eventKey,
            "deviceMac" to event.deviceMac,
            "attribution" to event.attribution,
        )
}
