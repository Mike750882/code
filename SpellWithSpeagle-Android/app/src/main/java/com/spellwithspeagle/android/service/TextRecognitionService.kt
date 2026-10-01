package com.spellwithspeagle.android.service

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * On-device OCR for "Import a list" -- the Android equivalent of iOS's
 * Vision-framework-based `TextRecognitionService`. ML Kit's on-device text
 * recognizer ships its model with the app; no network call, the photo never
 * leaves the device.
 */
class TextRecognitionService {
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    /** One recognized line per word, trimmed, blank lines dropped. */
    suspend fun recognizeWords(bitmap: Bitmap): List<String> = suspendCancellableCoroutine { continuation ->
        val image = InputImage.fromBitmap(bitmap, 0)
        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                val words = visionText.text.lines().map { it.trim() }.filter { it.isNotEmpty() }
                if (continuation.isActive) continuation.resume(words)
            }
            .addOnFailureListener {
                if (continuation.isActive) continuation.resume(emptyList())
            }
    }
}
