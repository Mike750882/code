package com.spellwithspeagle.android.service

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.MessageDigest

/**
 * The parent PIN gate, Android equivalent of the iOS Keychain-backed
 * `ParentGate`. Shared across every child profile on the device -- one
 * parent, one PIN, regardless of which kid's data is being edited.
 *
 * Uses [EncryptedSharedPreferences] (AES-256, key material in the Android
 * Keystore) rather than [androidx.datastore], since the file itself needs
 * to disappear on a real uninstall -- `allowBackup="false"` plus
 * `data_extraction_rules.xml` (excluding the "sharedpref" domain from both
 * cloud backup and device-to-device transfer) keeps this PIN from quietly
 * surviving a fresh install the way an iCloud Keychain entry used to on
 * iOS before that was intentionally made device-local too. It *does*
 * survive a normal app update, same as Keychain, since Android preserves
 * app-private storage across updates.
 */
class PinService(context: Context) {
    private val prefs: SharedPreferences = run {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "spell_with_speagle_pin",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun hasPin(): Boolean = prefs.contains(KEY_PIN_HASH)

    fun setPin(pin: String) {
        prefs.edit().putString(KEY_PIN_HASH, hash(pin)).apply()
    }

    fun verify(pin: String): Boolean = prefs.getString(KEY_PIN_HASH, null) == hash(pin)

    fun clearPin() {
        prefs.edit().remove(KEY_PIN_HASH).apply()
    }

    private fun hash(pin: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(pin.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    private companion object {
        const val KEY_PIN_HASH = "pin_hash"
    }
}
