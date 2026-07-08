package com.friend.ios.trigger.bt

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class DeviceRegistryTest {
    private val db = Room.inMemoryDatabaseBuilder(
        ApplicationProvider.getApplicationContext<Context>(),
        TriggerDb::class.java,
    ).allowMainThreadQueries().build()
    private val dao = db.triggerDao()

    @After
    fun tearDown() {
        db.close()
    }

    @Test
    fun upsertOnReconnectUpdatesLastSeenWithoutReenablingDisabledDevice() {
        dao.upsertDevice(BtDevice(mac = "AA:BB", name = "Headset", kind = "A2DP", lastSeenMs = 100, enabled = true))
        dao.setDeviceEnabled("AA:BB", false)

        dao.upsertSeenDevice(mac = "AA:BB", name = "Headset v2", kind = "A2DP", lastSeenMs = 250)

        val device = dao.getDevice("AA:BB")
        assertEquals("Headset v2", device?.name)
        assertEquals(250, device?.lastSeenMs)
        assertFalse(device?.enabled ?: true)
    }

    @Test
    fun mappingRoundTripPersistsDeviceScopedAndGlobalRows() {
        dao.upsertMapping(
            ButtonMapping(
                deviceMac = "AA:BB",
                eventKey = "KEYCODE_MEDIA_NEXT",
                action = "start",
                attribution = "CONFIRMED",
                createdMs = 10,
            )
        )
        dao.upsertMapping(
            ButtonMapping(
                deviceMac = null,
                eventKey = "KEYCODE_MEDIA_PLAY_PAUSE",
                action = "toggle",
                attribution = "AMBIGUOUS",
                createdMs = 20,
            )
        )

        assertEquals("start", dao.findDeviceMapping("KEYCODE_MEDIA_NEXT", "AA:BB")?.action)
        assertEquals("toggle", dao.findGlobalMapping("KEYCODE_MEDIA_PLAY_PAUSE")?.action)
        assertEquals(2, dao.listMappings().size)
    }
}
