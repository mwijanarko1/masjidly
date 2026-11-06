package com.mikhailspeaks.masjidly.features.compare

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Mirrors iOS `CompareView`: mode switch, day stepper and the two Compare modes. */
@Composable
fun CompareScreen(
    homeViewModel: HomeViewModel,
    settingsStore: SettingsStore,
    onBack: () -> Unit,
    onOpenMosque: (Mosque) -> Unit,
) {
    val homeState by homeViewModel.uiState.collectAsState()
    val settingsRevision by settingsStore.revision.collectAsState()
    val language = settingsStore.appLanguage
    val locale = settingsStore.resolvedLocale()

    val dynamicTheme = TimeTheme.homeHeroTheme(homeState.displayedPrayerTimes, homeState.selectedPrayerIndex)
    val theme = settingsStore.resolvedTheme(dynamicTheme)

    val store = remember { homeViewModel.makeCompareDataStore() }
    val model = remember(homeState.mosques) {
        CompareViewModel(
            mosques = homeState.mosques,
            homeMosque = homeState.selectedMosque,
            settings = settingsStore,
            store = store,
            initialDate = homeState.displayedDate,
        )
    }
    DisposableEffect(store) { onDispose { store.cancel() } }

    val revision by store.revision.collectAsState()

    // Passed to the content so it recomposes when payloads or settings change. The model reads
    // store state that Compose cannot observe, so without a changed argument the content is skipped.
    val tick = revision + settingsRevision

    val mode = model.mode
    val loadKey = listOf(
        mode,
        model.date,
        if (mode == CompareMode.BY_TIME) model.cityKey else "",
        if (mode == CompareMode.MASJIDS) model.listedMosques.map { it.id } else emptyList<String>(),
    )
    LaunchedEffect(loadKey) {
        when (mode) {
            CompareMode.MASJIDS -> model.loadMasjids()
            CompareMode.BY_TIME -> model.loadFind()
        }
    }

    var showPicker by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(theme.sky.baseColors)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            CompareHeader(
                title = LocaleStrings.t("compare.title", language),
                closeLabel = LocaleStrings.t("compare.close", language),
                theme = theme,
                onBack = onBack,
            )
            CompareModeSwitch(
                mode = mode,
                language = language,
                theme = theme,
                onSelect = { model.mode = it },
            )
            CompareDayStepper(
                title = dayTitle(model, locale),
                theme = theme,
                language = language,
                onStep = model::stepDay,
            )
            when (mode) {
                CompareMode.MASJIDS -> CompareMasjidsContent(
                    revision = tick,
                    model = model,
                    settingsStore = settingsStore,
                    theme = theme,
                    onAdd = { showPicker = true },
                    onOpen = onOpenMosque,
                )
                CompareMode.BY_TIME -> CompareFindContent(
                    revision = tick,
                    model = model,
                    settingsStore = settingsStore,
                    theme = theme,
                    onOpen = onOpenMosque,
                )
            }
        }
    }

    if (showPicker) {
        CompareMosquePicker(
            mosques = homeState.mosques,
            homeMosqueId = homeState.selectedMosque?.id,
            model = model,
            theme = theme,
            language = language,
            onDismiss = { showPicker = false },
        )
    }
}

private fun dayTitle(model: CompareViewModel, locale: Locale): String =
    DateTimeFormatter.ofPattern("EEE d MMM", locale)
        .withZone(ZoneOffset.UTC)
        .format(model.date)

@Composable
private fun CompareHeader(
    title: String,
    closeLabel: String,
    theme: com.mikhailspeaks.masjidly.ui.home.ResolvedTheme,
    onBack: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = title,
            style = rememberAppTextStyle(20f, FontWeight.Medium),
            color = theme.textColor,
        )
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .size(36.dp)
                .clip(CircleShape)
                .background(theme.textColor.copy(alpha = 0.1f))
                .hapticClickable(onClick = onBack)
                .semantics { contentDescription = closeLabel },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Close, contentDescription = null, tint = theme.textColor, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun CompareModeSwitch(
    mode: CompareMode,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    theme: com.mikhailspeaks.masjidly.ui.home.ResolvedTheme,
    onSelect: (CompareMode) -> Unit,
) {
    val shape = RoundedCornerShape(percent = 50)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp)
            .clip(shape)
            .background(theme.textColor.copy(alpha = 0.1f))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        listOf(
            CompareMode.MASJIDS to "compare.mode.masjids",
            CompareMode.BY_TIME to "compare.mode.byTime",
        ).forEach { (value, key) ->
            val selected = value == mode
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(shape)
                    .background(if (selected) theme.textColor.copy(alpha = 0.92f) else Color.Transparent)
                    .hapticClickable { onSelect(value) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = LocaleStrings.t(key, language),
                    style = rememberAppTextStyle(15f, if (selected) FontWeight.SemiBold else FontWeight.Normal),
                    color = when {
                        selected && theme.usesLightForeground -> Color.Black
                        selected -> Color.White
                        else -> theme.textColor.copy(alpha = 0.75f)
                    },
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun CompareDayStepper(
    title: String,
    theme: com.mikhailspeaks.masjidly.ui.home.ResolvedTheme,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
    onStep: (Int) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StepButton(Icons.Default.ChevronLeft, LocaleStrings.t("accessibility.previous_day", language), theme) { onStep(-1) }
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Center,
            style = rememberAppTextStyle(17f, FontWeight.Medium),
            color = theme.textColor,
        )
        StepButton(Icons.Default.ChevronRight, LocaleStrings.t("accessibility.next_day", language), theme) { onStep(1) }
    }
}

@Composable
private fun StepButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    theme: com.mikhailspeaks.masjidly.ui.home.ResolvedTheme,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .hapticClickable(onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = theme.textColor, modifier = Modifier.size(22.dp))
    }
}
