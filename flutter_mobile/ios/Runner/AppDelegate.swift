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
}
