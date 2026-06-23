package com.mikhailspeaks.masjidly.features.qibla

import android.location.LocationManager
import android.os.Build

/**
 * Picks location providers for Masjidly.
 *
 * [continuousUpdateProvider] is for [LocationManager.requestLocationUpdates].
 * The fused provider only supports one-shot reads via [LocationManager.getCurrentLocation],
 * so continuous updates must use GPS/network.
 */
internal object LocationProviderSelection {
    fun continuousUpdateProvider(locationManager: LocationManager): String? {
        val providers = buildList {
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                add(LocationManager.GPS_PROVIDER)
            }
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                add(LocationManager.NETWORK_PROVIDER)
            }
        }
        return providers.firstOrNull()
    }

    fun singleShotProvider(locationManager: LocationManager): String? {
        val providers = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                locationManager.isProviderEnabled(LocationManager.FUSED_PROVIDER)
            ) {
                add(LocationManager.FUSED_PROVIDER)
            }
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                add(LocationManager.GPS_PROVIDER)
            }
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                add(LocationManager.NETWORK_PROVIDER)
            }
        }
        return providers.firstOrNull()
    }

    inline fun runSafely(block: () -> Unit): Boolean {
        return try {
            block()
            true
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }
}
