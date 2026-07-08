package com.friend.ios.trigger.bt

data class BtLearnEvent(
    val eventKey: String,
    val deviceMac: String?,
    val attribution: String,
)

object BtLearnMode {
    @Volatile private var listener: ((BtLearnEvent) -> Unit)? = null

    fun start(listener: (BtLearnEvent) -> Unit) {
        this.listener = listener
    }

    fun stop() {
        listener = null
    }

    fun emit(event: BtLearnEvent) {
        listener?.invoke(event)
    }
}
