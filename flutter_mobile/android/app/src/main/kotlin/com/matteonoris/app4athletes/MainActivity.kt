package com.matteonoris.app4athletes

import androidx.annotation.NonNull
import androidx.health.connect.client.HealthConnectClient
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit
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
                        val days = call.argument<Int>("days") ?: 7
                        val workouts = withContext(Dispatchers.IO) {
                            HealthConnectWorkoutReader(
                                HealthConnectClient.getOrCreate(applicationContext)
                            ).readRecentWorkouts(days)
                        }
                        result.success(workouts)
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

class HealthConnectWorkoutReader(
    private val healthConnectClient: HealthConnectClient
) {
    suspend fun readRecentWorkouts(days: Int): List<Map<String, Any?>> {
        val endTime = Instant.now()
        val startTime = endTime.minus(days.toLong(), ChronoUnit.DAYS)
        val sessions = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
            )
        ).records

        return sessions.mapNotNull { session ->
            val distanceMeters = readDistanceMeters(session)
            val energyKcal = readEnergyKcal(session)
            val heartRateSamples = readHeartRateSamples(session)
            val activeSeconds = activeDurationSeconds(session)
            mapOf<String, Any?>(
                "id" to session.metadata.id,
                "sourceName" to session.metadata.dataOrigin.packageName,
                "sourceId" to session.metadata.dataOrigin.packageName,
                "activityType" to activityTypeName(session.exerciseType),
                "startTime" to session.startTime.toEpochMilli(),
                "endTime" to session.endTime.toEpochMilli(),
                "totalDurationSeconds" to Duration.between(session.startTime, session.endTime).seconds,
                "activeDurationSeconds" to activeSeconds,
                "movingDurationSeconds" to activeSeconds,
                "distanceMeters" to distanceMeters,
                "energyTotalKcal" to energyKcal,
                "hrSamples" to heartRateSamples
            )
        }
    }

    private suspend fun readDistanceMeters(session: ExerciseSessionRecord): Double {
        return healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = DistanceRecord::class,
                timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
            )
        ).records
            .filter { it.metadata.dataOrigin.packageName == session.metadata.dataOrigin.packageName }
            .sumOf { it.distance.inMeters }
    }

    private suspend fun readEnergyKcal(session: ExerciseSessionRecord): Double {
        return healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = TotalCaloriesBurnedRecord::class,
                timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
            )
        ).records
            .filter { it.metadata.dataOrigin.packageName == session.metadata.dataOrigin.packageName }
            .sumOf { it.energy.inKilocalories }
    }

    private suspend fun readHeartRateSamples(session: ExerciseSessionRecord): List<Map<String, Any>> {
        val records = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
            )
        ).records

        if (records.isEmpty()) return emptyList()

        val sessionPackage = session.metadata.dataOrigin.packageName
        val samplesByPackage = records
            .flatMap { record ->
                record.samples
                    .filter { sample ->
                        !sample.time.isBefore(session.startTime) &&
                            !sample.time.isAfter(session.endTime)
                    }
                    .map { sample ->
                        HeartRateSamplePoint(
                            time = sample.time,
                            bpm = sample.beatsPerMinute,
                            sourcePackage = record.metadata.dataOrigin.packageName
                        )
                    }
            }
            .groupBy { it.sourcePackage }

        if (samplesByPackage.isEmpty()) return emptyList()

        val selectedSamples = selectHeartRateSourceSamples(
            samplesByPackage,
            sessionPackage
        )

        return selectedSamples
            .map { sample ->
                mapOf(
                    "time" to sample.time.toEpochMilli(),
                    "bpm" to sample.bpm
                )
            }
            .sortedBy { it["time"] as Long }
    }

    private fun selectHeartRateSourceSamples(
        samplesByPackage: Map<String, List<HeartRateSamplePoint>>,
        sessionPackage: String
    ): List<HeartRateSamplePoint> {
        val stats = samplesByPackage.map { (packageName, samples) ->
            heartRateSourceStats(packageName, samples)
        }
        val best = stats.maxWithOrNull(
            compareBy<HeartRateSourceStats> { it.coverageSeconds }
                .thenBy { it.samples.size }
        ) ?: return emptyList()
        val sessionStats = stats.firstOrNull { it.packageName == sessionPackage }

        if (sessionStats != null) {
            if (sessionStats.samples.size >= best.samples.size * 0.80) {
                return sessionStats.samples
            }
            if (
                sessionStats.coverageSeconds >= best.coverageSeconds * 0.95 &&
                sessionStats.samples.size >= best.samples.size * 0.50
            ) {
                return sessionStats.samples
            }
        }

        return best.samples
    }

    private fun heartRateSourceStats(
        packageName: String,
        samples: List<HeartRateSamplePoint>
    ): HeartRateSourceStats {
        val sortedSamples = samples.sortedBy { it.time }
        var coverageSeconds = 0L
        for (i in 0 until sortedSamples.size - 1) {
            val gap = Duration.between(sortedSamples[i].time, sortedSamples[i + 1].time).seconds
            if (gap > 0 && gap <= 300) {
                coverageSeconds += gap
            }
        }
        return HeartRateSourceStats(packageName, sortedSamples, coverageSeconds)
    }

    private fun activeDurationSeconds(session: ExerciseSessionRecord): Long {
        if (session.segments.isEmpty()) {
            return Duration.between(session.startTime, session.endTime).seconds
        }

        val activeMillis = session.segments
            .filter { it.segmentType != ExerciseSegment.EXERCISE_SEGMENT_TYPE_PAUSE }
            .sumOf { Duration.between(it.startTime, it.endTime).toMillis() }

        return if (activeMillis > 0) {
            Duration.ofMillis(activeMillis).seconds
        } else {
            Duration.between(session.startTime, session.endTime).seconds
        }
    }

    private fun activityTypeName(type: Int): String {
        return when (type) {
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> "RUNNING"
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "RUNNING_TREADMILL"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> "BIKING"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "BIKING_STATIONARY"
            ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "WALKING"
            ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> "HIKING"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER -> "SWIMMING_OPEN_WATER"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> "SWIMMING_POOL"
            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING -> "STRENGTH_TRAINING"
            ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> "WEIGHTLIFTING"
            ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING -> "HIGH_INTENSITY_INTERVAL_TRAINING"
            ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "YOGA"
            ExerciseSessionRecord.EXERCISE_TYPE_SKIING -> "SKIING"
            ExerciseSessionRecord.EXERCISE_TYPE_SNOWBOARDING -> "SNOWBOARDING"
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING -> "ROWING"
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE -> "ROWING_MACHINE"
            ExerciseSessionRecord.EXERCISE_TYPE_SOCCER -> "SOCCER"
            ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL -> "BASKETBALL"
            ExerciseSessionRecord.EXERCISE_TYPE_TENNIS -> "TENNIS"
            else -> "OTHER"
        }
    }
}

data class HeartRateSamplePoint(
    val time: Instant,
    val bpm: Long,
    val sourcePackage: String
)

data class HeartRateSourceStats(
    val packageName: String,
    val samples: List<HeartRateSamplePoint>,
    val coverageSeconds: Long
)

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
