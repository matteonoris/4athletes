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
      var readTypes: Set<HKObjectType> = [workoutType, hrType]
      for identifier in [
          HKQuantityTypeIdentifier.distanceWalkingRunning,
          HKQuantityTypeIdentifier.activeEnergyBurned,
          HKQuantityTypeIdentifier.stepCount,
          HKQuantityTypeIdentifier.flightsClimbed
      ] {
          if let type = HKObjectType.quantityType(forIdentifier: identifier) {
              readTypes.insert(type)
          }
      }
      if #available(iOS 16.0, *),
         let runningSpeedType = HKObjectType.quantityType(forIdentifier: .runningSpeed) {
          readTypes.insert(runningSpeedType)
      }
      
      healthStore.requestAuthorization(toShare: nil, read: readTypes) { (success, error) in
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
                      self.fetchWorkoutMetrics(for: workout) { importedMetrics in
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
                          importedMetrics.forEach { item[$0.key] = $0.value }

                          let workoutEvents = workout.workoutEvents ?? []
                          item["importedLaps"] = workoutEvents
                              .filter { $0.type == .lap }
                              .map { self.serializeWorkoutEvent($0) }
                          item["segments"] = workoutEvents.map {
                              self.serializeWorkoutEvent($0)
                          }

                          lock.lock()
                          jsonList.append(item)
                          lock.unlock()
                          group.leave()
                      }
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

  private func fetchWorkoutMetrics(
      for workout: HKWorkout,
      completion: @escaping ([String: Any]) -> Void
  ) {
      let group = DispatchGroup()
      let lock = NSLock()
      var metrics: [String: Any] = [:]

      func store(_ key: String, _ value: Double?) {
          guard let value = value, value > 0 else { return }
          lock.lock()
          metrics[key] = value
          lock.unlock()
      }

      if workout.totalDistance == nil,
         let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
          group.enter()
          fetchQuantitySamples(for: workout, type: distanceType) { samples in
              store("distanceMeters", samples.reduce(0) {
                  $0 + $1.quantity.doubleValue(for: .meter())
              })
              group.leave()
          }
      }

      if workout.totalEnergyBurned == nil,
         let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
          group.enter()
          fetchQuantitySamples(for: workout, type: energyType) { samples in
              store("energyTotalKcal", samples.reduce(0) {
                  $0 + $1.quantity.doubleValue(for: .kilocalorie())
              })
              group.leave()
          }
      }

      if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
          group.enter()
          fetchQuantitySamples(for: workout, type: stepsType) { samples in
              let steps = samples.reduce(0) {
                  $0 + $1.quantity.doubleValue(for: .count())
              }
              if workout.duration > 0 && steps > 0 {
                  store("avgCadenceSpm", steps / (workout.duration / 60.0))
              }
              group.leave()
          }
      }

      if let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
          group.enter()
          fetchQuantitySamples(for: workout, type: flightsType) { samples in
              let flights = samples.reduce(0) {
                  $0 + $1.quantity.doubleValue(for: .count())
              }
              // HealthKit does not expose workout elevation on every source.
              // Keep the estimate explicit and omit it when no flights exist.
              store("elevationMeters", flights > 0 ? flights * 3.0 : nil)
              group.leave()
          }
      }

      if #available(iOS 16.0, *),
         let speedType = HKObjectType.quantityType(forIdentifier: .runningSpeed) {
          group.enter()
          fetchQuantitySamples(for: workout, type: speedType) { samples in
              let values = samples.map {
                  $0.quantity.doubleValue(for: .meter().unitDivided(by: .second()))
              }.filter { $0 > 0 }
              let averageMetersPerSecond = values.isEmpty
                  ? nil
                  : values.reduce(0, +) / Double(values.count)
              store("avgSpeedKmh", averageMetersPerSecond.map { $0 * 3.6 })
              group.leave()
          }
      }

      group.notify(queue: .global(qos: .userInitiated)) {
          lock.lock()
          let result = metrics
          lock.unlock()
          completion(result)
      }
  }

  private func fetchQuantitySamples(
      for workout: HKWorkout,
      type: HKQuantityType,
      completion: @escaping ([HKQuantitySample]) -> Void
  ) {
      let sortDescriptor = NSSortDescriptor(
          key: HKSampleSortIdentifierStartDate,
          ascending: true
      )
      let associatedPredicate = HKQuery.predicateForObjects(from: workout)
      let associatedQuery = HKSampleQuery(
          sampleType: type,
          predicate: associatedPredicate,
          limit: HKObjectQueryNoLimit,
          sortDescriptors: [sortDescriptor]
      ) { (_, samples, _) in
          let associated = samples as? [HKQuantitySample] ?? []
          if !associated.isEmpty {
              completion(self.selectQuantitySourceSamples(associated, for: workout))
              return
          }

          let timePredicate = HKQuery.predicateForSamples(
              withStart: workout.startDate,
              end: workout.endDate,
              options: [.strictStartDate]
          )
          let fallbackQuery = HKSampleQuery(
              sampleType: type,
              predicate: timePredicate,
              limit: HKObjectQueryNoLimit,
              sortDescriptors: [sortDescriptor]
          ) { (_, fallbackSamples, _) in
              let samples = fallbackSamples as? [HKQuantitySample] ?? []
              completion(self.selectQuantitySourceSamples(samples, for: workout))
          }
          self.healthStore.execute(fallbackQuery)
      }
      healthStore.execute(associatedQuery)
  }

  private func selectQuantitySourceSamples(
      _ samples: [HKQuantitySample],
      for workout: HKWorkout
  ) -> [HKQuantitySample] {
      guard !samples.isEmpty else { return [] }
      let grouped = Dictionary(grouping: samples) {
          $0.sourceRevision.source.bundleIdentifier
      }
      let preferred = workout.sourceRevision.source.bundleIdentifier
      if let exact = grouped[preferred], !exact.isEmpty { return exact }
      return grouped.values.max { $0.count < $1.count } ?? []
  }

  private func serializeWorkoutEvent(_ event: HKWorkoutEvent) -> [String: Any] {
      [
          "type": event.type == .lap ? "lap" : "event",
          "eventType": event.type.rawValue,
          "startTime": event.dateInterval.start.timeIntervalSince1970 * 1000,
          "endTime": event.dateInterval.end.timeIntervalSince1970 * 1000,
          "durationSeconds": event.dateInterval.duration
      ]
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
          let preferredBundleIdentifier = workout.sourceRevision.source.bundleIdentifier
          let selectedAssociatedSamples = self.selectHeartRateSourceSamples(
              associatedSamples,
              preferredBundleIdentifier: preferredBundleIdentifier
          )
          if selectedAssociatedSamples.count >= 5 {
              completion(serialize(selectedAssociatedSamples))
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

              let selected = self.selectHeartRateSourceSamples(
                  windowSamples,
                  preferredBundleIdentifier: preferredBundleIdentifier
              )
              completion(serialize(selected))
          }
          self.healthStore.execute(fallbackQuery)
      }
      healthStore.execute(query)
  }

  private func selectHeartRateSourceSamples(
      _ samples: [HKQuantitySample],
      preferredBundleIdentifier: String
  ) -> [HKQuantitySample] {
      guard !samples.isEmpty else { return [] }

      let grouped = Dictionary(grouping: samples) { sample in
          sample.sourceRevision.source.bundleIdentifier
      }
      guard let bestEntry = grouped.max(by: { lhs, rhs in
          let lhsCoverage = self.heartRateCoverageSeconds(lhs.value)
          let rhsCoverage = self.heartRateCoverageSeconds(rhs.value)
          if lhsCoverage != rhsCoverage {
              return lhsCoverage < rhsCoverage
          }
          return lhs.value.count < rhs.value.count
      }) else {
          return []
      }

      let bestSamples = bestEntry.value
      guard let preferredSamples = grouped[preferredBundleIdentifier] else {
          return bestSamples
      }

      let bestCoverage = heartRateCoverageSeconds(bestSamples)
      let preferredCoverage = heartRateCoverageSeconds(preferredSamples)
      if Double(preferredSamples.count) >= Double(bestSamples.count) * 0.80 {
          return preferredSamples
      }
      if preferredCoverage >= bestCoverage * 0.95 &&
          Double(preferredSamples.count) >= Double(bestSamples.count) * 0.50 {
          return preferredSamples
      }
      return bestSamples
  }

  private func heartRateCoverageSeconds(
      _ samples: [HKQuantitySample]
  ) -> TimeInterval {
      let ordered = samples.sorted { $0.startDate < $1.startDate }
      guard ordered.count > 1 else { return 0 }

      var coverage: TimeInterval = 0
      for index in 0..<(ordered.count - 1) {
          let gap = ordered[index + 1].startDate.timeIntervalSince(ordered[index].startDate)
          if gap > 0 && gap <= 300 {
              coverage += gap
          }
      }
      return coverage
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
      case .coreTraining:
          return "CORE_TRAINING"
      case .crossTraining:
          return "CROSS_TRAINING"
      case .mixedCardio:
          return "MIXED_CARDIO"
      case .yoga:
          return "YOGA"
      case .pilates:
          return "PILATES"
      case .flexibility:
          return "FLEXIBILITY"
      case .mindAndBody:
          return "MIND_AND_BODY"
      case .elliptical:
          return "ELLIPTICAL"
      case .stairClimbing:
          return "STAIR_CLIMBING"
      case .stairs:
          return "STAIRS"
      case .stepTraining:
          return "STEP_TRAINING"
      case .preparationAndRecovery:
          return "PREPARATION_AND_RECOVERY"
      case .downhillSkiing:
          return "DOWNHILL_SKIING"
      case .snowSports:
          return "SNOW_SPORTS"
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
      case .martialArts:
          return "MARTIAL_ARTS"
      case .kickboxing:
          return "KICKBOXING"
      default:
          return "HKWORKOUT_\(type.rawValue)"
      }
  }
}
