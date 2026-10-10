package com.spellwithspeagle.android.service

import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.DailyReward
import com.spellwithspeagle.android.data.model.PracticeAttempt
import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.model.WeekList
import com.spellwithspeagle.android.data.model.WeeklyPrize
import com.spellwithspeagle.android.data.repository.SpellingRepository
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

private const val BACKUP_FILE_NAME = "spellwithspeagle-backup.json"
private const val DRIVE_FILES_URL = "https://www.googleapis.com/drive/v3/files"
private const val DRIVE_UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3/files"

/**
 * Backs up and restores all six Room tables as one JSON file in the
 * signed-in family's own Google Drive -- not a live sync, an explicit
 * "Back up now" / "Restore" action a parent takes from Settings. Talks
 * to the Drive v3 REST API directly over plain HTTP (no Firebase, no
 * server of ours, no extra client library) using the OAuth token
 * [AuthService] provides, scoped ([DRIVE_FILE_SCOPE]) so this app can
 * only ever see the one file it creates -- never the rest of a family's
 * Drive -- and that file stays visible and deletable by them at any
 * time, independent of whether the app is still installed.
 */
class DriveBackupService(private val authService: AuthService) {

    suspend fun backup(repository: SpellingRepository): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val token = authService.driveAccessToken().getOrThrow()
            val content = buildBackupJson(repository).toString()
            val fileId = findBackupFileId(token)
            if (fileId != null) updateFile(token, fileId, content) else createFile(token, content)
        }
    }

    suspend fun restore(repository: SpellingRepository): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val token = authService.driveAccessToken().getOrThrow()
            val fileId = findBackupFileId(token) ?: error("No backup found in Google Drive yet.")
            val json = JSONObject(downloadFile(token, fileId))
            applyBackupJson(json, repository)
        }
    }

    // --- Gathering/applying everything in Room ---

    private suspend fun buildBackupJson(repository: SpellingRepository): JSONObject {
        val children = JSONArray()
        val weekLists = JSONArray()
        val words = JSONArray()
        val attempts = JSONArray()
        val rewards = JSONArray()
        val prizes = JSONArray()

        repository.observeChildren().first().forEach { child ->
            children.put(child.toJson())
            val childWeekLists = repository.observeWeekLists(child.id).first()
            childWeekLists.forEach { weekList ->
                weekLists.put(weekList.toJson())
                repository.observeWords(weekList.id).first().forEach { word ->
                    words.put(word.toJson())
                    repository.attemptsForWords(listOf(word.id)).forEach { attempts.put(it.toJson()) }
                }
                repository.observeDailyRewards(child.id, weekList.weekOf).first().forEach { rewards.put(it.toJson()) }
                repository.observeWeeklyPrize(child.id, weekList.weekOf).first()?.let { prizes.put(it.toJson()) }
            }
        }

        return JSONObject().apply {
            put("version", 1)
            put("children", children)
            put("weekLists", weekLists)
            put("spellingWords", words)
            put("practiceAttempts", attempts)
            put("dailyRewards", rewards)
            put("weeklyPrizes", prizes)
        }
    }

    /** Order matters: children before weekLists before words before attempts, so each row's foreign key already exists by the time it's inserted. */
    private suspend fun applyBackupJson(json: JSONObject, repository: SpellingRepository) {
        json.optJSONArray("children")?.forEachObject { repository.upsertChildFromBackup(it.toChild()) }
        json.optJSONArray("weekLists")?.forEachObject { repository.upsertWeekListFromBackup(it.toWeekList()) }
        json.optJSONArray("spellingWords")?.forEachObject { repository.upsertWordFromBackup(it.toSpellingWord()) }
        json.optJSONArray("practiceAttempts")?.forEachObject { repository.upsertAttemptFromBackup(it.toPracticeAttempt()) }
        json.optJSONArray("dailyRewards")?.forEachObject { repository.upsertDailyRewardFromBackup(it.toDailyReward()) }
        json.optJSONArray("weeklyPrizes")?.forEachObject { repository.upsertWeeklyPrizeFromBackup(it.toWeeklyPrize()) }
    }

    // --- Drive v3 REST calls ---

    private fun findBackupFileId(token: String): String? {
        val query = URLEncoder.encode("name = '$BACKUP_FILE_NAME' and trashed = false", "UTF-8")
        val connection = openConnection("$DRIVE_FILES_URL?q=$query&spaces=drive&fields=files(id,name)", "GET", token)
        val files = JSONObject(connection.readResponse()).optJSONArray("files") ?: return null
        return if (files.length() > 0) files.getJSONObject(0).getString("id") else null
    }

    private fun createFile(token: String, content: String) {
        val metadata = JSONObject().apply {
            put("name", BACKUP_FILE_NAME)
            put("mimeType", "application/json")
        }
        upload("$DRIVE_UPLOAD_URL?uploadType=multipart", "POST", token, metadata.toString(), content)
    }

    private fun updateFile(token: String, fileId: String, content: String) {
        upload("$DRIVE_UPLOAD_URL/$fileId?uploadType=multipart", "PATCH", token, "{}", content)
    }

    private fun downloadFile(token: String, fileId: String): String =
        openConnection("$DRIVE_FILES_URL/$fileId?alt=media", "GET", token).readResponse()

    private fun upload(url: String, method: String, token: String, metadataJson: String, content: String) {
        val boundary = "spellwithspeagle-${UUID.randomUUID()}"
        val body = buildString {
            append("--$boundary\r\n")
            append("Content-Type: application/json; charset=UTF-8\r\n\r\n")
            append(metadataJson)
            append("\r\n--$boundary\r\n")
            append("Content-Type: application/json\r\n\r\n")
            append(content)
            append("\r\n--$boundary--")
        }
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            doOutput = true
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "multipart/related; boundary=$boundary")
        }
        connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
        connection.readResponse()
    }

    private fun openConnection(url: String, method: String, token: String): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            setRequestProperty("Authorization", "Bearer $token")
        }

    private fun HttpURLConnection.readResponse(): String {
        val code = responseCode
        val text = (if (code in 200..299) inputStream else errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
        if (code !in 200..299) error("Drive request failed ($code): $text")
        return text
    }
}

private inline fun JSONArray.forEachObject(action: (JSONObject) -> Unit) {
    for (i in 0 until length()) action(getJSONObject(i))
}

// --- Entity <-> JSON mapping ---

private fun Child.toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("name", name)
    put("textScale", textScale)
    put("appearance", appearance)
    put("colorProfile", colorProfile)
    put("voiceIdentifier", voiceIdentifier)
    put("createdAt", createdAt)
    put("mondayInputMode", mondayInputMode)
    put("tuesdayInputMode", tuesdayInputMode)
    put("wednesdayInputMode", wednesdayInputMode)
    put("thursdayInputMode", thursdayInputMode)
    put("fridayNotificationEnabled", fridayNotificationEnabled)
    put("fridayNotificationHour", fridayNotificationHour)
    put("fridayNotificationMinute", fridayNotificationMinute)
    put("allowHintsDuringTest", allowHintsDuringTest)
}

private fun JSONObject.toChild(): Child = Child(
    id = getString("id"),
    name = optString("name", ""),
    textScale = optDouble("textScale", 1.0),
    appearance = optString("appearance", "system"),
    colorProfile = optString("colorProfile", "default"),
    voiceIdentifier = optString("voiceIdentifier", ""),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    mondayInputMode = optString("mondayInputMode", "TILES_SCAFFOLDED"),
    tuesdayInputMode = optString("tuesdayInputMode", "TILES_FULL"),
    wednesdayInputMode = optString("wednesdayInputMode", "HALF_AND_HALF"),
    thursdayInputMode = optString("thursdayInputMode", "TYPED"),
    fridayNotificationEnabled = optBoolean("fridayNotificationEnabled", false),
    fridayNotificationHour = optInt("fridayNotificationHour", 7),
    fridayNotificationMinute = optInt("fridayNotificationMinute", 0),
    allowHintsDuringTest = optBoolean("allowHintsDuringTest", false)
)

private fun WeekList.toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("childId", childId)
    put("weekOf", weekOf)
    put("targetWordCount", targetWordCount)
}

private fun JSONObject.toWeekList(): WeekList = WeekList(
    id = getString("id"),
    childId = optString("childId", ""),
    weekOf = optLong("weekOf", 0L),
    targetWordCount = optInt("targetWordCount", 12)
)

private fun SpellingWord.toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("weekListId", weekListId)
    put("text", text)
    put("orderIndex", orderIndex)
    put("hint", hint)
    put("customAudioPath", customAudioPath ?: JSONObject.NULL)
}

private fun JSONObject.toSpellingWord(): SpellingWord = SpellingWord(
    id = getString("id"),
    weekListId = optString("weekListId", ""),
    text = optString("text", ""),
    orderIndex = optInt("orderIndex", 0),
    hint = optString("hint", ""),
    customAudioPath = if (isNull("customAudioPath")) null else optString("customAudioPath")
)

private fun PracticeAttempt.toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("wordId", wordId)
    put("date", date)
    put("isCorrect", isCorrect)
    put("mode", mode.name)
    put("sessionId", sessionId)
}

private fun JSONObject.toPracticeAttempt(): PracticeAttempt = PracticeAttempt(
    id = getString("id"),
    wordId = optString("wordId", ""),
    date = optLong("date", System.currentTimeMillis()),
    isCorrect = optBoolean("isCorrect", false),
    mode = runCatching { PracticeMode.valueOf(optString("mode", "PRACTICE")) }.getOrDefault(PracticeMode.PRACTICE),
    sessionId = optString("sessionId", "")
)

private fun DailyReward.toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("childId", childId)
    put("weekOf", weekOf)
    put("weekday", weekday)
    put("rewardText", rewardText)
    put("thresholdPercent", thresholdPercent)
}

private fun JSONObject.toDailyReward(): DailyReward = DailyReward(
    id = getString("id"),
    childId = optString("childId", ""),
    weekOf = optLong("weekOf", 0L),
    weekday = optInt("weekday", 2),
    rewardText = optString("rewardText", ""),
    thresholdPercent = optInt("thresholdPercent", 70)
)

private fun WeeklyPrize.toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("childId", childId)
    put("weekOf", weekOf)
    put("title", title)
    put("thresholdPercent", thresholdPercent)
}

private fun JSONObject.toWeeklyPrize(): WeeklyPrize = WeeklyPrize(
    id = getString("id"),
    childId = optString("childId", ""),
    weekOf = optLong("weekOf", 0L),
    title = optString("title", ""),
    thresholdPercent = optInt("thresholdPercent", 80)
)
