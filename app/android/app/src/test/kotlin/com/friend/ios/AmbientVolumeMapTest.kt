package com.friend.ios

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AmbientVolumeMapTest {
    @Test
    fun silenceUsesCalmFloorDerivedFromBase() {
        assertEquals(10, rmsToVolume(rms = 0.0, base = 25, floor = 8, ceil = 60))
    }

    @Test
    fun loudInputReachesCeil() {
        assertEquals(60, rmsToVolume(rms = 1.0, base = 25, floor = 8, ceil = 60))
    }

    @Test
    fun volumeIsMonotonicAcrossAmbientRms() {
        val quiet = rmsToVolume(rms = 0.02, base = 25, floor = 8, ceil = 60)
        val normal = rmsToVolume(rms = 0.18, base = 25, floor = 8, ceil = 60)
        val loud = rmsToVolume(rms = 0.65, base = 25, floor = 8, ceil = 60)

        assertTrue(quiet <= normal)
        assertTrue(normal <= loud)
    }

    @Test
    fun clampsInvalidInputsToBounds() {
        assertEquals(8, rmsToVolume(rms = -1.0, base = 0, floor = 8, ceil = 60))
        assertEquals(60, rmsToVolume(rms = 10.0, base = 100, floor = 8, ceil = 60))
    }
}
