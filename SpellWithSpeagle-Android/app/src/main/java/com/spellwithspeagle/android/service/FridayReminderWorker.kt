package com.spellwithspeagle.android.service

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.util.Calendar
import java.util.concurrent.TimeUnit

private const val WORK_NAME = "friday_test_reminder"
private const val CHANNEL_ID = "friday_reminder"
private const val NOTIFICATION_ID = 1001
private const val KEY_HOUR = "hour"
private const val KEY_MINUTE = "minute"

/**
 * Schedules a local, on-device weekly reminder -- the Android equivalent of
 * iOS's repeating `UNCalendarNotificationTrigger`. WorkManager has no native
 * "every Friday at HH:mm" schedule (periodic work can't target a specific
 * day of week), so this enqueues a single one-time request timed for the
 * next Friday; [FridayReminderWorker] re-enqueues the following week's
 * request itself after firing.
 */
object FridayReminderScheduler {
    fun ensureChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Friday test reminder",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "A weekly reminder to practice before Friday's spelling test."
        }
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    fun schedule(context: Context, hour: Int, minute: Int) {
        val request = OneTimeWorkRequestBuilder<FridayReminderWorker>()
            .setInitialDelay(delayUntilNextFriday(hour, minute), TimeUnit.MILLISECONDS)
            .setInputData(workDataOf(KEY_HOUR to hour, KEY_MINUTE to minute))
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, request)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    private fun delayUntilNextFriday(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val target = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        while (target.get(Calendar.DAY_OF_WEEK) != Calendar.FRIDAY || !target.after(now)) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }
        return target.timeInMillis - now.timeInMillis
    }

    internal fun showNotification(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("Practice For Today's Test")
            .setContentText("It's Friday! Review this week's spelling words before today's test.")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    internal fun reschedule(context: Context, hour: Int, minute: Int) = schedule(context, hour, minute)
}

class FridayReminderWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        FridayReminderScheduler.showNotification(applicationContext)
        val hour = inputData.getInt(KEY_HOUR, 7)
        val minute = inputData.getInt(KEY_MINUTE, 0)
        FridayReminderScheduler.reschedule(applicationContext, hour, minute)
        return Result.success()
    }
}
