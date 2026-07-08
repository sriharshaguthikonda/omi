package com.friend.ios.trigger.bt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MappingEngineTest {
    @Test
    fun deviceScopedMappingBeatsGlobalMapping() {
        val engine = MappingEngine(
            FakeMappingReader(
                deviceMappings = mapOf("AA:BB|KEYCODE_MEDIA_NEXT" to mapping("start", "AA:BB", "KEYCODE_MEDIA_NEXT")),
                globalMappings = mapOf("KEYCODE_MEDIA_NEXT" to mapping("toggle", null, "KEYCODE_MEDIA_NEXT")),
            )
        )

        assertEquals("start", engine.resolve("KEYCODE_MEDIA_NEXT", "AA:BB"))
    }

    @Test
    fun ambiguousEventMatchesGlobalMapping() {
        val engine = MappingEngine(
            FakeMappingReader(
                globalMappings = mapOf("KEYCODE_MEDIA_PLAY_PAUSE" to mapping("toggle", null, "KEYCODE_MEDIA_PLAY_PAUSE"))
            )
        )

        assertEquals("toggle", engine.resolve("KEYCODE_MEDIA_PLAY_PAUSE", null))
    }

    @Test
    fun unmappedEventReturnsNull() {
        val engine = MappingEngine(FakeMappingReader())

        assertNull(engine.resolve("KEYCODE_MEDIA_STOP", null))
    }

    private fun mapping(action: String, deviceMac: String?, eventKey: String): ButtonMapping =
        ButtonMapping(
            deviceMac = deviceMac,
            eventKey = eventKey,
            action = action,
            attribution = if (deviceMac == null) "AMBIGUOUS" else "CONFIRMED",
            createdMs = 1,
        )

    private class FakeMappingReader(
        private val deviceMappings: Map<String, ButtonMapping> = emptyMap(),
        private val globalMappings: Map<String, ButtonMapping> = emptyMap(),
    ) : ButtonMappingReader {
        override fun findDeviceMapping(eventKey: String, deviceMac: String): ButtonMapping? =
            deviceMappings["$deviceMac|$eventKey"]

        override fun findGlobalMapping(eventKey: String): ButtonMapping? =
            globalMappings[eventKey]
    }
}
