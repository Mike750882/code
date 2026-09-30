package com.spellwithspeagle.android.service

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.first

/**
 * Wraps Android's on-device [TextToSpeech] -- the Android equivalent of
 * AVSpeechSynthesizer on iOS. No network call, no third-party library,
 * matching this app's on-device-only design.
 */
class SpeechService(context: Context) {
    private var isReady = false
    private val pending = mutableListOf<() -> Unit>()

    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { status ->
        isReady = status == TextToSpeech.SUCCESS
        if (isReady) {
            tts.language = Locale.getDefault()
            pending.forEach { it() }
            pending.clear()
        }
    }

    /**
     * Curated shortlist of voice names to offer in Settings, mirroring
     * iOS's `SettingsView.allowedVoiceNames`. Not every name will have a
     * matching installed Android TTS voice on every device -- [availableVoices]
     * filters this list down to what's actually installed.
     */
    val allowedVoiceNames = listOf("Tessa", "Superstar", "Samantha", "Rishi", "Moira", "Kathy", "Karen", "Junior", "Fred", "Daniel")

    /** Installed system voices whose name contains one of [allowedVoiceNames], in that preference order. */
    fun availableVoices(): List<Voice> {
        val installed = runCatching { tts.voices ?: emptySet() }.getOrDefault(emptySet())
        return allowedVoiceNames.mapNotNull { wanted ->
            installed.firstOrNull { it.name.contains(wanted, ignoreCase = true) }
        }
    }

    /** Speaks [text] once TTS has finished initializing, in [voiceName] if given and available. */
    fun speak(text: String, voiceName: String? = null) {
        val action = {
            if (!voiceName.isNullOrBlank()) {
                val voice = tts.voices?.firstOrNull { it.name.contains(voiceName, ignoreCase = true) }
                if (voice != null) tts.voice = voice
            }
            tts.stop()
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
        }
        if (isReady) action() else pending.add(action)
    }

    /** Speaks [text] and suspends until playback completes -- useful for sequencing (e.g. word, then feedback). */
    suspend fun speakAndAwait(text: String, voiceName: String? = null) {
        val utteranceId = UUID.randomUUID().toString()
        callbackFlow {
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                override fun onDone(id: String?) {
                    if (id == utteranceId) trySend(Unit)
                }
                @Deprecated("Deprecated in Java")
                override fun onError(id: String?) {
                    if (id == utteranceId) trySend(Unit)
                }
            })
            val action = {
                if (!voiceName.isNullOrBlank()) {
                    val voice = tts.voices?.firstOrNull { it.name.contains(voiceName, ignoreCase = true) }
                    if (voice != null) tts.voice = voice
                }
                tts.stop()
                tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
            }
            if (isReady) action() else pending.add(action)
            awaitClose { }
        }.first()
    }

    fun shutdown() {
        tts.stop()
        tts.shutdown()
    }
}
