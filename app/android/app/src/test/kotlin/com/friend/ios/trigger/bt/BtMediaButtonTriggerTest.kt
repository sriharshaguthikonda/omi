package com.friend.ios.trigger.bt

import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BtMediaButtonTriggerTest {
    @Test
    fun supportedMediaKeycodesMapToStableEventKeys() {
        assertEquals("KEYCODE_MEDIA_PLAY_PAUSE", mediaKeyEventKey(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        assertEquals("KEYCODE_MEDIA_PLAY", mediaKeyEventKey(KeyEvent.KEYCODE_MEDIA_PLAY))
        assertEquals("KEYCODE_MEDIA_PAUSE", mediaKeyEventKey(KeyEvent.KEYCODE_MEDIA_PAUSE))
        assertEquals("KEYCODE_MEDIA_NEXT", mediaKeyEventKey(KeyEvent.KEYCODE_MEDIA_NEXT))
        assertEquals("KEYCODE_MEDIA_PREVIOUS", mediaKeyEventKey(KeyEvent.KEYCODE_MEDIA_PREVIOUS))
        assertEquals("KEYCODE_MEDIA_STOP", mediaKeyEventKey(KeyEvent.KEYCODE_MEDIA_STOP))
    }

    @Test
    fun unsupportedKeycodesAreIgnored() {
        assertNull(mediaKeyEventKey(KeyEvent.KEYCODE_VOLUME_UP))
    }
}
