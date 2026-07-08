package com.friend.ios.trigger.bt

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Transaction

@Entity(tableName = "bt_devices")
data class BtDevice(
    @PrimaryKey val mac: String,
    val name: String,
    val kind: String,
    val lastSeenMs: Long,
    val enabled: Boolean = true,
)

@Entity(tableName = "button_mappings")
data class ButtonMapping(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val deviceMac: String?,
    val eventKey: String,
    val action: String,
    val attribution: String,
    val createdMs: Long,
)

@Dao
interface TriggerDao : ButtonMappingReader {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsertDevice(device: BtDevice)

    @Query("SELECT * FROM bt_devices WHERE mac = :mac LIMIT 1")
    fun getDevice(mac: String): BtDevice?

    @Query("SELECT * FROM bt_devices ORDER BY lastSeenMs DESC")
    fun listDevices(): List<BtDevice>

    @Query("UPDATE bt_devices SET enabled = :enabled WHERE mac = :mac")
    fun setDeviceEnabled(mac: String, enabled: Boolean)

    @Transaction
    fun upsertSeenDevice(mac: String, name: String, kind: String, lastSeenMs: Long) {
        val existing = getDevice(mac)
        upsertDevice(
            BtDevice(
                mac = mac,
                name = name,
                kind = kind,
                lastSeenMs = lastSeenMs,
                enabled = existing?.enabled ?: true,
            )
        )
    }

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsertMapping(mapping: ButtonMapping): Long

    @Query("DELETE FROM button_mappings WHERE id = :id")
    fun deleteMapping(id: Long)

    @Query("SELECT * FROM button_mappings ORDER BY createdMs DESC")
    fun listMappings(): List<ButtonMapping>

    @Query("SELECT * FROM button_mappings WHERE eventKey = :eventKey AND deviceMac = :deviceMac LIMIT 1")
    override
    fun findDeviceMapping(eventKey: String, deviceMac: String): ButtonMapping?

    @Query("SELECT * FROM button_mappings WHERE eventKey = :eventKey AND deviceMac IS NULL LIMIT 1")
    override
    fun findGlobalMapping(eventKey: String): ButtonMapping?

    @Query("SELECT COUNT(*) FROM button_mappings")
    fun mappingCount(): Int
}

interface ButtonMappingReader {
    fun findDeviceMapping(eventKey: String, deviceMac: String): ButtonMapping?

    fun findGlobalMapping(eventKey: String): ButtonMapping?
}

@Database(
    entities = [BtDevice::class, ButtonMapping::class],
    version = 1,
    exportSchema = false,
)
abstract class TriggerDb : RoomDatabase() {
    abstract fun triggerDao(): TriggerDao

    companion object {
        @Volatile private var instance: TriggerDb? = null

        fun get(context: Context): TriggerDb =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    TriggerDb::class.java,
                    "trigger.db",
                ).build().also { instance = it }
            }
    }
}
