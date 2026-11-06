package com.mikhailspeaks.masjidly.features.compare

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerLocalization
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.features.settings.SettingsPickerBottomSheet
import com.mikhailspeaks.masjidly.features.settings.SettingsPickerOption
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.launch

/** Mirrors iOS `CompareFindView`. */
@Composable
internal fun CompareFindContent(
    revision: Int,
    model: CompareViewModel,
    settingsStore: SettingsStore,
    theme: ResolvedTheme,
    onOpen: (Mosque) -> Unit,
) {
    val language = settingsStore.appLanguage
    val locale = settingsStore.resolvedLocale()
    val uses24 = settingsStore.uses24HourTime
    val scope = rememberCoroutineScope()
    readRevision(revision)
    val query = model.query
    val result = model.findResult
    val progress = model.loadProgress
    var showCityPicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }
    // The query whose exact-time matches the user chose to reveal. Any query change hides them again.
    var revealedAtTimeQuery by remember { mutableStateOf<CompareFindQuery?>(null) }

    fun format(minutes: Int): String =
        PrayerTimesEngine.formatPrayerTimeForDisplay("%02d:%02d".format(minutes / 60, minutes % 60), uses24, locale)

    val timeText = format(query.minutes)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 12.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            CityField(model.cityLabel, theme, language) { showCityPicker = true }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                CompareTextTabs(
                    options = listOf(
                        CompareTimeType.ADHAN to LocaleStrings.t("compare.find.adhan", language),
                        CompareTimeType.JAMAAT to LocaleStrings.t("compare.find.jamaat", language),
                    ),
                    selection = query.type,
                    theme = theme,
                    sizeSp = 16f,
                    equalWidth = false,
                ) { model.query = model.query.copy(type = it) }
                CompareTextTabs(
                    options = listOf(
                        CompareDirection.BEFORE to LocaleStrings.t("compare.find.before", language),
                        CompareDirection.AFTER to LocaleStrings.t("compare.find.after", language),
                    ),
                    selection = query.direction,
                    theme = theme,
                    sizeSp = 16f,
                    equalWidth = false,
                ) { model.query = model.query.copy(direction = it) }
            }

            val prayerOptions: List<Pair<ComparePrayer?, String>> =
                listOf<Pair<ComparePrayer?, String>>(null to LocaleStrings.t("compare.find.any", language)) +
                    ComparePrayer.entries.map {
                        it to PrayerLocalization.displayName(it.canonicalName(model.isFriday), language)
                    }
            CompareTextTabs(
                options = prayerOptions,
                selection = query.prayer,
                theme = theme,
                sizeSp = 14f,
                equalWidth = true,
                modifier = Modifier.fillMaxWidth(),
            ) { model.query = model.query.copy(prayer = it) }

            TimeStepper(timeText, theme, language, onNudge = model::nudgeMinutes, onTapTime = { showTimePicker = true })

            query.prayer?.let { prayer ->
                model.yourJamaatMinutes(prayer)?.let { yours ->
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        MeridiemText(
                            text = LocaleStrings.format("compare.find.laterThanYours", language, format(yours)),
                            sizeSp = 14f,
                            weight = FontWeight.Medium,
                            color = theme.textColor.copy(alpha = 0.75f),
                            meridiemScale = 0.75f,
                            modifier = Modifier
                                .hapticClickable { model.searchLaterThanYours() }
                                .padding(vertical = 6.dp),
                        )
                    }
                }
            }
        }

        val headerKey = when (query.type to query.direction) {
            CompareTimeType.JAMAAT to CompareDirection.AFTER -> "compare.find.header.jamaatAfter"
            CompareTimeType.JAMAAT to CompareDirection.BEFORE -> "compare.find.header.jamaatBefore"
            CompareTimeType.ADHAN to CompareDirection.AFTER -> "compare.find.header.adhanAfter"
            else -> "compare.find.header.adhanBefore"
        }
        MeridiemText(
            text = LocaleStrings.format(headerKey, language, timeText, model.cityLabel),
            sizeSp = 16f,
            weight = FontWeight.SemiBold,
            color = theme.textColor,
            meridiemScale = 0.75f,
            maxLines = 3,
            modifier = Modifier.padding(top = 4.dp),
        )

        if (result.hits.isEmpty() && !model.isLoadingFind) {
            EmptyResults(
                timeText = timeText,
                theme = theme,
                language = language,
                atTimeHits = result.atTimeHits,
                atTimeRevealed = revealedAtTimeQuery == query,
                onRevealAtTime = { revealedAtTimeQuery = query },
            ) { hit -> ResultRow(hit, model, settingsStore, theme, onOpen) }
        } else {
            result.hits.forEach { hit -> ResultRow(hit, model, settingsStore, theme, onOpen) }
        }

        Column(modifier = Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (result.noFixedTimeCount > 0) {
                FooterText(LocaleStrings.format("compare.find.noFixedTime", language, result.noFixedTimeCount), theme)
            }
            if (model.isLoadingFind) {
                FooterText(LocaleStrings.format("compare.find.loading", language, progress.first, progress.second), theme)
            }
            if (model.failedCount > 0 && !model.isLoadingFind) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FooterText(LocaleStrings.format("compare.find.failed", language, model.failedCount), theme)
                    Text(
                        text = LocaleStrings.t("compare.retry", language),
                        style = rememberAppTextStyle(13f, FontWeight.SemiBold),
                        color = theme.textColor,
                        textDecoration = TextDecoration.Underline,
                        modifier = Modifier.hapticClickable { scope.launch { model.loadFind() } },
                    )
                }
            }
        }
    }

    SettingsPickerBottomSheet(
        visible = showCityPicker,
        title = LocaleStrings.t("compare.find.city", language),
        options = model.cityOptions.map { SettingsPickerOption(it.first, it.second) },
        selectedKey = model.cityKey,
        theme = theme,
        language = language,
        onDismiss = { showCityPicker = false },
        onSelect = { model.cityKey = it },
    )

    if (showTimePicker) {
        CompareTimeDialog(
            initialMinutes = query.minutes,
            uses24Hour = uses24,
            theme = theme,
            language = language,
            onDismiss = { showTimePicker = false },
            onConfirm = {
                model.query = model.query.copy(minutes = it)
                showTimePicker = false
            },
        )
    }
}

@Composable
private fun FooterText(text: String, theme: ResolvedTheme) {
    Text(text, style = rememberAppTextStyle(13f), color = theme.textColor.copy(alpha = 0.65f))
}

@Composable
private fun CityField(
    label: String,
    theme: ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(theme.textColor.copy(alpha = 0.1f))
            .border(1.dp, theme.textColor.copy(alpha = 0.25f), shape)
            .hapticClickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .semantics { contentDescription = LocaleStrings.t("compare.find.city", language) + ": " + label },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Text(
            text = label,
            style = rememberAppTextStyle(17f, FontWeight.SemiBold),
            color = theme.textColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Icon(
            Icons.Default.KeyboardArrowDown,
            contentDescription = null,
            tint = theme.textColor.copy(alpha = 0.6f),
            modifier = Modifier.padding(start = 6.dp).size(20.dp),
        )
    }
}

@Composable
private fun TimeStepper(
    timeText: String,
    theme: ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    onNudge: (Int) -> Unit,
    onTapTime: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        NudgeButton(Icons.Default.Remove, LocaleStrings.t("compare.find.nudgeEarlier", language), theme) { onNudge(-5) }
        Row(
            modifier = Modifier
                .heightIn(min = 56.dp)
                .clip(shape)
                .background(theme.textColor.copy(alpha = 0.1f))
                .border(1.dp, theme.textColor.copy(alpha = 0.25f), shape)
                .hapticClickable(onClick = onTapTime)
                .padding(horizontal = 16.dp)
                .semantics { contentDescription = LocaleStrings.t("compare.find.time", language) + ": " + timeText },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MeridiemText(text = timeText, sizeSp = 40f, weight = FontWeight.SemiBold, color = theme.textColor, meridiemScale = 0.45f)
            Icon(Icons.Default.KeyboardArrowDown, contentDescription = null, tint = theme.textColor.copy(alpha = 0.6f), modifier = Modifier.size(18.dp))
        }
        NudgeButton(Icons.Default.Add, LocaleStrings.t("compare.find.nudgeLater", language), theme) { onNudge(5) }
    }
}

@Composable
private fun NudgeButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    theme: ResolvedTheme,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .hapticClickable(onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = theme.textColor.copy(alpha = 0.75f), modifier = Modifier.size(24.dp))
    }
}

@Composable
private fun EmptyResults(
    timeText: String,
    theme: ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    atTimeHits: List<CompareFindHit>,
    atTimeRevealed: Boolean,
    onRevealAtTime: () -> Unit,
    row: @Composable (CompareFindHit) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        MeridiemText(
            text = LocaleStrings.t("compare.find.empty", language),
            sizeSp = 15f,
            color = theme.textColor.copy(alpha = 0.75f),
            maxLines = 3,
        )
        if (atTimeHits.isNotEmpty()) {
            if (atTimeRevealed) {
                atTimeHits.forEach { hit -> row(hit) }
            } else {
                MeridiemText(
                    text = LocaleStrings.format("compare.find.showAtTime", language, timeText),
                    sizeSp = 14f,
                    weight = FontWeight.SemiBold,
                    color = theme.textColor,
                    meridiemScale = 0.75f,
                    maxLines = 2,
                    modifier = Modifier
                        .hapticClickable(onClick = onRevealAtTime)
                        .padding(vertical = 6.dp),
                )
            }
        }
    }
}

@Composable
private fun ResultRow(
    hit: CompareFindHit,
    model: CompareViewModel,
    settingsStore: SettingsStore,
    theme: ResolvedTheme,
    onOpen: (Mosque) -> Unit,
) {
    val language = settingsStore.appLanguage
    val locale = settingsStore.resolvedLocale()
    val uses24 = settingsStore.uses24HourTime
    val prayerName = PrayerLocalization.displayName(hit.prayer.canonicalName(model.isFriday), language)
    val time = PrayerTimesEngine.formatPrayerTimeForDisplay(hit.raw, uses24, locale)
    val relative = model.relativeMinutes(hit)?.let { delta ->
        if (delta >= 0) LocaleStrings.format("compare.find.inMinutes", language, delta)
        else LocaleStrings.format("compare.find.minutesAgo", language, -delta)
    }
    var description = LocaleStrings.format("compare.a11y.result", language, prayerName, time, hit.mosque.name)
    if (relative != null) description += ", $relative"

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .hapticClickable { onOpen(hit.mosque) }
            .padding(vertical = 6.dp)
            .clearAndSetSemantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(modifier = Modifier.widthIn(min = 72.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            if (model.query.prayer == null) {
                Text(prayerName, style = rememberAppTextStyle(12f, FontWeight.Medium), color = theme.textColor.copy(alpha = 0.6f))
            }
            MeridiemText(text = time, sizeSp = 18f, weight = FontWeight.SemiBold, color = theme.textColor, meridiemScale = 0.65f)
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(hit.mosque.name, style = rememberAppTextStyle(15f, FontWeight.Medium), color = theme.textColor)
            relative?.let {
                Text(it, style = rememberAppTextStyle(12f), color = theme.textColor.copy(alpha = 0.6f))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CompareTimeDialog(
    initialMinutes: Int,
    uses24Hour: Boolean,
    theme: ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    onDismiss: () -> Unit,
    onConfirm: (Int) -> Unit,
) {
    val state = rememberTimePickerState(
        initialHour = initialMinutes / 60,
        initialMinute = initialMinutes % 60,
        is24Hour = uses24Hour,
    )
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(LocaleStrings.t("compare.find.time", language)) },
        text = { TimePicker(state = state) },
        confirmButton = {
            Text(
                text = LocaleStrings.t("compare.done", language),
                style = rememberAppTextStyle(16f, FontWeight.SemiBold),
                modifier = Modifier
                    .hapticClickable { onConfirm(state.hour * 60 + state.minute) }
                    .padding(12.dp),
            )
        },
        dismissButton = {
            Text(
                text = LocaleStrings.t("action.cancel", language),
                style = rememberAppTextStyle(16f),
                modifier = Modifier
                    .hapticClickable(onClick = onDismiss)
                    .padding(12.dp),
            )
        },
    )
}
