import Flutter
import UIKit

import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  
  let healthStore = HKHealthStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    if let flutterViewController = window?.rootViewController as? FlutterViewController {
        let healthChannel = FlutterMethodChannel(name: "com.4athletes.health/hrv",
                                              binaryMessenger: flutterViewController.binaryMessenger)
        
        healthChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            if call.method == "getRRIntervals" {
                self.fetchRRIntervals(result: result)
            } else if call.method == "getNormalizedWorkouts" {
                self.fetchNormalizedWorkouts(call: call, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        })
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
  
  private func fetchRRIntervals(result: @escaping FlutterResult) {
      guard HKHealthStore.isHealthDataAvailable() else {
          result(FlutterError(code: "UNAVAILABLE", message: "HealthKit non disponibile", details: nil))
          return
      }
      
      guard let heartbeatType = HKObjectType.seriesType(forIdentifier: HKDataTypeIdentifierHeartbeatSeries) else {
          result(FlutterError(code: "UNSUPPORTED", message: "Heartbeat Series non supportato", details: nil))
          return
      }
      
      healthStore.requestAuthorization(toShare: nil, read: [heartbeatType]) { (success, error) in
          if !success {
              result(FlutterError(code: "UNAUTHORIZED", message: "Permesso negato", details: nil))
              return
          }
          
          let calendar = Calendar.current
          var components = calendar.dateComponents([.year, .month, .day], from: Date())
          components.hour = 0
          components.minute = 0
          components.second = 0
          guard let midnight = calendar.date(from: components) else {
              result([])
              return
          }
          let eightAM = calendar.date(byAdding: .hour, value: 8, to: midnight)!
          
          let predicate = HKQuery.predicateForSamples(withStart: midnight, end: eightAM, options: .strictStartDate)
          let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
          
          let query = HKSampleQuery(sampleType: heartbeatType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
              
              guard let seriesSample = samples?.first as? HKHeartbeatSeriesSample else {
                  result([])
                  return
              }
              
              var rrIntervals: [Double] = []
              var lastBeatTime: TimeInterval? = nil
              
              let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: seriesSample) { (query, timeSinceSeriesStart, precededByGap, done, error) in
                  
                  if !precededByGap {
                      if let last = lastBeatTime {
                          let rr = (timeSinceSeriesStart - last) * 1000.0 // ms
                          rrIntervals.append(rr)
                      }
                  }
                  lastBeatTime = timeSinceSeriesStart
                  
                  if done {
                      result(rrIntervals)
                  }
              }
              self.healthStore.execute(seriesQuery)
          }
          self.healthStore.execute(query)
      }
  }
  
  private func fetchNormalizedWorkouts(call: FlutterMethodCall, result: @escaping FlutterResult) {
      guard HKHealthStore.isHealthDataAvailable() else {
          result(FlutterError(code: "UNAVAILABLE", message: "HealthKit non disponibile", details: nil))
          return
      }
      
      let workoutType = HKObjectType.workoutType()
      let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
      
      healthStore.requestAuthorization(toShare: nil, read: [workoutType, hrType]) { (success, error) in
          if !success {
              result(FlutterError(code: "UNAUTHORIZED", message: "Permesso negato", details: nil))
              return
          }
          
          let args = call.arguments as? [String: Any]
          let days = args?["days"] as? Int ?? 7
          let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
          let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
          
          let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
          let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in

              guard let workouts = samples as? [HKWorkout] else {
                  result([])
                  return
              }

              let group = DispatchGroup()
              var jsonList = [[String: Any]]()
              let lock = NSLock()

              for workout in workouts {
                  group.enter()
                  self.fetchHeartRateSamples(for: workout, hrType: hrType) { hrSamples in
                      var item: [String: Any] = [
                          "id": workout.uuid.uuidString,
                          "sourceName": workout.sourceRevision.source.name,
                          "sourceId": workout.sourceRevision.source.bundleIdentifier,
                          "activityType": self.activityTypeName(workout.workoutActivityType),
                          "startTime": workout.startDate.timeIntervalSince1970 * 1000,
                          "endTime": workout.endDate.timeIntervalSince1970 * 1000,
                          "totalDurationSeconds": workout.endDate.timeIntervalSince(workout.startDate),
                          "activeDurationSeconds": workout.duration,
                          "movingDurationSeconds": workout.duration,
                          "hrSamples": hrSamples
                      ]
                      if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                          item["distanceMeters"] = distance
                      }
                      if let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                          item["energyTotalKcal"] = energy
                      }

                      lock.lock()
                      jsonList.append(item)
                      lock.unlock()
                      group.leave()
                  }
              }

              group.notify(queue: .main) {
                  result(jsonList.sorted {
                      ($0["startTime"] as? Double ?? 0) < ($1["startTime"] as? Double ?? 0)
                  })
              }
          }
          self.healthStore.execute(query)
      }
  }

  private func fetchHeartRateSamples(
      for workout: HKWorkout,
      hrType: HKQuantityType,
      completion: @escaping ([[String: Any]]) -> Void
  ) {
      let bpmUnit = HKUnit.count().unitDivided(by: .minute())
      func serialize(_ samples: [HKQuantitySample]) -> [[String: Any]] {
          return samples.sorted { $0.startDate < $1.startDate }.map { sample -> [String: Any] in
              [
                  "time": sample.startDate.timeIntervalSince1970 * 1000,
                  "bpm": sample.quantity.doubleValue(for: bpmUnit)
              ]
          }
      }

      let workoutPredicate = HKQuery.predicateForObjects(from: workout)
      let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
      let query = HKSampleQuery(sampleType: hrType, predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (_, samples, _) in
          let associatedSamples = samples as? [HKQuantitySample] ?? []
          if associatedSamples.count >= 5 {
              completion(serialize(associatedSamples))
              return
          }

          let timePredicate = HKQuery.predicateForSamples(
              withStart: workout.startDate,
              end: workout.endDate,
              options: [.strictStartDate]
          )
          let fallbackQuery = HKSampleQuery(sampleType: hrType, predicate: timePredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (_, fallbackSamples, _) in
              let windowSamples = fallbackSamples as? [HKQuantitySample] ?? []
              guard !windowSamples.isEmpty else {
                  completion(serialize(associatedSamples))
                  return
              }

              let grouped = Dictionary(grouping: windowSamples) { sample in
                  sample.sourceRevision.source.bundleIdentifier
              }
              let selected = grouped.max { lhs, rhs in
                  lhs.value.count < rhs.value.count
              }?.value ?? windowSamples
              completion(serialize(selected))
          }
          self.healthStore.execute(fallbackQuery)
      }
      healthStore.execute(query)
  }

  private func activityTypeName(_ type: HKWorkoutActivityType) -> String {
      switch type {
      case .running:
          return "RUNNING"
      case .cycling:
          return "BIKING"
      case .walking:
          return "WALKING"
      case .hiking:
          return "HIKING"
      case .swimming:
          return "SWIMMING"
      case .traditionalStrengthTraining:
          return "TRADITIONAL_STRENGTH_TRAINING"
      case .functionalStrengthTraining:
          return "FUNCTIONAL_STRENGTH_TRAINING"
      case .highIntensityIntervalTraining:
          return "HIGH_INTENSITY_INTERVAL_TRAINING"
      case .yoga:
          return "YOGA"
      case .downhillSkiing:
          return "DOWNHILL_SKIING"
      case .crossCountrySkiing:
          return "CROSS_COUNTRY_SKIING"
      case .snowboarding:
          return "SNOWBOARDING"
      case .rowing:
          return "ROWING"
      case .soccer:
          return "SOCCER"
      case .basketball:
          return "BASKETBALL"
      case .tennis:
          return "TENNIS"
      default:
          return "OTHER"
      }
  }
}

// MARK: - Pipeline Code
struct NormalizedWorkout {
    let id: UUID
    let sourceName: String
    let activityType: HKWorkoutActivityType
    let startTime: Date
    let endTime: Date
    let elapsedDuration: TimeInterval
    let activeDuration: TimeInterval
    let totalDistance: Double?
    let averagePace: Double?
    let maxHeartRate: Double?
    let averageHeartRate: Double?
    let heartRateSamples: [HeartRateSample]
}

struct HeartRateSample {
    let date: Date
    let value: Double
}

struct RawWorkoutData {
    let workout: HKWorkout
    let heartRateSamples: [HKQuantitySample]
    let events: [HKWorkoutEvent]
}

class DeduplicationFilter {
    private let sourcePriority: [String: Int] = [
        "Apple Watch": 1, "Garmin": 2, "Polar": 3, "Coros": 4, "Strava": 10, "Nike Run Club": 11
    ]
    func process(_ workouts: [RawWorkoutData]) -> [RawWorkoutData] {
        let sorted = workouts.sorted { $0.workout.startDate < $1.workout.startDate }
        var resolved: [RawWorkoutData] = []
        for current in sorted {
            if let overlapIndex = resolved.firstIndex(where: { overlaps($0.workout, current.workout) }) {
                if priority(for: current) < priority(for: resolved[overlapIndex]) {
                    resolved[overlapIndex] = current
                }
            } else { resolved.append(current) }
        }
        return resolved
    }
    private func overlaps(_ w1: HKWorkout, _ w2: HKWorkout) -> Bool {
        return w1.startDate < w2.endDate && w2.startDate < w1.endDate
    }
    private func priority(for data: RawWorkoutData) -> Int {
        let name = data.workout.sourceRevision.source.name
        return sourcePriority.first { name.localizedCaseInsensitiveContains($0.key) }?.value ?? 100
    }
}

class HeartRateSmoothingFilter {
    func process(_ samples: [HKQuantitySample]) -> (max: Double?, avg: Double?, filtered: [HeartRateSample]) {
        guard !samples.isEmpty else { return (nil, nil, []) }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let rawValues = samples.map { $0.quantity.doubleValue(for: bpmUnit) }
        var filteredSamples: [HeartRateSample] = []
        var validValues: [Double] = []
        for i in 0..<samples.count {
            let start = max(0, i - 2)
            let end = min(samples.count - 1, i + 2)
            let window = rawValues[start...end]
            let mean = window.reduce(0, +) / Double(window.count)
            let variance = window.map { pow($0 - mean, 2) }.reduce(0, +) / Double(window.count)
            let stdDev = sqrt(variance)
            let maxAllowed = max(2 * stdDev, 10.0)
            if abs(rawValues[i] - mean) <= maxAllowed {
                filteredSamples.append(HeartRateSample(date: samples[i].startDate, value: rawValues[i]))
                validValues.append(rawValues[i])
            }
        }
        let maxHR = validValues.max()
        let avgHR = validValues.isEmpty ? nil : validValues.reduce(0, +) / Double(validValues.count)
        return (maxHR, avgHR, filteredSamples)
    }
}

class PaceAndPauseCalculator {
    func process(workout: HKWorkout, events: [HKWorkoutEvent], totalDistanceMeters: Double?) -> (activeDuration: TimeInterval, pace: Double?) {
        var pauseDuration: TimeInterval = 0
        var currentPauseStart: Date? = nil
        let sortedEvents = events.sorted { $0.dateInterval.start < $1.dateInterval.start }
        for event in sortedEvents {
            if event.type == .pause { currentPauseStart = event.dateInterval.start }
            else if event.type == .resume {
                if let start = currentPauseStart { pauseDuration += event.dateInterval.start.timeIntervalSince(start); currentPauseStart = nil }
            }
        }
        if let start = currentPauseStart { pauseDuration += workout.endDate.timeIntervalSince(start) }
        let activeDuration = max(workout.endDate.timeIntervalSince(workout.startDate) - pauseDuration, 0)
        var pace: Double? = nil
        if let distance = totalDistanceMeters, distance > 0, activeDuration > 0 {
            pace = activeDuration / (distance / 1000.0)
        }
        return (activeDuration, pace)
    }
}

actor FitnessDataPipeline {
    private let deduplicator = DeduplicationFilter()
    private let hrFilter = HeartRateSmoothingFilter()
    private let paceCalculator = PaceAndPauseCalculator()
    func processWorkouts(_ rawData: [RawWorkoutData]) async throws -> [NormalizedWorkout] {
        let uniqueWorkouts = deduplicator.process(rawData)
        return try await withThrowingTaskGroup(of: NormalizedWorkout.self) { group in
            var results: [NormalizedWorkout] = []
            for raw in uniqueWorkouts { group.addTask { return self.normalize(raw) } }
            for try await result in group { results.append(result) }
            return results.sorted { $0.startTime < $1.startTime }
        }
    }
    private nonisolated func normalize(_ raw: RawWorkoutData) -> NormalizedWorkout {
        let hrMetrics = hrFilter.process(raw.heartRateSamples)
        let dist = raw.workout.totalDistance?.doubleValue(for: .meter())
        let paceMetrics = paceCalculator.process(workout: raw.workout, events: raw.events, totalDistanceMeters: dist)
        return NormalizedWorkout(
            id: raw.workout.uuid, sourceName: raw.workout.sourceRevision.source.name, activityType: raw.workout.workoutActivityType,
            startTime: raw.workout.startDate, endTime: raw.workout.endDate, elapsedDuration: raw.workout.endDate.timeIntervalSince(raw.workout.startDate),
            activeDuration: paceMetrics.activeDuration, totalDistance: dist, averagePace: paceMetrics.pace,
            maxHeartRate: hrMetrics.max, averageHeartRate: hrMetrics.avg, heartRateSamples: hrMetrics.filtered
        )
    }
}
