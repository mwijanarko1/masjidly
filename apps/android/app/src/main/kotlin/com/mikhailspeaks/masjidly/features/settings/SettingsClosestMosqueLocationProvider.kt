package com.mikhailspeaks.masjidly.features.settings

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.mikhailspeaks.masjidly.features.qibla.LocationProviderSelection
import java.util.concurrent.Executor
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Location provider for the settings "closest mosque" row.
 * Mirrors iOS `SettingsClosestMosqueLocationProvider` + Expo `getCurrentPositionWithTimeout`.
 */
class SettingsClosestMosqueLocationProvider(context: Context) : LocationListener {
    private val appContext = context.applicationContext
    private val locationManager = appContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { mainHandler.post(it) }

    var currentLocation: Location? = null
        private set

    var onLocationUpdated: ((Location?) -> Unit)? = null

    fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    fun start() {
        if (!hasLocationPermission()) {
            clear()
            return
        }

        getBestLastKnown()?.let { location ->
            currentLocation = location
            onLocationUpdated?.invoke(location)
        }

        val provider = LocationProviderSelection.continuousUpdateProvider(locationManager) ?: return
        LocationProviderSelection.runSafely {
            locationManager.requestLocationUpdates(provider, 250L, 250f, this, Looper.getMainLooper())
        }
    }

    suspend fun fetchLocation(timeoutMs: Long = 8_000L): Location? {
        if (!hasLocationPermission()) return null

        getBestLastKnown()?.let { location ->
            if (isFresh(location)) {
                currentLocation = location
                onLocationUpdated?.invoke(location)
                return location
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val provider = LocationProviderSelection.singleShotProvider(locationManager) ?: return getBestLastKnown()
            val fromCurrent = requestCurrentLocation(provider, timeoutMs)
            if (fromCurrent != null) {
                currentLocation = fromCurrent
                onLocationUpdated?.invoke(fromCurrent)
                return fromCurrent
            }
        }

        return requestLocationWithTimeout(timeoutMs) ?: getBestLastKnown()?.also {
            currentLocation = it
            onLocationUpdated?.invoke(it)
        }
    }

    fun clear() {
        currentLocation = null
        onLocationUpdated?.invoke(null)
        LocationProviderSelection.runSafely {
            locationManager.removeUpdates(this)
        }
    }

    override fun onLocationChanged(location: Location) {
        currentLocation = location
        onLocationUpdated?.invoke(location)
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    override fun onProviderEnabled(provider: String) = Unit

    override fun onProviderDisabled(provider: String) = Unit

    private fun getBestLastKnown(): Location? {
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
        return best
    }

    private fun isFresh(location: Location): Boolean {
        val ageMs = System.currentTimeMillis() - location.time
        return ageMs in 0..LAST_KNOWN_MAX_AGE_MS
    }

    private suspend fun requestCurrentLocation(provider: String, timeoutMs: Long): Location? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return suspendCancellableCoroutine { cont ->
            val signal = CancellationSignal()
            cont.invokeOnCancellation { signal.cancel() }
            val timeout = Runnable {
                signal.cancel()
                if (cont.isActive) cont.resume(null)
            }
            mainHandler.postDelayed(timeout, timeoutMs)
            if (!LocationProviderSelection.runSafely {
                    locationManager.getCurrentLocation(provider, signal, mainExecutor) { location ->
                        mainHandler.removeCallbacks(timeout)
                        if (cont.isActive) cont.resume(location)
                    }
                }
            ) {
                mainHandler.removeCallbacks(timeout)
                if (cont.isActive) cont.resume(null)
            }
        }
    }

    private suspend fun requestLocationWithTimeout(timeoutMs: Long): Location? =
        suspendCancellableCoroutine { cont ->
            val provider = LocationProviderSelection.continuousUpdateProvider(locationManager)
            if (provider == null) {
                cont.resume(null)
                return@suspendCancellableCoroutine
            }

            var listenerRef: LocationListener? = null
            val timeoutRunnable = Runnable {
                listenerRef?.let { activeListener ->
                    LocationProviderSelection.runSafely {
                        locationManager.removeUpdates(activeListener)
                    }
                }
                if (cont.isActive) cont.resume(null)
            }

            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    LocationProviderSelection.runSafely {
                        locationManager.removeUpdates(this)
                    }
                    if (cont.isActive) cont.resume(location)
                }

                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
            }
            listenerRef = listener

            cont.invokeOnCancellation {
                mainHandler.removeCallbacks(timeoutRunnable)
                LocationProviderSelection.runSafely {
                    locationManager.removeUpdates(listener)
                }
            }

            if (!LocationProviderSelection.runSafely {
                    locationManager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
                    mainHandler.postDelayed(timeoutRunnable, timeoutMs)
                }
            ) {
                if (cont.isActive) cont.resume(null)
            }
        }

    companion object {
        private const val LAST_KNOWN_MAX_AGE_MS = 15 * 60 * 1000L
    }
}
