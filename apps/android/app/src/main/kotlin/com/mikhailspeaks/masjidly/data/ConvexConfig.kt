package com.mikhailspeaks.masjidly.data

import com.mikhailspeaks.masjidly.BuildConfig

/**
 * Convex deployment URLs mirrored from iOS `ConvexConfiguration.swift`.
 */
object ConvexConfig {
    val deploymentUrl: String
        get() = if (BuildConfig.DEBUG) {
            "https://upbeat-goat-583.eu-west-1.convex.cloud"
        } else {
            "https://zany-mockingbird-207.eu-west-1.convex.cloud"
        }
}
