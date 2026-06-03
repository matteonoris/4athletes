package com.matteonoris.app4athletes

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import java.time.Duration
import java.time.Instant
import kotlin.math.pow
import kotlin.math.sqrt

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.4athletes.health/hrv"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getRRIntervals") {
                // TODO: Implementazione Health Connect per leggere HeartRateVariabilityRmssdRecord
                // Per ora ritorniamo una lista vuota in attesa dell'integrazione SDK Health Connect
                result.success(emptyList<Double>())
            } else if (call.method == "getNormalizedWorkouts") {
                CoroutineScope(Dispatchers.Main).launch {
                    try {
                        val pipeline = FitnessDataPipeline()
                        // Mock data for compilation since HealthConnectClient needs context and permission check
                        val rawDataList = emptyList<RawWorkoutData>() 
                        val normalized = pipeline.processWorkouts(rawDataList)
                        val jsonList = normalized.map { nw ->
                            mapOf(
                                "id" to nw.id,
                                "sourceName" to nw.sourceName,
                                "startTime" to nw.startTime.toEpochMilli(),
                                "endTime" to nw.endTime.toEpochMilli(),
                                "activeDuration" to nw.activeDuration.seconds.toDouble(),
                                "totalDistance" to (nw.totalDistance ?: 0.0),
                                "averagePace" to (nw.averagePace ?: 0.0)
                            )
                        }
                        result.success(jsonList)
                    } catch (e: Exception) {
                        result.error("PIPELINE_ERROR", "Errore: ${e.message}", null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

// MARK: - Pipeline Code

data class NormalizedWorkout(
    val id: String, val sourceName: String, val activityType: Int, val startTime: Instant, val endTime: Instant,
    val elapsedDuration: Duration, val activeDuration: Duration, val totalDistance: Double?, val averagePace: Double?,
    val maxHeartRate: Double?, val averageHeartRate: Double?, val heartRateSamples: List<HeartRateSample>
)

data class HeartRateSample(val date: Instant, val value: Double)

data class RawWorkoutData(
    val session: ExerciseSessionRecord, val heartRateRecords: List<HeartRateRecord>, val totalDistanceMeters: Double? = null
)

class DeduplicationFilter {
    private val sourcePriority = mapOf(
        "com.google.android.apps.fitness" to 1, "com.garmin.android.apps.connectmobile" to 2,
        "com.polar.polarbeat" to 3, "com.strava" to 10, "com.nike.plusgps" to 11
    )
    fun process(workouts: List<RawWorkoutData>): List<RawWorkoutData> {
        val sorted = workouts.sortedBy { it.session.startTime }
        val resolved = mutableListOf<RawWorkoutData>()
        for (current in sorted) {
            val overlapIndex = resolved.indexOfFirst { overlaps(it.session, current.session) }
            if (overlapIndex != -1) {
                if (priority(current) < priority(resolved[overlapIndex])) {
                    resolved[overlapIndex] = current
                }
            } else { resolved.add(current) }
        }
        return resolved
    }
    private fun overlaps(s1: ExerciseSessionRecord, s2: ExerciseSessionRecord): Boolean {
        return s1.startTime.isBefore(s2.endTime) && s2.startTime.isBefore(s1.endTime)
    }
    private fun priority(data: RawWorkoutData): Int {
        val packageName = data.session.metadata.dataOrigin.packageName
        return sourcePriority.entries.firstOrNull { packageName.contains(it.key, ignoreCase = true) }?.value ?: 100
    }
}

class HeartRateSmoothingFilter {
    fun process(records: List<HeartRateRecord>): Triple<Double?, Double?, List<HeartRateSample>> {
        val allSamples = records.flatMap { it.samples }.sortedBy { it.time }
        if (allSamples.isEmpty()) return Triple(null, null, emptyList())
        val rawValues = allSamples.map { it.beatsPerMinute.toDouble() }
        val filteredSamples = mutableListOf<HeartRateSample>()
        val validValues = mutableListOf<Double>()
        for (i in allSamples.indices) {
            val start = maxOf(0, i - 2)
            val end = minOf(allSamples.size - 1, i + 2)
            val window = rawValues.subList(start, end + 1)
            val mean = window.average()
            val variance = window.map { (it - mean).pow(2) }.average()
            val stdDev = sqrt(variance)
            val maxAllowed = maxOf(2 * stdDev, 10.0)
            if (Math.abs(rawValues[i] - mean) <= maxAllowed) {
                filteredSamples.add(HeartRateSample(allSamples[i].time, rawValues[i]))
                validValues.add(rawValues[i])
            }
        }
        val maxHR = validValues.maxOrNull()
        val avgHR = if (validValues.isNotEmpty()) validValues.average() else null
        return Triple(maxHR, avgHR, filteredSamples)
    }
}

class PaceAndPauseCalculator {
    fun process(session: ExerciseSessionRecord, distanceMeters: Double?): Pair<Duration, Double?> {
        val elapsedDuration = Duration.between(session.startTime, session.endTime)
        var activeDuration = elapsedDuration
        val segments = session.segments
        if (!segments.isNullOrEmpty()) {
            var totalActiveMillis = 0L
            for (segment in segments) {
                if (segment.segmentType != androidx.health.connect.client.records.ExerciseSegment.EXERCISE_SEGMENT_TYPE_PAUSE) {
                    totalActiveMillis += Duration.between(segment.startTime, segment.endTime).toMillis()
                }
            }
            if (totalActiveMillis > 0) activeDuration = Duration.ofMillis(totalActiveMillis)
        }
        var pace: Double? = null
        if (distanceMeters != null && distanceMeters > 0 && activeDuration.seconds > 0) {
            pace = activeDuration.seconds / (distanceMeters / 1000.0)
        }
        return Pair(activeDuration, pace)
    }
}

class FitnessDataPipeline {
    private val deduplicator = DeduplicationFilter()
    private val hrFilter = HeartRateSmoothingFilter()
    private val paceCalculator = PaceAndPauseCalculator()
    suspend fun processWorkouts(rawData: List<RawWorkoutData>): List<NormalizedWorkout> {
        val uniqueWorkouts = deduplicator.process(rawData)
        return coroutineScope {
            uniqueWorkouts.map { raw ->
                async { normalize(raw) }
            }.awaitAll().sortedBy { it.startTime }
        }
    }
    private fun normalize(raw: RawWorkoutData): NormalizedWorkout {
        val hrMetrics = hrFilter.process(raw.heartRateRecords)
        val paceMetrics = paceCalculator.process(raw.session, raw.totalDistanceMeters)
        return NormalizedWorkout(
            id = raw.session.metadata.id, sourceName = raw.session.metadata.dataOrigin.packageName,
            activityType = raw.session.exerciseType, startTime = raw.session.startTime, endTime = raw.session.endTime,
            elapsedDuration = Duration.between(raw.session.startTime, raw.session.endTime),
            activeDuration = paceMetrics.first, totalDistance = raw.totalDistanceMeters, averagePace = paceMetrics.second,
            maxHeartRate = hrMetrics.first, averageHeartRate = hrMetrics.second, heartRateSamples = hrMetrics.third
        )
    }
}
