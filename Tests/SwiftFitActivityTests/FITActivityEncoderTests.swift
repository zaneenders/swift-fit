import Foundation
import SwiftFit
import SwiftFitActivity
import Testing

@Suite struct FITActivityEncoderTests {
  @Test func roundTripsEncodedActivity() throws {
    let fitEpoch = Date(timeIntervalSince1970: TimeInterval(fitEpochOffset))
    let startTimestamp = UInt32(fitEpoch.addingTimeInterval(120).timeIntervalSince1970) &- fitEpochOffset

    let original = FITActivitySummary(
      points: [
        FITTrackPoint(
          lat: 40.7608,
          lon: -111.8910,
          altitudeMeters: 1_300,
          heartRate: 140,
          speedMps: 5.0,
          distanceMeters: 100,
          timestamp: startTimestamp
        ),
        FITTrackPoint(
          lat: 40.7610,
          lon: -111.8900,
          altitudeMeters: 1_305,
          heartRate: 141,
          speedMps: 5.2,
          distanceMeters: 110,
          timestamp: startTimestamp &+ 1
        ),
      ],
      sport: .running,
      subSport: .treadmill,
      sessionDistanceMeters: 425
    )

    let bytes = try FITActivityEncoder.encode(original)
    let decoded = try FITActivityParser.parse(bytes: bytes)

    #expect(decoded.points.count == 2)
    #expect(decoded.sport == .running)
    #expect(decoded.subSport == .treadmill)
    #expect(abs((decoded.sessionDistanceMeters ?? 0) - 425) < 0.01)

    let first = try #require(decoded.points.first)
    #expect(first.timestamp == startTimestamp)
    #expect(abs((first.lat ?? 0) - 40.7608) < 0.0001)
    #expect(abs((first.lon ?? 0) - -111.8910) < 0.0001)
    #expect(abs((first.altitudeMeters ?? 0) - 1_300) < 0.1)
    #expect(first.heartRate == 140)
    #expect(abs((first.speedMps ?? 0) - 5.0) < 0.01)
    #expect(abs((first.distanceMeters ?? 0) - 100) < 0.01)
  }
}
