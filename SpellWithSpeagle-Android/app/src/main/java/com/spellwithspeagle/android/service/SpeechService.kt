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
     * A voice option for the Settings picker: [id] is the underlying
     * [Voice.getName] (opaque, engine-specific -- e.g. "en-us-x-tpf-local"),
     * stored as-is in [com.spellwithspeagle.android.data.model.Child.voiceIdentifier];
     * [label] is a readable string built from the voice's locale + quality
     * for display, since Android TTS voices don't have friendly names the
     * way iOS's AVSpeechSynthesisVoice list does (no "Samantha"/"Moira" here
     * -- those are Apple-specific personas with no Android equivalent).
     */
    data class VoiceOption(val id: String, val label: String)

    /**
     * Every installed on-device voice (no [Voice.isNetworkConnectionRequired],
     * matching this app's on-device-only design) matching the current
     * device language, best quality first. A bare emulator often has very
     * few or none installed at all -- Settings -> System -> Languages &
     * input -> Text-to-speech output -> (engine) -> Install voice data adds
     * more, and a real device typically ships with several already.
     */
    fun availableVoices(): List<VoiceOption> {
        val installed = runCatching { tts.voices ?: emptySet() }.getOrDefault(emptySet())
        val deviceLanguage = Locale.getDefault().language
        val sorted = installed
            .filterNot { it.isNetworkConnectionRequired }
            .filter { it.locale.language == deviceLanguage }
            .sortedWith(compareByDescending<Voice> { it.quality }.thenBy { it.locale.displayName }.thenBy { it.name })

        // Android TTS engines commonly register several distinct voices per
        // locale (different speaker models), but unlike iOS's named
        // AVSpeechSynthesisVoice list, Voice itself carries no friendly
        // per-voice name -- locale + quality is all there is to build a
        // label from, so same-locale/same-quality voices would otherwise
        // show as identical, indistinguishable rows. Number them instead.
        val baseLabelCounts = sorted.groupingBy { labelFor(it) }.eachCount()
        val seenSoFar = mutableMapOf<String, Int>()
        return sorted.map { voice ->
            val base = labelFor(voice)
            val label = if ((baseLabelCounts[base] ?: 1) > 1) {
                val n = (seenSoFar[base] ?: 0) + 1
                seenSoFar[base] = n
                "$base (Voice $n)"
            } else {
                base
            }
            VoiceOption(id = voice.name, label = label)
        }
    }

    private fun labelFor(voice: Voice): String {
        val qualityLabel = when (voice.quality) {
            Voice.QUALITY_VERY_HIGH -> "Very high quality"
            Voice.QUALITY_HIGH -> "High quality"
            Voice.QUALITY_NORMAL -> "Normal quality"
            Voice.QUALITY_LOW -> "Low quality"
            Voice.QUALITY_VERY_LOW -> "Very low quality"
            else -> null
        }
        val localeName = voice.locale.displayName
        return if (qualityLabel != null) "$localeName -- $qualityLabel" else localeName
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
