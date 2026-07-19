package com.matteonoris.app4athletes

import androidx.annotation.NonNull
import androidx.health.connect.client.HealthConnectClient
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit

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
            val heartRate = readHeartRateSamples(session)
            val activeSeconds = activeDurationSeconds(session)
            val averageSpeedKmh = readAverageSpeedKmh(session)
            val elevationMeters = readElevationMeters(session)
            val stepCount = readStepCount(session)
            val averageCadenceSpm = if (activeSeconds > 0 && stepCount > 0) {
                stepCount / (activeSeconds / 60.0)
            } else {
                null
            }
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
                "avgSpeedKmh" to averageSpeedKmh,
                "elevationMeters" to elevationMeters,
                "avgCadenceSpm" to averageCadenceSpm,
                "importedLaps" to session.laps.map { lap ->
                    mapOf(
                        "startTime" to lap.startTime.toEpochMilli(),
                        "endTime" to lap.endTime.toEpochMilli(),
                        "durationSeconds" to Duration.between(lap.startTime, lap.endTime).seconds,
                        "distanceMeters" to lap.length?.inMeters
                    )
                },
                "segments" to session.segments.map { segment ->
                    mapOf(
                        "startTime" to segment.startTime.toEpochMilli(),
                        "endTime" to segment.endTime.toEpochMilli(),
                        "durationSeconds" to Duration.between(segment.startTime, segment.endTime).seconds,
                        "segmentType" to segment.segmentType,
                        "repetitions" to segment.repetitions
                    )
                },
                "hrSamples" to heartRate.samples.map { sample ->
                    mapOf(
                        "time" to sample.time.toEpochMilli(),
                        "bpm" to sample.bpm
                    )
                },
                "hrSourceId" to heartRate.sourcePackage,
                "hrSampleCount" to heartRate.samples.size,
                "hrMaxBpm" to heartRate.samples.maxOfOrNull { it.bpm }
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

    private suspend fun readAverageSpeedKmh(session: ExerciseSessionRecord): Double? {
        return try {
            val samples = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = SpeedRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
                )
            ).records
                .filter { it.metadata.dataOrigin.packageName == session.metadata.dataOrigin.packageName }
                .flatMap { it.samples }
                .filter { !it.time.isBefore(session.startTime) && !it.time.isAfter(session.endTime) }
            if (samples.isEmpty()) null else samples.map { it.speed.inMetersPerSecond }.average() * 3.6
        } catch (_: Exception) {
            null
        }
    }

    private suspend fun readElevationMeters(session: ExerciseSessionRecord): Double? {
        return try {
            val value = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = ElevationGainedRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
                )
            ).records
                .filter { it.metadata.dataOrigin.packageName == session.metadata.dataOrigin.packageName }
                .sumOf { it.elevation.inMeters }
            value.takeIf { it > 0 }
        } catch (_: Exception) {
            null
        }
    }

    private suspend fun readStepCount(session: ExerciseSessionRecord): Long {
        return try {
            healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
                )
            ).records
                .filter { it.metadata.dataOrigin.packageName == session.metadata.dataOrigin.packageName }
                .sumOf { it.count }
        } catch (_: Exception) {
            0
        }
    }

    private suspend fun readHeartRateSamples(session: ExerciseSessionRecord): HeartRateReadResult {
        val records = readAllHeartRateRecords(session)

        if (records.isEmpty()) return HeartRateReadResult(null, emptyList())

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

        if (samplesByPackage.isEmpty()) return HeartRateReadResult(null, emptyList())

        val selectedSource = selectHeartRateSource(
            samplesByPackage,
            sessionPackage
        )

        return HeartRateReadResult(
            sourcePackage = selectedSource.packageName,
            samples = selectedSource.samples
        )
    }

    private suspend fun readAllHeartRateRecords(
        session: ExerciseSessionRecord
    ): List<HeartRateRecord> {
        val records = mutableListOf<HeartRateRecord>()
        var pageToken: String? = null

        do {
            val response = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        session.startTime,
                        session.endTime
                    ),
                    pageToken = pageToken
                )
            )
            records.addAll(response.records)
            pageToken = response.pageToken
        } while (!pageToken.isNullOrEmpty())

        return records
    }

    private fun selectHeartRateSource(
        samplesByPackage: Map<String, List<HeartRateSamplePoint>>,
        sessionPackage: String
    ): HeartRateSourceStats {
        val stats = samplesByPackage.map { (packageName, samples) ->
            heartRateSourceStats(packageName, samples)
        }
        val sessionStats = stats.firstOrNull { it.packageName == sessionPackage }
        if (sessionStats != null) return sessionStats

        return stats.maxWithOrNull(
            compareBy<HeartRateSourceStats> { it.coverageSeconds }
                .thenBy { it.samples.size }
        ) ?: error("Heart-rate source selection requires at least one source")
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

data class HeartRateReadResult(
    val sourcePackage: String?,
    val samples: List<HeartRateSamplePoint>
)
