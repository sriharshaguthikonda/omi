package com.friend.ios.trigger.bt

import org.junit.Assert.assertEquals
import org.junit.Test

class TriggerConfigCodecTest {
    @Test
    fun deviceMappingAndLearnEventsEncodeForMethodChannel() {
        val device = BtDevice(mac = "AA:BB", name = "Headset", kind = "A2DP", lastSeenMs = 10, enabled = false)
        val mapping = ButtonMapping(
            id = 7,
            deviceMac = null,
            eventKey = "KEYCODE_MEDIA_NEXT",
            action = "start",
            attribution = "AMBIGUOUS",
            createdMs = 20,
        )
        val event = BtLearnEvent(eventKey = "KEYCODE_MEDIA_STOP", deviceMac = null, attribution = "AMBIGUOUS")

        assertEquals("AA:BB", TriggerConfigCodec.deviceToMap(device)["mac"])
        assertEquals(false, TriggerConfigCodec.deviceToMap(device)["enabled"])
        assertEquals("start", TriggerConfigCodec.mappingToMap(mapping)["action"])
        assertEquals("KEYCODE_MEDIA_STOP", TriggerConfigCodec.learnEventToMap(event)["eventKey"])
    }
}
