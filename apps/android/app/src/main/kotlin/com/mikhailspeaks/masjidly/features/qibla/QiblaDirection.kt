package com.mikhailspeaks.masjidly.features.qibla

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import com.mikhailspeaks.masjidly.domain.Mosque
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan

private const val ROTATION_DEADBAND_DEGREES = 0.5

/** Mirrors iOS `QiblaDirectionCalculator`. */
object QiblaDirectionCalculator {
    private const val KAABA_LAT = 21.4225
    private const val KAABA_LNG = 39.8262

    fun bearingDegrees(latitude: Double, longitude: Double): Double {
        val startLat = Math.toRadians(latitude)
        val startLng = Math.toRadians(longitude)
        val destLat = Math.toRadians(KAABA_LAT)
        val destLng = Math.toRadians(KAABA_LNG)
        val deltaLng = destLng - startLng
        val y = sin(deltaLng)
        val x = cos(startLat) * tan(destLat) - sin(startLat) * cos(deltaLng)
        return normalizeDegrees(Math.toDegrees(atan2(y, x)))
    }

    fun indicatorRotationDegrees(qiblaBearing: Double, heading: Double?): Double {
        return normalizeDegrees(qiblaBearing - (heading ?: 0.0))
    }

    fun continuousRotationDegrees(previous: Double?, target: Double): Double {
        if (previous == null) return target
        val delta = normalizeDegrees(target - previous + 180.0) - 180.0
        return previous + delta
    }

    fun shortestSignedDeltaDegrees(from: Double, to: Double): Double {
        return normalizeDegrees(to - from + 180.0) - 180.0
    }

    private fun normalizeDegrees(degrees: Double): Double {
        val remainder = degrees % 360.0
        return if (remainder >= 0) remainder else remainder + 360.0
    }
}

/**
 * Qibla direction provider — native compass heading + GPS/mosque bearing.
 * Mirrors iOS `QiblaDirectionProvider`.
 */
class QiblaDirectionProvider(context: Context) : LocationListener {
    private val appContext = context.applicationContext
    private val locationManager = appContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val compass = NativeCompassHeadingProvider(appContext) { currentCoordinates }

    private var fallbackMosque: Mosque? = null
    private var headingDegrees: Double? = null
    private var latitude: Double? = null
    private var longitude: Double? = null

    var displayedRotationDegrees: Double? = null
        private set

    var onDisplayedRotationChanged: ((Double?) -> Unit)? = null

    init {
        compass.onHeadingChanged = { heading ->
            headingDegrees = heading
            updateDisplayedRotation()
        }
    }

    fun updateFallbackMosque(mosque: Mosque?) {
        fallbackMosque = mosque
        updateDisplayedRotation()
    }

    fun start() {
        updateDisplayedRotation()
        compass.start()
        if (!hasLocationPermission()) {
            seedLastKnownLocation()
            updateDisplayedRotation()
            return
        }
        seedLastKnownLocation()
        val provider = LocationProviderSelection.continuousUpdateProvider(locationManager) ?: return
        LocationProviderSelection.runSafely {
            locationManager.requestLocationUpdates(provider, 250L, 250f, this, Looper.getMainLooper())
        }
    }

    fun stop() {
        compass.stop()
        LocationProviderSelection.runSafely {
            locationManager.removeUpdates(this)
        }
        headingDegrees = null
        latitude = null
        longitude = null
        setDisplayedRotation(null)
    }

    fun release() {
        stop()
        compass.release()
    }

    override fun onLocationChanged(location: Location) {
        latitude = location.latitude
        longitude = location.longitude
        updateDisplayedRotation()
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    private fun updateDisplayedRotation() {
        val coordinates = currentCoordinates ?: return

        val bearing = QiblaDirectionCalculator.bearingDegrees(
            coordinates.first,
            coordinates.second,
        )
        val targetRotation = QiblaDirectionCalculator.indicatorRotationDegrees(
            qiblaBearing = bearing,
            heading = headingDegrees,
        )
        val continuousRotation = QiblaDirectionCalculator.continuousRotationDegrees(
            previous = displayedRotationDegrees,
            target = targetRotation,
        )

        val previous = displayedRotationDegrees
        if (previous == null) {
            setDisplayedRotation(continuousRotation)
            return
        }

        if (abs(continuousRotation - previous) >= ROTATION_DEADBAND_DEGREES) {
            setDisplayedRotation(continuousRotation)
        }
    }

    private val currentCoordinates: Pair<Double, Double>?
        get() {
            latitude?.let { lat -> longitude?.let { lng -> return lat to lng } }
            fallbackMosque?.let { return it.lat to it.lng }
            return null
        }

    private fun setDisplayedRotation(value: Double?) {
        if (displayedRotationDegrees == value) return
        displayedRotationDegrees = value
        onDisplayedRotationChanged?.invoke(value)
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    private fun seedLastKnownLocation() {
        if (!hasLocationPermission()) return
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        )
        var best: Location? = null
        for (provider in providers) {
            LocationProviderSelection.runSafely {
                locationManager.getLastKnownLocation(provider)?.let { location ->
                    if (best == null || location.time > best!!.time) {
                        best = location
                    }
                }
            }
        }
        best?.let { onLocationChanged(it) }
    }
}

@Composable
fun rememberQiblaRotation(
    context: Context,
    mosque: Mosque?,
    enabled: Boolean,
    locationPermissionGranted: Boolean = false,
): Float? {
    val provider = remember { QiblaDirectionProvider(context) }
    var rotation by remember { mutableFloatStateOf(0f) }
    var hasRotation by remember { mutableStateOf(false) }

    DisposableEffect(enabled, mosque?.id, locationPermissionGranted) {
        if (!enabled) {
            provider.release()
            hasRotation = false
            onDispose { }
        } else {
            provider.onDisplayedRotationChanged = { value ->
                if (value != null) {
                    rotation = value.toFloat()
                    hasRotation = true
                } else {
                    hasRotation = false
                }
            }
            provider.updateFallbackMosque(mosque)
            provider.start()
            onDispose {
                provider.onDisplayedRotationChanged = null
                provider.release()
                hasRotation = false
            }
        }
    }

    // No Compose animation — native compass low-pass + throttling handles smoothness.
    return if (enabled && hasRotation) rotation else null
}
