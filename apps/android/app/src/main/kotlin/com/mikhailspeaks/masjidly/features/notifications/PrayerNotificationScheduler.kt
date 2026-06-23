package com.mikhailspeaks.masjidly.features.notifications

import android.content.Context
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.NotificationSettings
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Android counterpart to iOS `PrayerNotificationScheduler.swift`.
 * Schedules up to 7 days of adhan, iqamah, and pre-reminders via exact alarms.
 */
class PrayerNotificationScheduler(
    private val context: Context,
    private val repository: PrayerRepository,
    private val diskCache: PrayerTimesDiskCache,
) {
    private val appContext = context.applicationContext
    private val alarmStore = PrayerNotificationAlarmStore(appContext)
    private val runLock = Mutex()
    private val runGeneration = AtomicInteger(0)
    private var addBudget = 0

    suspend fun requestAuthorizationIfNeeded(): Boolean {
        PrayerNotificationContent.ensureChannel(appContext)
        return PrayerNotificationPermissions.hasPostNotificationsPermission(appContext)
    }

    suspend fun cancelAllPrayerNotifications() {
        runLock.withLock {
            runGeneration.incrementAndGet()
            cancelAllForCurrentRun()
        }
    }

    suspend fun rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int = 7,
        settings: NotificationSettings,
        language: AppLanguage,
        asrIqamahPreference: AsrIqamahPreference,
    ) {
        runLock.withLock {
            rescheduleForCurrentRun(
                mosque = mosque,
                days = days,
                settings = settings,
                language = language,
                asrIqamahPreference = asrIqamahPreference,
            )
        }
    }

    private suspend fun rescheduleForCurrentRun(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        language: AppLanguage,
        asrIqamahPreference: AsrIqamahPreference,
    ) {
        val generation = runGeneration.incrementAndGet()
        scheduledThisRun.clear()
        cancelAllForCurrentRun()
        if (!settings.masterEnabled) return

        val granted = requestAuthorizationIfNeeded()
        if (!granted || !isCurrentGeneration(generation)) return

        addBudget = MAX_PENDING_NOTIFICATIONS

        val ukDst = repository.getUkDstDates()?.ukDstDates
            ?: diskCache.loadUkDst()?.ukDstDates
            ?: emptyList()
        val slug = mosque.slug
        val nowParts = PrayerTimesEngine.getDateInSheffield(Instant.now())
        val baseDay = LocalDate.of(nowParts.year, nowParts.month, nowParts.day)
            .atStartOfDay(PrayerTimesEngine.sheffieldTimeZone)
            .toInstant()

        for (offset in 0 until maxOf(1, days)) {
            if (!isCurrentGeneration(generation)) return
            val dayDate = baseDay.plus(offset.toLong(), ChronoUnit.DAYS)
            val comps = PrayerTimesEngine.getDateInSheffield(dayDate)
            val iso = PrayerTimesEngine.isoDateString(comps.year, comps.month, comps.day)
            val monthName = MonthName.from(comps.month) ?: continue

            val monthly = try {
                repository.getMonthlyPrayerTimes(slug, monthName, comps.year)
                    ?: diskCache.loadMonthly(slug, monthName.rawValue, comps.year)
            } catch (_: Exception) {
                diskCache.loadMonthly(slug, monthName.rawValue, comps.year)
            }
            val ramadan = try {
                repository.getRamadanTimetable(slug, iso)
                    ?: diskCache.loadRamadan(slug, iso)
            } catch (_: Exception) {
                diskCache.loadRamadan(slug, iso)
            }

            val displayed = try {
                val raw = PrayerTimesEngine.resolvePrayerTimes(
                    slug = slug,
                    on = dayDate,
                    monthly = monthly,
                    ramadan = ramadan,
                    ukDst = ukDst,
                    asrTimingPreference = asrIqamahPreference,
                )
                PrayerTimesEngine.getDisplayedPrayerTimes(raw, date = dayDate, mosqueSlug = slug)
            } catch (_: Exception) {
                continue
            }
            val iq = try {
                PrayerTimesEngine.resolveIqamahTimesWithDstMapping(
                    slug = slug,
                    on = dayDate,
                    monthly = monthly,
                    ramadan = ramadan,
                    ukDst = ukDst,
                )
            } catch (_: Exception) {
                continue
            }

            val isFriday = dayDate.atZone(PrayerTimesEngine.sheffieldTimeZone).dayOfWeek == DayOfWeek.FRIDAY

            scheduleAdhanIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.fajr.adhan",
                "masjidly.prayer.$slug.$iso.fajr.adhan_reminder",
                "fajr", displayed.fajr, isFriday, dayDate, language, generation,
            )
            scheduleIqamahIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.fajr.iqamah",
                "masjidly.prayer.$slug.$iso.fajr.iqamah_reminder",
                "fajr",
                PrayerTimesEngine.getIqamahTime("fajr", displayed.fajr, iq),
                isFriday, dayDate, language, generation,
            )

            val dhuhrTime = displayed.dhuhr
            scheduleAdhanIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.dhuhr.adhan",
                "masjidly.prayer.$slug.$iso.dhuhr.adhan_reminder",
                "dhuhr", dhuhrTime, isFriday, dayDate, language, generation,
            )
            val iqLabel = if (isFriday) iq.jummah else PrayerTimesEngine.getIqamahTime("dhuhr", dhuhrTime, iq)
            val iqPrayerKey = if (isFriday) "jummah" else "dhuhr"
            scheduleIqamahIfEnabled(
                settings, slug, iso,
                "masjidly.prayer.$slug.$iso.$iqPrayerKey.iqamah",
                "masjidly.prayer.$slug.$iso.$iqPrayerKey.iqamah_reminder",
                "dhuhr", iqLabel, isFriday, dayDate, language, generation,
            )

            scheduleAdhanIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.asr.adhan",
                "masjidly.prayer.$slug.$iso.asr.adhan_reminder",
                "asr", displayed.asr, isFriday, dayDate, language, generation,
            )
            scheduleIqamahIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.asr.iqamah",
                "masjidly.prayer.$slug.$iso.asr.iqamah_reminder",
                "asr",
                PrayerTimesEngine.selectAsrIqamahTime(iq.asr, displayed.asr, asrIqamahPreference),
                isFriday, dayDate, language, generation,
            )

            scheduleAdhanIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.maghrib.adhan",
                "masjidly.prayer.$slug.$iso.maghrib.adhan_reminder",
                "maghrib", displayed.maghrib, isFriday, dayDate, language, generation,
            )
            scheduleIqamahIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.maghrib.iqamah",
                "masjidly.prayer.$slug.$iso.maghrib.iqamah_reminder",
                "maghrib",
                PrayerTimesEngine.getIqamahTime("maghrib", displayed.maghrib, iq),
                isFriday, dayDate, language, generation,
            )

            scheduleAdhanIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.isha.adhan",
                "masjidly.prayer.$slug.$iso.isha.adhan_reminder",
                "isha", displayed.isha, isFriday, dayDate, language, generation,
            )
            scheduleIqamahIfEnabled(
                settings, slug, iso, "masjidly.prayer.$slug.$iso.isha.iqamah",
                "masjidly.prayer.$slug.$iso.isha.iqamah_reminder",
                "isha",
                PrayerTimesEngine.resolveIshaIqamahForDisplay(
                    slug = slug,
                    date = dayDate,
                    ishaAdhan = displayed.isha,
                    iqamahTimes = iq,
                    maghribAdhan = displayed.maghrib,
                ),
                isFriday, dayDate, language, generation,
            )
        }

        if (isCurrentGeneration(generation)) {
            finalizeRun()
        }
    }

    private fun isAdhanForPrayerEnabled(prayerKey: String, settings: NotificationSettings): Boolean =
        when (prayerKey) {
            "fajr" -> settings.adhanFajr
            "dhuhr" -> settings.adhanDhuhrJummah
            "asr" -> settings.adhanAsr
            "maghrib" -> settings.adhanMaghrib
            "isha" -> settings.adhanIsha
            else -> true
        }

    private fun isIqamahForPrayerEnabled(prayerKey: String, settings: NotificationSettings): Boolean =
        when (prayerKey) {
            "fajr" -> settings.iqamahFajr
            "dhuhr" -> settings.iqamahDhuhrJummah
            "asr" -> settings.iqamahAsr
            "maghrib" -> settings.iqamahMaghrib
            "isha" -> settings.iqamahIsha
            else -> true
        }

    private fun scheduleAdhanIfEnabled(
        settings: NotificationSettings,
        mosqueSlug: String,
        iso: String,
        id: String,
        reminderId: String,
        prayerKey: String,
        time: String,
        isFriday: Boolean,
        civilDay: Instant,
        language: AppLanguage,
        generation: Int,
    ) {
        if (!isAdhanForPrayerEnabled(prayerKey, settings)) return
        if (settings.adhanEnabled) {
            val (title, body) = PrayerNotificationContent.adhanCopy(prayerKey, isFriday, language)
            scheduleIfNeeded(
                id = id,
                title = title,
                body = body,
                civilDay = civilDay,
                hhmm = time,
                categoryId = PrayerNotificationContent.CategoryId.ADHAN,
                extras = adhanUserInfo(prayerKey, mosqueSlug, iso),
                generation = generation,
            )
        }
        val minutes = settings.preAdhanReminderMinutes
        if (minutes == null || minutes <= 0) return
        scheduleReminderIfNeeded(
            settings = settings,
            id = reminderId,
            mosqueSlug = mosqueSlug,
            iso = iso,
            prayerKey = prayerKey,
            kind = ReminderKind.BEFORE_ADHAN,
            minutesBefore = minutes,
            isFriday = isFriday,
            civilDay = civilDay,
            hhmm = time,
            language = language,
            generation = generation,
        )
    }

    private fun scheduleIqamahIfEnabled(
        settings: NotificationSettings,
        mosqueSlug: String,
        iso: String,
        id: String,
        reminderId: String,
        prayerKey: String,
        time: String,
        isFriday: Boolean,
        civilDay: Instant,
        language: AppLanguage,
        generation: Int,
    ) {
        if (!isIqamahForPrayerEnabled(prayerKey, settings)) return
        if (settings.iqamahEnabled) {
            val (title, body) = PrayerNotificationContent.iqamahCopy(prayerKey, isFriday, language)
            scheduleIfNeeded(
                id = id,
                title = title,
                body = body,
                civilDay = civilDay,
                hhmm = time,
                categoryId = PrayerNotificationContent.CategoryId.IQAMAH,
                extras = iqamahUserInfo(prayerKey, mosqueSlug, iso),
                generation = generation,
            )
        }
        val minutes = settings.preIqamahReminderMinutes
        if (minutes == null || minutes <= 0) return
        scheduleReminderIfNeeded(
            settings = settings,
            id = reminderId,
            mosqueSlug = mosqueSlug,
            iso = iso,
            prayerKey = prayerKey,
            kind = ReminderKind.BEFORE_IQAMAH,
            minutesBefore = minutes,
            isFriday = isFriday,
            civilDay = civilDay,
            hhmm = time,
            language = language,
            generation = generation,
        )
    }

    private enum class ReminderKind {
        BEFORE_ADHAN,
        BEFORE_IQAMAH,
    }

    private fun scheduleReminderIfNeeded(
        settings: NotificationSettings,
        id: String,
        mosqueSlug: String,
        iso: String,
        prayerKey: String,
        kind: ReminderKind,
        minutesBefore: Int,
        isFriday: Boolean,
        civilDay: Instant,
        hhmm: String,
        language: AppLanguage,
        generation: Int,
    ) {
        val targetDate = triggerDate(civilDay, hhmm) ?: return
        val fire = targetDate.minus(minutesBefore.toLong(), ChronoUnit.MINUTES)
        if (!fire.isAfter(Instant.now())) return

        val (title, body) = when (kind) {
            ReminderKind.BEFORE_ADHAN ->
                PrayerNotificationContent.beforeAdhanReminderCopy(prayerKey, isFriday, minutesBefore, language)
            ReminderKind.BEFORE_IQAMAH ->
                PrayerNotificationContent.beforeIqamahReminderCopy(prayerKey, isFriday, minutesBefore, language)
        }
        val payloadKind = when (kind) {
            ReminderKind.BEFORE_ADHAN -> PrayerNotificationContent.PayloadKind.REMINDER_BEFORE_ADHAN
            ReminderKind.BEFORE_IQAMAH -> PrayerNotificationContent.PayloadKind.REMINDER_BEFORE_IQAMAH
        }

        scheduleAt(
            id = id,
            title = title,
            body = body,
            fireAt = fire,
            categoryId = PrayerNotificationContent.CategoryId.REMINDER,
            extras = reminderUserInfo(payloadKind, prayerKey, mosqueSlug, iso, minutesBefore),
            generation = generation,
        )
    }

    private fun scheduleIfNeeded(
        id: String,
        title: String,
        body: String,
        civilDay: Instant,
        hhmm: String,
        categoryId: String,
        extras: Map<String, String>,
        generation: Int,
    ) {
        val fire = triggerDate(civilDay, hhmm) ?: return
        if (!fire.isAfter(Instant.now())) return
        scheduleAt(id, title, body, fire, categoryId, extras, generation)
    }

    private val scheduledThisRun = mutableListOf<String>()

    private fun scheduleAt(
        id: String,
        title: String,
        body: String,
        fireAt: Instant,
        categoryId: String,
        extras: Map<String, String>,
        generation: Int,
    ) {
        if (addBudget <= 0 || !isCurrentGeneration(generation)) return
        if (!PrayerNotificationPermissions.canScheduleExactAlarms(appContext)) return

        val intent = PrayerNotificationReceiver.buildIntent(
            context = appContext,
            id = id,
            title = title,
            body = body,
            categoryId = categoryId,
            extras = extras,
        )
        val pendingIntent = PrayerNotificationReceiver.pendingIntent(appContext, id, intent)
        PrayerNotificationReceiver.scheduleExact(appContext, fireAt.toEpochMilli(), pendingIntent)
        scheduledThisRun.add(id)
        addBudget -= 1

        if (!isCurrentGeneration(generation)) {
            PrayerNotificationReceiver.cancel(appContext, id)
            scheduledThisRun.remove(id)
        }
    }

    private fun cancelAllForCurrentRun() {
        alarmStore.scheduledIds().forEach { id ->
            PrayerNotificationReceiver.cancel(appContext, id)
        }
        scheduledThisRun.forEach { id ->
            PrayerNotificationReceiver.cancel(appContext, id)
        }
        scheduledThisRun.clear()
        alarmStore.clear()
    }

    private fun finalizeRun() {
        if (scheduledThisRun.isNotEmpty()) {
            alarmStore.replaceScheduledIds(scheduledThisRun)
        }
        scheduledThisRun.clear()
    }

    private fun isCurrentGeneration(generation: Int): Boolean =
        runGeneration.get() == generation

    private fun triggerDate(civilDay: Instant, hhmm: String): Instant? {
        val parts = hhmm.split(":").mapNotNull { it.toIntOrNull() }
        if (parts.size != 2 || parts[0] !in 0..23 || parts[1] !in 0..59) return null
        val day = PrayerTimesEngine.getDateInSheffield(civilDay)
        return LocalDate.of(day.year, day.month, day.day)
            .atTime(parts[0], parts[1])
            .atZone(PrayerTimesEngine.sheffieldTimeZone)
            .toInstant()
    }

    private fun adhanUserInfo(prayerKey: String, mosqueSlug: String, iso: String): Map<String, String> =
        mapOf(
            PrayerNotificationContent.UserInfoKey.KIND to PrayerNotificationContent.PayloadKind.ADHAN.wireValue,
            PrayerNotificationContent.UserInfoKey.PRAYER to prayerKey,
            PrayerNotificationContent.UserInfoKey.MOSQUE_SLUG to mosqueSlug,
            PrayerNotificationContent.UserInfoKey.ISO_DATE to iso,
        )

    private fun iqamahUserInfo(prayerKey: String, mosqueSlug: String, iso: String): Map<String, String> =
        mapOf(
            PrayerNotificationContent.UserInfoKey.KIND to PrayerNotificationContent.PayloadKind.IQAMAH.wireValue,
            PrayerNotificationContent.UserInfoKey.PRAYER to prayerKey,
            PrayerNotificationContent.UserInfoKey.MOSQUE_SLUG to mosqueSlug,
            PrayerNotificationContent.UserInfoKey.ISO_DATE to iso,
        )

    private fun reminderUserInfo(
        kind: PrayerNotificationContent.PayloadKind,
        prayerKey: String,
        mosqueSlug: String,
        iso: String,
        minutes: Int,
    ): Map<String, String> =
        mapOf(
            PrayerNotificationContent.UserInfoKey.KIND to kind.wireValue,
            PrayerNotificationContent.UserInfoKey.PRAYER to prayerKey,
            PrayerNotificationContent.UserInfoKey.MOSQUE_SLUG to mosqueSlug,
            PrayerNotificationContent.UserInfoKey.ISO_DATE to iso,
            PrayerNotificationContent.UserInfoKey.REMINDER_MINUTES to minutes.toString(),
        )

    companion object {
        /** iOS keeps at most 64 pending local notifications. */
        private const val MAX_PENDING_NOTIFICATIONS = 64
    }
}
