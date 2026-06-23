package com.mikhailspeaks.masjidly.features.qibla

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import kotlin.math.abs

/**
 * Native Android compass pipeline for portrait Qibla.
 *
 * Uses [Sensor.TYPE_ROTATION_VECTOR] first for iOS-like responsive fused heading,
 * processes on a background thread, low-pass filters heading, and throttles main-thread callbacks.
 */
internal class NativeCompassHeadingProvider(
    context: Context,
    private val coordinatesProvider: () -> Pair<Double, Double>?,
) {
    private val appContext = context.applicationContext
    private val sensorManager = appContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sensorThread: HandlerThread? = null
    private var sensorHandler: Handler? = null

    private val rotationMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasGeomagnetic = false

    private var smoothedHeading: Double? = null
    private var lastEmittedHeading: Double? = null
    private var lastEmitUptimeMs = 0L
    private var activeSensorType: Int? = null

    var onHeadingChanged: ((Double) -> Unit)? = null

    private val listener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            if (event.accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE) return

            val rawHeading = when (event.sensor.type) {
                Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR,
                Sensor.TYPE_ROTATION_VECTOR,
                -> headingFromRotationVector(event)
                Sensor.TYPE_ACCELEROMETER -> {
                    System.arraycopy(event.values, 0, gravity, 0, 3)
                    hasGravity = true
                    headingFromAccelMagnetometer()
                }
                Sensor.TYPE_MAGNETIC_FIELD -> {
                    System.arraycopy(event.values, 0, geomagnetic, 0, 3)
                    hasGeomagnetic = true
                    headingFromAccelMagnetometer()
                }
                else -> null
            } ?: return

            val smoothed = lowPassAngle(smoothedHeading, rawHeading, LOW_PASS_ALPHA)
            smoothedHeading = smoothed
            maybeEmitHeading(smoothed)
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    fun start() {
        stopSensorsOnly()
        smoothedHeading = null
        lastEmittedHeading = null
        lastEmitUptimeMs = 0L
        hasGravity = false
        hasGeomagnetic = false

        val thread = sensorThread?.takeIf { it.isAlive }
            ?: HandlerThread("masjidly-compass").also {
                it.start()
                sensorThread = it
                sensorHandler = Handler(it.looper)
            }
        if (sensorHandler == null) {
            sensorHandler = Handler(thread.looper)
        }
        val handler = sensorHandler ?: return

        val geoVector = sensorManager.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        val rotationVector = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

        when {
            rotationVector != null -> {
                activeSensorType = Sensor.TYPE_ROTATION_VECTOR
                register(rotationVector, handler)
            }
            geoVector != null -> {
                activeSensorType = Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR
                register(geoVector, handler)
            }
            accelerometer != null && magnetometer != null -> {
                activeSensorType = Sensor.TYPE_ACCELEROMETER
                register(accelerometer, handler)
                register(magnetometer, handler)
            }
        }
    }

    fun stop() {
        stopSensorsOnly()
        smoothedHeading = null
        lastEmittedHeading = null
        lastEmitUptimeMs = 0L
    }

    fun release() {
        stop()
        sensorThread?.quitSafely()
        sensorThread = null
        sensorHandler = null
    }

    private fun stopSensorsOnly() {
        try {
            sensorManager.unregisterListener(listener)
        } catch (_: Exception) {
        }
        activeSensorType = null
    }

    private fun register(sensor: Sensor, handler: Handler) {
        sensorManager.registerListener(
            listener,
            sensor,
            SensorManager.SENSOR_DELAY_GAME,
            handler,
        )
    }

    private fun headingFromRotationVector(event: SensorEvent): Double? {
        SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
        SensorManager.getOrientation(rotationMatrix, orientation)
        val magneticAzimuth = normalizeDegrees(Math.toDegrees(orientation[0].toDouble()))
        return trueHeadingDegrees(magneticAzimuth)
    }

    private fun headingFromAccelMagnetometer(): Double? {
        if (!hasGravity || !hasGeomagnetic) return null
        if (!SensorManager.getRotationMatrix(rotationMatrix, null, gravity, geomagnetic)) return null

        SensorManager.getOrientation(rotationMatrix, orientation)
        val magneticAzimuth = normalizeDegrees(Math.toDegrees(orientation[0].toDouble()))
        return trueHeadingDegrees(magneticAzimuth)
    }

    private fun trueHeadingDegrees(magneticAzimuth: Double): Double {
        val coordinates = coordinatesProvider() ?: return magneticAzimuth
        val field = GeomagneticField(
            coordinates.first.toFloat(),
            coordinates.second.toFloat(),
            0f,
            System.currentTimeMillis(),
        )
        return normalizeDegrees(magneticAzimuth + field.declination)
    }

    private fun maybeEmitHeading(heading: Double) {
        val now = SystemClock.uptimeMillis()
        if (now - lastEmitUptimeMs < EMIT_INTERVAL_MS) return

        val last = lastEmittedHeading
        if (last != null &&
            abs(QiblaDirectionCalculator.shortestSignedDeltaDegrees(last, heading)) < EMIT_DEADBAND_DEGREES
        ) {
            return
        }

        lastEmitUptimeMs = now
        lastEmittedHeading = heading
        mainHandler.post { onHeadingChanged?.invoke(heading) }
    }

    private fun lowPassAngle(previous: Double?, target: Double, alpha: Double): Double {
        if (previous == null) return target
        val delta = QiblaDirectionCalculator.shortestSignedDeltaDegrees(previous, target)
        return normalizeDegrees(previous + alpha * delta)
    }

    private fun normalizeDegrees(degrees: Double): Double {
        val remainder = degrees % 360.0
        return if (remainder >= 0) remainder else remainder + 360.0
    }

    companion object {
        private const val LOW_PASS_ALPHA = 0.35
        private const val EMIT_INTERVAL_MS = 16L
        private const val EMIT_DEADBAND_DEGREES = 0.25
    }
}
