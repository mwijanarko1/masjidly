package com.mikhailspeaks.masjidly.features.compare

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerLocalization
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.launch

private val EarlierGreen = Color(0xFF34C759)
private val LaterOrange = Color(0xFFFF9500)

/** Mirrors iOS `CompareMasjidsView`. */
@Composable
internal fun CompareMasjidsContent(
    revision: Int,
    model: CompareViewModel,
    settingsStore: SettingsStore,
    theme: ResolvedTheme,
    onAdd: () -> Unit,
    onOpen: (Mosque) -> Unit,
) {
    val language = settingsStore.appLanguage
    if (model.listedMosques.isEmpty()) {
        CompareEmptyState(theme = theme, language = language, onAdd = onAdd)
        return
    }
    var editing by remember { mutableStateOf(false) }
    if (model.listedMosques.size <= 1 && editing) editing = false

    Column(modifier = Modifier.fillMaxSize()) {
        ListHeader(model, theme, language, editing, onToggleEdit = { editing = !editing }, onAdd = onAdd)
        CompareGrid(revision, model, settingsStore, theme, editing, onOpen)
    }
}

@Composable
private fun CompareEmptyState(theme: ResolvedTheme, language: com.mikhailspeaks.masjidly.domain.AppLanguage, onAdd: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = LocaleStrings.t("compare.empty.title", language),
            style = rememberAppTextStyle(22f, FontWeight.SemiBold),
            color = theme.textColor,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            text = LocaleStrings.t("compare.empty.body", language),
            style = rememberAppTextStyle(16f),
            color = theme.textColor.copy(alpha = 0.75f),
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(18.dp))
        CompareCapsuleButton(text = "+  " + LocaleStrings.t("compare.add", language), theme = theme, onClick = onAdd)
        Spacer(Modifier.height(64.dp))
    }
}

@Composable
private fun ListHeader(
    model: CompareViewModel,
    theme: ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    editing: Boolean,
    onToggleEdit: () -> Unit,
    onAdd: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 12.dp, top = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.weight(1f)) {
            CompareTextTabs(
                options = listOf(
                    CompareTimeType.ADHAN to LocaleStrings.t("timetable.header.adhan", language),
                    CompareTimeType.JAMAAT to LocaleStrings.t("timetable.header.iqamah", language),
                ),
                selection = model.gridTimeType,
                theme = theme,
                sizeSp = 16f,
                equalWidth = false,
            ) { model.gridTimeType = it }
        }
        if (model.listedMosques.size > 1) {
            Text(
                text = LocaleStrings.t(if (editing) "compare.done" else "compare.edit", language),
                style = rememberAppTextStyle(15f, FontWeight.SemiBold),
                color = theme.textColor,
                modifier = Modifier
                    .hapticClickable(onClick = onToggleEdit)
                    .padding(horizontal = 8.dp, vertical = 10.dp),
            )
        }
        Box(
            modifier = Modifier
                .size(40.dp)
                .hapticClickable(onClick = onAdd)
                .semantics { contentDescription = LocaleStrings.t("compare.add", language) },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Add, contentDescription = null, tint = theme.textColor, modifier = Modifier.size(24.dp))
        }
    }
}

@Composable
private fun CompareGrid(
    // Changes when any payload loads. The grid reads store state Compose cannot observe, so it needs a new argument to recompose.
    revision: Int,
    model: CompareViewModel,
    settingsStore: SettingsStore,
    theme: ResolvedTheme,
    editing: Boolean,
    onOpen: (Mosque) -> Unit,
) {
    val language = settingsStore.appLanguage
    readRevision(revision)
    val rows = model.rows
    val multiCity = rows.map { it.mosque.cityGroupingKey }.toSet().size > 1
    val isJummah = model.isFriday
    val highlights = model.highlightedMosqueIds

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(bottom = 32.dp),
    ) {
        Row(modifier = Modifier.padding(top = 8.dp)) {
            ComparePrayer.entries.forEach { prayer ->
                HeaderCell(prayer, isJummah, model, theme, language, Modifier.weight(1f))
            }
        }
        rows.forEach { row ->
            RowBlock(row, multiCity, isJummah, editing, model, settingsStore, theme, highlights, onOpen)
        }
        if (rows.size == 1) {
            Text(
                text = LocaleStrings.t("compare.empty.body", language),
                style = rememberAppTextStyle(14f),
                color = theme.textColor.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 12.dp),
            )
        }
    }
}

@Composable
private fun HeaderCell(
    prayer: ComparePrayer,
    isJummah: Boolean,
    model: CompareViewModel,
    theme: ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    modifier: Modifier,
) {
    val name = PrayerLocalization.displayName(prayer.canonicalName(isJummah), language)
    val sort = model.sort
    val active = sort?.first == prayer
    val state = if (active) LocaleStrings.t(if (sort!!.second) "compare.sort.asc" else "compare.sort.desc", language) else ""
    Row(
        modifier = modifier
            .hapticClickable { model.tapHeader(prayer) }
            .padding(vertical = 8.dp)
            .semantics { contentDescription = if (state.isEmpty()) name else "$name, $state" },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = name,
            style = rememberAppTextStyle(13f, if (active) FontWeight.SemiBold else FontWeight.Normal),
            color = theme.textColor.copy(alpha = if (active) 1f else 0.55f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (active) {
            Icon(
                if (sort!!.second) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward,
                contentDescription = null,
                tint = theme.textColor,
                modifier = Modifier.size(11.dp),
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun RowBlock(
    row: CompareViewModel.Row,
    showCity: Boolean,
    isJummah: Boolean,
    editing: Boolean,
    model: CompareViewModel,
    settingsStore: SettingsStore,
    theme: ResolvedTheme,
    highlights: Map<ComparePrayer, Set<String>>,
    onOpen: (Mosque) -> Unit,
) {
    val language = settingsStore.appLanguage
    var menuOpen by remember { mutableStateOf(false) }
    Column(
        modifier = Modifier.padding(vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (editing && !row.isYours) {
                Box(
                    modifier = Modifier
                        .size(width = 24.dp, height = 32.dp)
                        .hapticClickable { model.remove(row.mosque) }
                        .semantics {
                            contentDescription = LocaleStrings.t("compare.remove", language) + " " + row.mosque.name
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Default.RemoveCircle, contentDescription = null, tint = Color(0xFFFF3B30), modifier = Modifier.size(20.dp))
                }
            }
            Box(modifier = Modifier.weight(1f)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .combinedClickable(onClick = { onOpen(row.mosque) }, onLongClick = { menuOpen = true }),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = row.mosque.name,
                        style = rememberAppTextStyle(16f, FontWeight.SemiBold),
                        color = theme.textColor,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    noteText(row, showCity, language)?.let { note ->
                        Text(
                            text = note,
                            style = rememberAppTextStyle(12f),
                            color = theme.textColor.copy(alpha = 0.55f),
                            maxLines = 1,
                        )
                    }
                }
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                    DropdownMenuItem(
                        text = { Text(LocaleStrings.t("compare.openOnHome", language)) },
                        onClick = {
                            menuOpen = false
                            onOpen(row.mosque)
                        },
                    )
                    if (!row.isYours) {
                        DropdownMenuItem(
                            text = { Text(LocaleStrings.t("compare.remove", language)) },
                            onClick = {
                                menuOpen = false
                                model.remove(row.mosque)
                            },
                        )
                    }
                }
            }
        }
        TimesLine(row, isJummah, model, settingsStore, theme, highlights)
    }
}

private fun noteText(row: CompareViewModel.Row, showCity: Boolean, language: com.mikhailspeaks.masjidly.domain.AppLanguage): String? {
    val parts = buildList {
        if (row.isYours) add(LocaleStrings.t("compare.yours", language))
        if (showCity) add(row.mosque.cityDisplayName)
    }
    return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
}

@Composable
private fun TimesLine(
    row: CompareViewModel.Row,
    isJummah: Boolean,
    model: CompareViewModel,
    settingsStore: SettingsStore,
    theme: ResolvedTheme,
    highlights: Map<ComparePrayer, Set<String>>,
) {
    val times = row.times
    val scope = rememberCoroutineScope()
    when {
        times != null -> Row(verticalAlignment = Alignment.Top) {
            ComparePrayer.entries.forEach { prayer ->
                TimeCell(
                    row, times, prayer, isJummah, model, settingsStore, theme,
                    highlighted = highlights[prayer]?.contains(row.mosque.id) == true,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        row.state is CompareState.Loaded -> Row {
            ComparePrayer.entries.forEach { _ ->
                Text(
                    text = "-",
                    style = rememberAppTextStyle(17f),
                    color = theme.textColor.copy(alpha = 0.4f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        else -> StatusCell(row.state, theme, settingsStore.appLanguage) { scope.launch { model.loadMasjids() } }
    }
}

@Composable
private fun TimeCell(
    row: CompareViewModel.Row,
    times: CompareDayTimes,
    prayer: ComparePrayer,
    isJummah: Boolean,
    model: CompareViewModel,
    settingsStore: SettingsStore,
    theme: ResolvedTheme,
    highlighted: Boolean,
    modifier: Modifier,
) {
    val language = settingsStore.appLanguage
    val locale = settingsStore.resolvedLocale()
    val uses24 = settingsStore.uses24HourTime
    val slots = times.iqamah[prayer].orEmpty()
    val delta = row.deltas[prayer]
    val adhan = times.adhan[prayer]
    val adhanSelected = model.gridTimeType == CompareTimeType.ADHAN
    fun clock(raw: String) = PrayerTimesEngine.formatPrayerTimeHeroParts(raw, uses24, locale).clock

    val prayerName = PrayerLocalization.displayName(prayer.canonicalName(isJummah), language)
    val value = if (slots.isEmpty()) "-" else slots.joinToString(", ") {
        PrayerTimesEngine.formatPrayerTimeForDisplay(it.raw, uses24, locale)
    }
    var description = LocaleStrings.format("compare.a11y.cell", language, row.mosque.name, prayerName, value)
    if (adhan != null) {
        description += ", ${LocaleStrings.t("timetable.header.adhan", language)} " +
            PrayerTimesEngine.formatPrayerTimeForDisplay(adhan, uses24, locale)
    }
    if (delta != null) description += ", " + LocaleStrings.format("compare.a11y.delta", language, CompareDelta.label(delta))

    Column(
        modifier = modifier.clearAndSetSemantics { contentDescription = description },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        if (adhan != null) {
            Text(
                text = clock(adhan),
                style = rememberAppTextStyle(if (adhanSelected) 17f else 11f, if (adhanSelected) FontWeight.SemiBold else FontWeight.Normal, tabularDigits = true),
                color = theme.textColor.copy(alpha = if (adhanSelected) 1f else 0.5f),
                maxLines = 1,
                softWrap = false,
            )
        } else if (adhanSelected) {
            Text("-", style = rememberAppTextStyle(17f), color = theme.textColor.copy(alpha = 0.4f))
        }
        if (slots.isEmpty()) {
            if (!adhanSelected) Text("-", style = rememberAppTextStyle(17f), color = theme.textColor.copy(alpha = 0.4f))
        } else {
            slots.forEach { slot ->
                if (slot.minutes != null) {
                    Text(
                        text = clock(slot.raw),
                        style = rememberAppTextStyle(
                            if (adhanSelected) 11f else 17f,
                            if (adhanSelected) FontWeight.Normal else if (highlighted) FontWeight.ExtraBold else FontWeight.SemiBold,
                            tabularDigits = true,
                        ),
                        color = theme.textColor.copy(alpha = if (adhanSelected) 0.5f else 1f),
                        maxLines = 1,
                        softWrap = false,
                    )
                } else {
                    Text(
                        text = slot.raw,
                        style = rememberAppTextStyle(11f),
                        color = theme.textColor.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
        if (delta != null) DeltaPill(delta, theme)
    }
}

/** Earlier than yours is green, later is orange, the same is quiet. */
@Composable
private fun DeltaPill(delta: Int, theme: ResolvedTheme) {
    val tint = when {
        delta < 0 -> EarlierGreen
        delta > 0 -> LaterOrange
        else -> theme.textColor
    }
    val shape = RoundedCornerShape(percent = 50)
    Text(
        text = CompareDelta.displayLabel(delta),
        style = rememberAppTextStyle(13f, FontWeight.Bold, tabularDigits = true),
        color = if (delta == 0) theme.textColor.copy(alpha = 0.6f) else theme.textColor,
        maxLines = 1,
        modifier = Modifier
            .padding(top = 2.dp)
            .clip(shape)
            .background(tint.copy(alpha = if (delta == 0) 0.12f else 0.30f))
            .then(if (delta == 0) Modifier else Modifier.border(1.dp, tint.copy(alpha = 0.55f), shape))
            .padding(horizontal = 7.dp, vertical = 2.dp),
    )
}

@Composable
private fun StatusCell(
    state: CompareState,
    theme: ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    onRetry: () -> Unit,
) {
    Box(modifier = Modifier.padding(vertical = 6.dp)) {
        when (state) {
            CompareState.Idle, CompareState.Loading ->
                CircularProgressIndicator(color = theme.textColor, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
            CompareState.Offline -> Text(
                LocaleStrings.t("compare.error.offline", language),
                style = rememberAppTextStyle(13f),
                color = theme.textColor.copy(alpha = 0.7f),
            )
            CompareState.Failed -> Text(
                LocaleStrings.t("compare.error.load", language),
                style = rememberAppTextStyle(13f, FontWeight.Medium),
                color = theme.textColor.copy(alpha = 0.85f),
                modifier = Modifier.hapticClickable(onClick = onRetry),
            )
            is CompareState.Loaded -> Text("-", style = rememberAppTextStyle(17f), color = theme.textColor.copy(alpha = 0.4f))
        }
    }
}
