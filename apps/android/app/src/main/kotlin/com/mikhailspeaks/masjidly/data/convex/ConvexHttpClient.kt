package com.mikhailspeaks.masjidly.data.convex

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.put
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Official Convex HTTP query API — same functions as iOS ConvexMobile / Expo ConvexReactClient.
 * POST `{deploymentUrl}/api/query` with `{ path, args, format }`.
 */
class ConvexHttpClient(
    private val deploymentUrl: String,
    private val json: Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    },
) {
    suspend fun query(path: String, args: Map<String, JsonElement>): JsonElement =
        withContext(Dispatchers.IO) {
            val connection = (URL("$deploymentUrl/api/query").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
            }

            val body = buildJsonObject {
                put("path", path)
                put("args", buildJsonObject {
                    args.forEach { (key, value) -> put(key, value) }
                })
                put("format", "json")
            }

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(json.encodeToString(body))
            }

            val responseCode = connection.responseCode
            val stream = if (responseCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }
            val responseText = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
            connection.disconnect()

            if (responseCode !in 200..299) {
                throw ConvexHttpException("HTTP $responseCode: $responseText")
            }

            val envelope = json.decodeFromString<ConvexQueryResponse>(responseText)
            if (envelope.status != "success") {
                throw ConvexHttpException(envelope.errorMessage ?: "Convex query failed: $path")
            }
            envelope.value ?: JsonNull
        }

    fun jsonArgs(block: MutableMap<String, JsonElement>.() -> Unit): Map<String, JsonElement> =
        buildMap(block).toMap()
}

class ConvexHttpException(message: String) : Exception(message)

inline fun MutableMap<String, JsonElement>.putString(key: String, value: String) {
    put(key, Json.encodeToJsonElement(value))
}

inline fun MutableMap<String, JsonElement>.putDouble(key: String, value: Double) {
    put(key, Json.encodeToJsonElement(value))
}
