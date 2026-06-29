package com.mikhailspeaks.masjidly.features.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.DailyIqamahTimes
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.PrayerTime
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingFlowViewModel
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingHighlight
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingStep
import com.mikhailspeaks.masjidly.features.onboarding.TimetableOnboardingOverlay
import com.mikhailspeaks.masjidly.features.settings.MasjidlySupportMail
import com.mikhailspeaks.masjidly.ui.home.HomeDateFormatting
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import java.text.NumberFormat
import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoField
import java.util.Locale
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private const val TIME_COL_WIDTH = 105
private const val DATE_CELL_WIDTH = 48
private const val DATE_CELL_HEIGHT = 70
private const val ROW_FONT_SIZE = 18

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimetableScreen(
    homeViewModel: HomeViewModel,
    settingsStore: SettingsStore,
    onboardingViewModel: OnboardingFlowViewModel,
    onBack: () -> Unit,
) {
    val homeState by homeViewModel.uiState.collectAsState()
    val onboardingState by onboardingViewModel.uiState.collectAsState()
    val settingsRevision by settingsStore.revision.collectAsState()
    val language = settingsStore.appLanguage
    val locale = settingsStore.resolvedLocale()
    val uses24Hour = settingsStore.uses24HourTime
    val asrPreference = settingsStore.asrIqamahPreference
    val mosque = homeState.selectedMosque
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    @Suppress("UNUSED_VARIABLE")
    val _tick = settingsRevision

    val dynamicTheme = TimeTheme.homeHeroTheme(homeState.displayedPrayerTimes, homeState.selectedPrayerIndex)
    val theme = settingsStore.resolvedTheme(dynamicTheme)

    val initialMonthData = homeState.monthData
    val displayedDate = homeState.displayedDate
    val (seedMonth, seedYear) = remember(initialMonthData, displayedDate) {
        resolveInitialMonthYear(initialMonthData, displayedDate)
    }

    var currentMonthData by remember(initialMonthData) { mutableStateOf(initialMonthData) }
    var currentMonth by remember(seedMonth, seedYear) { mutableIntStateOf(seedMonth) }
    var currentYear by remember(seedMonth, seedYear) { mutableIntStateOf(seedYear) }
    var selectedDate by remember(seedMonth, seedYear, initialMonthData) {
        mutableIntStateOf(
            initialMonthData?.prayerTimes?.let {
                resolveInitialSelectedDate(it, displayedDate, seedMonth, seedYear)
            } ?: PrayerTimesEngine.getDateInSheffield(Instant.now()).day,
        )
    }
    var isLoadingMonth by remember { mutableStateOf(false) }
    var noDataForMonth by remember { mutableStateOf(initialMonthData?.prayerTimes.isNullOrEmpty() == true) }
    var isRefreshing by remember { mutableStateOf(false) }

    LaunchedEffect(initialMonthData, displayedDate) {
        if (initialMonthData != null) {
            currentMonthData = initialMonthData
            val (m, y) = resolveInitialMonthYear(initialMonthData, displayedDate)
            currentMonth = m
            currentYear = y
            noDataForMonth = initialMonthData.prayerTimes.isEmpty()
            selectedDate = resolveInitialSelectedDate(
                initialMonthData.prayerTimes,
                displayedDate,
                m,
                y,
            )
        }
    }

    fun refreshMonth() {
        val slug = mosque?.slug ?: return
        scope.launch {
            isRefreshing = true
            val data = homeViewModel.fetchMonthData(slug, currentMonth, currentYear)
            currentMonthData = data
            noDataForMonth = data == null || data.prayerTimes.isEmpty()
            isRefreshing = false
        }
    }

    suspend fun changeMonth(delta: Int) {
        if (isLoadingMonth) return
        isLoadingMonth = true
        var m = currentMonth + delta
        var y = currentYear
        if (m < 1) {
            m = 12
            y -= 1
        } else if (m > 12) {
            m = 1
            y += 1
        }
        val slug = mosque?.slug
        val data = if (slug != null) homeViewModel.fetchMonthData(slug, m, y) else null
        currentMonth = m
        currentYear = y
        currentMonthData = data
        noDataForMonth = data == null || data.prayerTimes.isEmpty()
        if (!noDataForMonth && data != null) {
            selectedDate = resolveInitialSelectedDate(data.prayerTimes, Instant.now(), m, y)
        } else {
            selectedDate = 1
        }
        isLoadingMonth = false
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(theme.sky.baseColors)),
    ) {
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = { refreshMonth() },
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding(),
            ) {
                TimetableHeader(
                    theme = theme,
                    selectedDate = selectedDate,
                    currentMonth = currentMonth,
                    currentYear = currentYear,
                    mosqueName = mosque?.name ?: "",
                    locale = locale,
                    language = language,
                    highlightCloseButton = onboardingState.currentStep == OnboardingStep.CloseTimetable,
                    onBack = onBack,
                )

                MonthSwitcher(
                    theme = theme,
                    title = monthTitle(currentMonth, currentYear, locale),
                    enabled = !isLoadingMonth,
                    language = language,
                    onPrevious = { scope.launch { changeMonth(-1) } },
                    onNext = { scope.launch { changeMonth(1) } },
                )

                when {
                    isLoadingMonth -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center,
                        ) {
                            CircularProgressIndicator(color = theme.textColor)
                        }
                    }
                    noDataForMonth -> {
                        MissingMonthMessage(
                            theme = theme,
                            language = language,
                        ) {
                            MasjidlySupportMail.openMissingPrayerTimesEmail(
                                context = context,
                                mosqueName = mosque?.name,
                                monthDisplay = monthTitle(currentMonth, currentYear, locale),
                                language = language,
                            )
                        }
                        Spacer(modifier = Modifier.weight(1f))
                    }
                    currentMonthData != null -> {
                        DateStrip(
                            theme = theme,
                            days = currentMonthData!!.prayerTimes,
                            selectedDate = selectedDate,
                            locale = locale,
                            language = language,
                            currentMonth = currentMonth,
                            currentYear = currentYear,
                            onSelect = { selectedDate = it },
                        )
                        val dayRow = currentMonthData!!.prayerTimes.firstOrNull { it.date == selectedDate }
                        if (dayRow != null && mosque != null) {
                            PrayerRows(
                                time = dayRow,
                                monthData = currentMonthData!!,
                                mosqueSlug = mosque.slug,
                                theme = theme,
                                locale = locale,
                                language = language,
                                uses24Hour = uses24Hour,
                                asrPreference = asrPreference,
                                currentMonth = currentMonth,
                                currentYear = currentYear,
                            )
                        }
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }

        onboardingState.currentStep?.let { step ->
            TimetableOnboardingOverlay(
                step = step,
                theme = theme,
                language = language,
                onboarding = onboardingViewModel,
            )
        }
    }
}

@Composable
private fun TimetableHeader(
    theme: ResolvedTheme,
    selectedDate: Int,
    currentMonth: Int,
    currentYear: Int,
    mosqueName: String,
    locale: Locale,
    language: AppLanguage,
    highlightCloseButton: Boolean,
    onBack: () -> Unit,
) {
    val gregorianLabel = formattedSelectedDate(selectedDate, currentMonth, currentYear, locale)
    val hijriLabel = formattedHijriDate(selectedDate, currentMonth, currentYear, locale)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 24.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(end = 4.dp),
        ) {
            Text(
                text = gregorianLabel,
                style = rememberAppTextStyle(18f, FontWeight.Light),
                color = theme.textColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (hijriLabel.isNotEmpty()) {
                Text(
                    text = hijriLabel,
                    style = rememberAppTextStyle(14f, FontWeight.Light),
                    color = theme.textColor.copy(alpha = 0.7f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = mosqueName,
                style = rememberAppTextStyle(14f),
                color = theme.textColor.copy(alpha = 0.7f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        OnboardingHighlight(
            highlighted = highlightCloseButton,
            theme = theme,
            shape = CircleShape,
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(theme.textColor.copy(alpha = 0.1f))
                    .hapticClickable(onClick = onBack)
                    .semantics {
                        contentDescription = LocaleStrings.t("timetable.close_a11y", language)
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = null,
                    tint = theme.textColor,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

@Composable
private fun MonthSwitcher(
    theme: ResolvedTheme,
    title: String,
    enabled: Boolean,
    language: AppLanguage,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 24.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        MonthSwitcherButton(
            theme = theme,
            enabled = enabled,
            contentDescription = LocaleStrings.t("timetable.previous_month_a11y", language),
            onClick = onPrevious,
        ) {
            Icon(
                Icons.Default.ChevronLeft,
                contentDescription = null,
                tint = theme.textColor,
                modifier = Modifier.size(16.dp),
            )
        }
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Center,
            style = rememberAppTextStyle(18f, FontWeight.Medium),
            color = theme.textColor,
        )
        MonthSwitcherButton(
            theme = theme,
            enabled = enabled,
            contentDescription = LocaleStrings.t("timetable.next_month_a11y", language),
            onClick = onNext,
        ) {
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = theme.textColor,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

@Composable
private fun MonthSwitcherButton(
    theme: ResolvedTheme,
    enabled: Boolean,
    contentDescription: String,
    onClick: () -> Unit,
    icon: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .hapticClickable(enabled = enabled, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        icon()
    }
}

@Composable
private fun DateStrip(
    theme: ResolvedTheme,
    days: List<PrayerTime>,
    selectedDate: Int,
    locale: Locale,
    language: AppLanguage,
    currentMonth: Int,
    currentYear: Int,
    onSelect: (Int) -> Unit,
) {
    val today = PrayerTimesEngine.getDateInSheffield(Instant.now())
    val isCurrentMonth = today.month == currentMonth && today.year == currentYear
    val listState = rememberLazyListState()
    val dayFormatter = remember(locale) { NumberFormat.getIntegerInstance(locale) }
    val density = LocalDensity.current
    val fallbackItemSizePx = with(density) { DATE_CELL_WIDTH.dp.roundToPx() }

    LaunchedEffect(selectedDate, days) {
        val index = days.indexOfFirst { it.date == selectedDate }
        if (index >= 0) {
            listState.animateScrollToItemCentered(index, fallbackItemSizePx)
        }
    }

    LazyRow(
        state = listState,
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 32.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 24.dp),
    ) {
        items(days, key = { it.date }) { day ->
            val isSelected = day.date == selectedDate
            val isToday = isCurrentMonth && day.date == today.day
            val weekday = shortWeekday(day.date, currentMonth, currentYear, locale)
            val dayLabel = LocaleStrings.format("timetable.day_a11y_format", language, day.date.toString())

            Column(
                modifier = Modifier
                    .width(DATE_CELL_WIDTH.dp)
                    .height(DATE_CELL_HEIGHT.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        if (isSelected) theme.textColor.copy(alpha = 0.12f) else Color.Transparent,
                    )
                    .hapticClickable(hapticOnPress = false) { onSelect(day.date) }
                    .semantics { contentDescription = dayLabel },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = weekday.uppercase(locale),
                    style = rememberAppTextStyle(10f, FontWeight.SemiBold),
                    color = if (isSelected) theme.textColor else theme.textColor.copy(alpha = 0.4f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = dayFormatter.format(day.date),
                    style = rememberAppTextStyle(
                        20f,
                        if (isSelected) FontWeight.Medium else FontWeight.Normal,
                    ),
                    color = if (isSelected) theme.textColor else theme.textColor.copy(alpha = 0.5f),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Box(
                    modifier = Modifier
                        .size(4.dp)
                        .clip(CircleShape)
                        .background(if (isToday) theme.textColor else Color.Transparent),
                )
            }
        }
    }
}

private data class TimetableRow(
    val id: String,
    val name: String,
    val adhanSortKey: String,
    val adhanDisplay: String,
    val iqamahDisplay: String,
)

@Composable
private fun PrayerRows(
    time: PrayerTime,
    monthData: MonthPrayerData,
    mosqueSlug: String,
    theme: ResolvedTheme,
    locale: Locale,
    language: AppLanguage,
    uses24Hour: Boolean,
    asrPreference: AsrIqamahPreference,
    currentMonth: Int,
    currentYear: Int,
) {
    val dailyIqamah = runCatching {
        PrayerTimesEngine.getIqamahTimesForDate(time.date, monthData.iqamahTimes)
    }.getOrNull()
    val prayerDate = PrayerTimesEngine.sheffieldNoonUTC(currentYear, currentMonth, time.date)
    val isFriday = isFriday(currentYear, currentMonth, time.date)
    val isToday = run {
        val now = PrayerTimesEngine.getDateInSheffield(Instant.now())
        now.year == currentYear && now.month == currentMonth && now.day == time.date
    }

    val baseRows = buildList {
        fun fmt(raw: String) = PrayerTimesEngine.formatPrayerTimeForDisplay(raw, uses24Hour, locale)
        add(
            TimetableRow(
                "fajr",
                LocaleStrings.t("timetable.header.fajr", language),
                time.fajr,
                fmt(time.fajr),
                resolveIqamah("fajr", time.fajr, dailyIqamah, time, mosqueSlug, prayerDate, asrPreference, uses24Hour, locale),
            ),
        )
        add(
            TimetableRow(
                "sunrise",
                LocaleStrings.t("timetable.header.shu", language),
                time.shurooq,
                fmt(time.shurooq),
                "-",
            ),
        )
        if (isFriday) {
            addAll(fridayJummahRows(time, dailyIqamah, monthData, uses24Hour, locale, language))
        } else {
            add(
                TimetableRow(
                    "dhuhr",
                    LocaleStrings.t("timetable.header.dhu", language),
                    time.dhuhr,
                    fmt(time.dhuhr),
                    resolveIqamah("dhuhr", time.dhuhr, dailyIqamah, time, mosqueSlug, prayerDate, asrPreference, uses24Hour, locale),
                ),
            )
        }
        add(
            TimetableRow(
                "asr",
                LocaleStrings.t("timetable.header.asr", language),
                time.asr,
                fmt(time.asr),
                resolveIqamah("asr", time.asr, dailyIqamah, time, mosqueSlug, prayerDate, asrPreference, uses24Hour, locale),
            ),
        )
        add(
            TimetableRow(
                "maghrib",
                LocaleStrings.t("timetable.header.mag", language),
                time.maghrib,
                fmt(time.maghrib),
                resolveIqamah("maghrib", time.maghrib, dailyIqamah, time, mosqueSlug, prayerDate, asrPreference, uses24Hour, locale),
            ),
        )
        add(
            TimetableRow(
                "isha",
                LocaleStrings.t("timetable.header.ish", language),
                time.isha,
                fmt(time.isha),
                resolveIqamah("isha", time.isha, dailyIqamah, time, mosqueSlug, prayerDate, asrPreference, uses24Hour, locale),
            ),
        )
    }

    val nowHHMM = formatSystemTime()
    val nextId = if (isToday) {
        baseRows.firstOrNull { it.adhanSortKey > nowHHMM }?.id
    } else {
        null
    }

    val nightRows = buildList {
        val nextFajr = monthData.prayerTimes.sortedBy { it.date }
            .firstOrNull { it.date > time.date }?.fajr
        val night = PrayerTimesEngine.computeMidnightAndLastThird(time.maghrib, nextFajr)
        fun fmt(raw: String) = PrayerTimesEngine.formatPrayerTimeForDisplay(raw, uses24Hour, locale)
        night.midnight?.let {
            add(
                TimetableRow(
                    "midnight",
                    LocaleStrings.t("timetable.header.midnight", language),
                    it,
                    fmt(it),
                    "-",
                ),
            )
        }
        night.lastThird?.let {
            add(
                TimetableRow(
                    "lastThird",
                    LocaleStrings.t("timetable.header.lastThird", language),
                    it,
                    fmt(it),
                    "-",
                ),
            )
        }
    }
    val rows = baseRows + nightRows

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        val rowPadding = if (maxWidth < 340.dp) 14.dp else 24.dp
        val timeColumnWidth = ((maxWidth - (rowPadding * 2) - 24.dp - 76.dp) / 2f)
            .coerceIn(78.dp, TIME_COL_WIDTH.dp)

        Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = rowPadding)
                    .padding(bottom = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    LocaleStrings.t("timetable.header.prayer", language),
                    modifier = Modifier.weight(1f),
                    color = theme.textColor.copy(alpha = 0.5f),
                    style = rememberAppTextStyle(13f, FontWeight.Medium),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    LocaleStrings.t("timetable.header.adhan", language),
                    modifier = Modifier.width(timeColumnWidth),
                    color = theme.textColor.copy(alpha = 0.5f),
                    style = rememberAppTextStyle(13f, FontWeight.Medium),
                    textAlign = TextAlign.End,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    LocaleStrings.t("timetable.header.iqamah", language),
                    modifier = Modifier.width(timeColumnWidth),
                    color = theme.textColor.copy(alpha = 0.5f),
                    style = rememberAppTextStyle(13f, FontWeight.Medium),
                    textAlign = TextAlign.End,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                rows.forEach { r ->
                    val isNext = r.id == nextId
                    val isPast = isToday && isTimePast(
                        r.adhanSortKey,
                        nowHHMM,
                        r.id == "midnight" || r.id == "lastThird",
                    )
                    val opacity = if (isPast) 0.35f else 1f
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(
                                if (isNext) theme.textColor.copy(alpha = 0.08f) else Color.Transparent,
                            )
                            .padding(vertical = 16.dp, horizontal = rowPadding),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.Top,
                    ) {
                        Text(
                            r.name,
                            modifier = Modifier.weight(1f),
                            color = theme.textColor.copy(alpha = opacity),
                            style = rememberAppTextStyle(
                                ROW_FONT_SIZE.toFloat(),
                                if (isNext) FontWeight.SemiBold else FontWeight.Normal,
                            ),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            softWrap = false,
                        )
                        Text(
                            r.adhanDisplay,
                            modifier = Modifier.width(timeColumnWidth),
                            color = theme.textColor.copy(alpha = opacity * 0.75f),
                            style = rememberAppTextStyle(
                                ROW_FONT_SIZE.toFloat(),
                                if (isNext) FontWeight.SemiBold else FontWeight.Normal,
                                tabularDigits = true,
                            ),
                            textAlign = TextAlign.End,
                            maxLines = 1,
                            overflow = TextOverflow.Clip,
                        )
                        Text(
                            r.iqamahDisplay,
                            modifier = Modifier.width(timeColumnWidth),
                            color = theme.textColor.copy(alpha = opacity),
                            style = rememberAppTextStyle(
                                ROW_FONT_SIZE.toFloat(),
                                if (isNext) FontWeight.Bold else FontWeight.Medium,
                                tabularDigits = true,
                            ),
                            textAlign = TextAlign.End,
                            maxLines = 1,
                            overflow = TextOverflow.Clip,
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

private fun fridayJummahRows(
    time: PrayerTime,
    dailyIqamah: DailyIqamahTimes?,
    monthData: MonthPrayerData,
    uses24Hour: Boolean,
    locale: Locale,
    language: AppLanguage,
): List<TimetableRow> {
    val raw = dailyIqamah?.jummah?.trim().orEmpty().ifEmpty { monthData.jummahIqamah.trim() }
    val slots = PrayerTimesEngine.splitJummahIqamahTimes(raw)
    val dhuhr = PrayerTimesEngine.formatPrayerTimeForDisplay(time.dhuhr, uses24Hour, locale)
    val jummahLabel = LocaleStrings.t("prayer.jummah", language)
    if (slots.isEmpty()) {
        return listOf(TimetableRow("jummah_0", jummahLabel, time.dhuhr, dhuhr, "-"))
    }
    return slots.mapIndexed { idx, slot ->
        val parts = slot.split(Regex("\\s+")).filter { it.isNotEmpty() }
        val iqCell = if (parts.size >= 2) {
            "${PrayerTimesEngine.formatPrayerTimeForDisplay(parts[0], uses24Hour, locale)} · ${PrayerTimesEngine.formatPrayerTimeForDisplay(parts[1], uses24Hour, locale)}"
        } else {
            PrayerTimesEngine.formatPrayerTimeForDisplay(parts[0], uses24Hour, locale)
        }
        val label = if (slots.size > 1) "$jummahLabel ${idx + 1}" else jummahLabel
        TimetableRow("jummah_$idx", label, time.dhuhr, dhuhr, iqCell)
    }
}

private fun resolveIqamah(
    id: String,
    adhan: String,
    iq: DailyIqamahTimes?,
    time: PrayerTime,
    mosqueSlug: String,
    date: Instant,
    asrPreference: AsrIqamahPreference,
    uses24Hour: Boolean,
    locale: Locale,
): String {
    if (iq == null) return "-"
    val resolved = if (id == "asr") {
        PrayerTimesEngine.selectAsrIqamahTime(iq.asr, adhan, asrPreference)
    } else {
        PrayerTimesEngine.getDisplayIqamah(id, adhan, iq, mosqueSlug, date, time.maghrib)
    }
    val trimmed = resolved.trim()
    if (trimmed.isEmpty() || trimmed.equals("no iqamah", ignoreCase = true)) return "-"
    return PrayerTimesEngine.formatPrayerTimeForDisplay(trimmed, uses24Hour, locale)
}

@Composable
private fun MissingMonthMessage(
    theme: ResolvedTheme,
    language: AppLanguage,
    onEmail: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = LocaleStrings.t("timetable.missing_month", language),
            color = theme.textColor.copy(alpha = 0.7f),
            textAlign = TextAlign.Center,
            style = rememberAppTextStyle(16f),
            lineHeight = 24.sp,
        )
        Spacer(modifier = Modifier.height(16.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(theme.textColor.copy(alpha = 0.14f))
                .border(1.dp, theme.textColor.copy(alpha = 0.22f), RoundedCornerShape(14.dp))
                .padding(vertical = 12.dp)
                .hapticClickable(onClick = onEmail),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = LocaleStrings.t("home.missing_times.email_button", language),
                color = theme.textColor,
                style = rememberAppTextStyle(15f, FontWeight.SemiBold),
            )
        }
    }
}

private suspend fun LazyListState.animateScrollToItemCentered(index: Int, fallbackItemSizePx: Int) {
    snapshotFlow { layoutInfo }
        .filter { it.totalItemsCount > index }
        .first()

    val layoutInfo = layoutInfo
    val viewportSize = layoutInfo.viewportEndOffset - layoutInfo.viewportStartOffset
    val itemSize = layoutInfo.visibleItemsInfo.find { it.index == index }?.size ?: fallbackItemSizePx
    val centerOffset = ((viewportSize - itemSize) / 2).coerceAtLeast(0)
    animateScrollToItem(index, scrollOffset = -centerOffset)
}

private fun resolveInitialMonthYear(monthData: MonthPrayerData?, displayedDate: Instant): Pair<Int, Int> {
    parseMonthYearLabel(monthData?.month)?.let { return it }
    val parts = PrayerTimesEngine.getDateInSheffield(displayedDate)
    return parts.month to parts.year
}

private fun parseMonthYearLabel(label: String?): Pair<Int, Int>? {
    if (label.isNullOrBlank()) return null
    val trimmed = label.trim()
    for (pattern in listOf("MMMM yyyy", "MMM yyyy")) {
        try {
            val formatter = DateTimeFormatter.ofPattern(pattern, Locale.ENGLISH)
            val parsed = formatter.parse(trimmed)
            return parsed.get(ChronoField.MONTH_OF_YEAR) to parsed.get(ChronoField.YEAR)
        } catch (_: Exception) {
            // try next pattern
        }
    }
    return null
}

private fun resolveInitialSelectedDate(
    prayerTimes: List<PrayerTime>,
    referenceDate: Instant,
    month: Int,
    year: Int,
): Int {
    if (prayerTimes.isEmpty()) return 1
    val reference = PrayerTimesEngine.getDateInSheffield(referenceDate)
    if (reference.month == month && reference.year == year &&
        prayerTimes.any { it.date == reference.day }
    ) {
        return reference.day
    }
    val today = PrayerTimesEngine.getDateInSheffield(Instant.now())
    if (today.month == month && today.year == year &&
        prayerTimes.any { it.date == today.day }
    ) {
        return today.day
    }
    return prayerTimes.first().date
}

private fun monthTitle(month: Int, year: Int, locale: Locale): String {
    val zdt = ZonedDateTime.of(year, month, 15, 12, 0, 0, 0, PrayerTimesEngine.sheffieldTimeZone)
    return DateTimeFormatter.ofPattern("MMM yyyy", locale).format(zdt)
}

private fun formattedSelectedDate(day: Int, month: Int, year: Int, locale: Locale): String {
    val zdt = ZonedDateTime.of(year, month, day, 12, 0, 0, 0, PrayerTimesEngine.sheffieldTimeZone)
    return DateTimeFormatter.ofPattern("EEEE · d MMMM", locale).format(zdt)
}

private fun formattedHijriDate(day: Int, month: Int, year: Int, locale: Locale): String {
    val zdt = ZonedDateTime.of(year, month, day, 12, 0, 0, 0, PrayerTimesEngine.sheffieldTimeZone)
    return HomeDateFormatting.hijriDateString(zdt.toInstant(), locale)
}

private fun shortWeekday(day: Int, month: Int, year: Int, locale: Locale): String {
    val zdt = ZonedDateTime.of(year, month, day, 12, 0, 0, 0, PrayerTimesEngine.sheffieldTimeZone)
    return DateTimeFormatter.ofPattern("EEE", locale).format(zdt)
}

private fun isFriday(year: Int, month: Int, day: Int): Boolean {
    val zdt = ZonedDateTime.of(year, month, day, 12, 0, 0, 0, PrayerTimesEngine.sheffieldTimeZone)
    return zdt.dayOfWeek.value == 5
}

private fun formatSystemTime(): String =
    DateTimeFormatter.ofPattern("HH:mm")
        .withZone(PrayerTimesEngine.sheffieldTimeZone)
        .format(Instant.now())

private fun isTimePast(time: String, now: String, isNextDayRow: Boolean): Boolean {
    val tMin = PrayerTimesEngine.timeToMinutes(time) ?: return false
    val nMin = PrayerTimesEngine.timeToMinutes(now) ?: return false
    if (isNextDayRow && nMin >= 720) return false
    return tMin <= nMin
}
