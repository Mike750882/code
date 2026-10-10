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
            // Some engines leave tts.voice effectively silent until it's
            // explicitly assigned -- relying on the engine's own implicit
            // default meant speech only started working once a user opened
            // Settings and picked a voice (which does set it explicitly).
            // Setting a real default here up front means it just works.
            bestDefaultVoice()?.let { tts.voice = it }
            pending.forEach { it() }
            pending.clear()
        }
    }

    /** Best on-device (non-network) voice for the device's language, used as the default until a user picks one in Settings. */
    private fun bestDefaultVoice(): Voice? {
        val installed = runCatching { tts.voices ?: emptySet() }.getOrDefault(emptySet())
        val deviceLanguage = Locale.getDefault().language
        return installed
            .filterNot { it.isNetworkConnectionRequired }
            .filter { it.locale.language == deviceLanguage }
            .maxByOrNull { it.quality }
            ?: installed.filterNot { it.isNetworkConnectionRequired }.maxByOrNull { it.quality }
    }

    /**
     * A voice option for the Settings picker: [id] is the underlying
     * [Voice.getName] (opaque, engine-specific -- e.g. "en-us-x-tpf-local"),
     * stored as-is in [com.spellwithspeagle.android.data.model.Child.voiceIdentifier];
     * [label] is one of [FRIENDLY_VOICE_NAMES] -- Android TTS voices carry
     * no built-in friendly name the way iOS's AVSpeechSynthesisVoice list
     * does (no real "Samantha"/"Moira" here), so a short fixed name is
     * assigned to each of the handful offered, same spirit as iOS's curated
     * shortlist even though the underlying engine is different.
     */
    data class VoiceOption(val id: String, val label: String)

    /**
     * English accents most people actually reach for, in preference order;
     * [java.util.Locale.getCountry] (ISO 3166-1 alpha-2) of each.
     */
    private val PREFERRED_COUNTRIES = listOf("US", "GB", "AU", "CA", "IN", "NZ", "ZA", "IE", "NG")
    private val FRIENDLY_VOICE_NAMES = listOf("Ava", "Max", "Luna", "Leo", "Zoe")

    /**
     * Up to [FRIENDLY_VOICE_NAMES.size] on-device voices (no
     * [Voice.isNetworkConnectionRequired], matching this app's
     * on-device-only design), one per accent, nearest the top of
     * [PREFERRED_COUNTRIES] first. A bare emulator often has very few or
     * none installed at all -- Settings -> System -> Languages & input ->
     * Text-to-speech output -> (engine) -> Install voice data adds more,
     * and a real device typically ships with several already.
     */
    fun availableVoices(): List<VoiceOption> {
        val installed = runCatching { tts.voices ?: emptySet() }.getOrDefault(emptySet())
        val deviceLanguage = Locale.getDefault().language

        // One voice per accent (the best-quality one available for it) --
        // several identical-sounding duplicates per accent aren't useful to
        // offer, and would only crowd out other accents from the top 5.
        val bestPerCountry = installed
            .filterNot { it.isNetworkConnectionRequired }
            .filter { it.locale.language == deviceLanguage }
            .groupBy { it.locale.country }
            .mapNotNull { (_, voices) -> voices.maxByOrNull { it.quality } }

        val ordered = bestPerCountry.sortedBy { voice ->
            PREFERRED_COUNTRIES.indexOf(voice.locale.country).let { if (it == -1) Int.MAX_VALUE else it }
        }

        return ordered.take(FRIENDLY_VOICE_NAMES.size).mapIndexed { index, voice ->
            VoiceOption(id = voice.name, label = FRIENDLY_VOICE_NAMES[index])
        }
    }

    /** Speaks [text] once TTS has finished initializing, in [voiceId] if given and available. */
    fun speak(text: String, voiceId: String? = null) {
        val action: () -> Unit = {
            if (!voiceId.isNullOrBlank()) {
                val voice = tts.voices?.firstOrNull { it.name == voiceId }
                if (voice != null) tts.voice = voice
            }
            tts.stop()
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
        }
        if (isReady) action() else pending.add(action)
    }

    /** Speaks [text] and suspends until playback completes -- useful for sequencing (e.g. word, then feedback). */
    suspend fun speakAndAwait(text: String, voiceId: String? = null) {
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
            val action: () -> Unit = {
                if (!voiceId.isNullOrBlank()) {
                    val voice = tts.voices?.firstOrNull { it.name == voiceId }
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
