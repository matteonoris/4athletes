import Flutter
import UIKit
import XCTest
import HealthKit
@testable import Runner

class RunnerTests: XCTestCase {

  func testWorkoutDistanceFallbackUsesTheActivityMetric() {
    XCTAssertEqual(AppDelegate.distanceIdentifier(for: .running), .distanceWalkingRunning)
    XCTAssertEqual(AppDelegate.distanceIdentifier(for: .hiking), .distanceWalkingRunning)
    XCTAssertEqual(AppDelegate.distanceIdentifier(for: .cycling), .distanceCycling)
    XCTAssertEqual(AppDelegate.distanceIdentifier(for: .swimming), .distanceSwimming)
    XCTAssertNil(AppDelegate.distanceIdentifier(for: .downhillSkiing))
    XCTAssertNil(AppDelegate.distanceIdentifier(for: .traditionalStrengthTraining))
  }

}
