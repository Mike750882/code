package com.spellwithspeagle.android.service

import android.content.Context
import android.view.textservice.SentenceSuggestionsInfo
import android.view.textservice.SpellCheckerSession
import android.view.textservice.SuggestionsInfo
import android.view.textservice.TextInfo
import android.view.textservice.TextServicesManager
import java.util.Locale
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * A dictionary check, not a "did you mean" check -- the Android equivalent
 * of iOS's `UITextChecker`-based `SpellCheckService` (`Services/SpellCheckService.swift`).
 * Uses the system's on-device spell checker (`TextServicesManager`), no
 * network call, no API key, nothing leaves the device. A nudge to double
 * check, not a hard block -- it won't catch a typo landing on a different
 * real word, and it will flag legitimate things a spelling list often has
 * (names, uncommon words).
 *
 * If the device has no spell checker enabled at all (Settings -> System ->
 * Languages & input -> On-screen keyboard -> Spell checker), this silently
 * flags nothing rather than erroring -- a missing nudge is harmless, a false
 * positive would just be annoying.
 */
class SpellCheckService(context: Context) {
    private val textServicesManager =
        context.getSystemService(Context.TEXT_SERVICES_MANAGER_SERVICE) as? TextServicesManager

    suspend fun isMisspelled(word: String): Boolean {
        if (word.isBlank()) return false
        val manager = textServicesManager ?: return false

        return suspendCancellableCoroutine { continuation ->
            var session: SpellCheckerSession? = null
            val listener = object : SpellCheckerSession.SpellCheckerSessionListener {
                override fun onGetSuggestions(results: Array<out SuggestionsInfo>?) {
                    val attributes = results?.firstOrNull()?.suggestionsAttributes ?: 0
                    val looksLikeTypo = (attributes and SuggestionsInfo.RESULT_ATTR_LOOKS_LIKE_TYPO) != 0
                    if (continuation.isActive) continuation.resumeWith(Result.success(looksLikeTypo))
                    session?.close()
                }

                override fun onGetSentenceSuggestions(results: Array<out SentenceSuggestionsInfo>?) {}
            }

            session = runCatching { manager.newSpellCheckerSession(null, Locale.getDefault(), listener, true) }.getOrNull()
            val activeSession = session
            if (activeSession == null) {
                if (continuation.isActive) continuation.resumeWith(Result.success(false))
                return@suspendCancellableCoroutine
            }
            activeSession.getSuggestions(TextInfo(word), 1)
            continuation.invokeOnCancellation { activeSession.close() }
        }
    }
}
