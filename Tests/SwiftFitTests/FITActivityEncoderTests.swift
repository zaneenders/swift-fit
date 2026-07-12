import Foundation
import Testing

@testable import SwiftFit

@Suite struct FITActivityEncoderTests {
  private let fitEpoch = Date(timeIntervalSince1970: TimeInterval(fitEpochOffset))

  @Test func encodesSampleOnlyActivity() throws {
    let start = fitEpoch.addingTimeInterval(60)
    var samples: [FITActivitySample] = []
    samples.reserveCapacity(5)
    for index in 0..<5 {
      samples.append(
        FITActivitySample(
          timestamp: start.addingTimeInterval(Double(index * 5)),
          heartRateBpm: UInt8(120 + index),
          distanceMeters: Double(index * 100),
          speedMps: 2.5 + Double(index) * 0.1
        ))
    }
    let end = samples.last!.timestamp

    let input = FITActivityInput(
      startDate: start,
      endDate: end,
      sport: .running,
      samples: samples,
      totalDistanceMeters: 400,
      totalEnergyKcal: 120
    )

    let bytes = FITActivityEncoder.encode(input)
    let fit = try FITFile(bytes: bytes)

    let records = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.record }
    #expect(records.count == 5)

    let sessions = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.session }
    #expect(sessions.count == 1)

    let activities = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.activity }
    #expect(activities.count == 1)

    let firstRecord = records[0]
    let timestampField = firstRecord.fields.first { $0.fieldDefinitionNumber == FITRecordField.timestamp }
    #expect(timestampField != nil)
    if case .uint32(let timestamp)? = timestampField?.values.first {
      #expect(timestamp == UInt32(start.timeIntervalSince1970) - fitEpochOffset)
    }

    let heartRateField = firstRecord.fields.first { $0.fieldDefinitionNumber == FITRecordField.heartRateAlt }
    if case .uint8(let hr)? = heartRateField?.values.first {
      #expect(hr == 120)
    }
  }

  @Test func encodesSparseWorkoutWithoutSamples() throws {
    let start = fitEpoch.addingTimeInterval(120)
    let end = start.addingTimeInterval(1_800)

    let input = FITActivityInput(
      startDate: start,
      endDate: end,
      sport: .cycling,
      subSport: .indoorCycling,
      samples: [],
      totalDistanceMeters: 15_000,
      totalEnergyKcal: 450
    )

    let bytes = FITActivityEncoder.encode(input)
    let fit = try FITFile(bytes: bytes)

    let records = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.record }
    #expect(records.count == 2)
    #expect(fit.fileCRCValid == true)
  }

  @Test func encodesGPSRouteWithCumulativeDistance() throws {
    let start = fitEpoch.addingTimeInterval(600)
    let samples = [
      FITActivitySample(
        timestamp: start,
        latitude: 40.7608,
        longitude: -111.8910,
        altitudeMeters: 1_300,
        heartRateBpm: 120,
        speedMps: 2.5
      ),
      FITActivitySample(
        timestamp: start.addingTimeInterval(10),
        latitude: 40.7610,
        longitude: -111.8900,
        altitudeMeters: 1_302,
        heartRateBpm: 125,
        speedMps: 2.6
      ),
      FITActivitySample(
        timestamp: start.addingTimeInterval(20),
        latitude: 40.7615,
        longitude: -111.8890,
        altitudeMeters: 1_304,
        heartRateBpm: 130,
        speedMps: 2.7
      ),
    ]

    let bytes = FITActivityEncoder.encode(
      FITActivityInput(
        startDate: start,
        endDate: start.addingTimeInterval(20),
        sport: .running,
        samples: samples,
        totalDistanceMeters: 2646
      ))

    let fit = try FITFile(bytes: bytes)
    let records = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.record }
    #expect(records.count == 3)

    let firstLat = records[0].fields.first { $0.fieldDefinitionNumber == FITRecordField.positionLat }
    if case .sint32(let raw)? = firstLat?.values.first {
      let semicircleScale = 180.0 / 2_147_483_648.0
      let lat = Double(raw) * semicircleScale
      #expect(abs(lat - 40.7608) < 0.0001)
    }

    let lastDistance = records[2].fields.first { $0.fieldDefinitionNumber == FITRecordField.distance }
    if case .uint32(let raw)? = lastDistance?.values.first {
      #expect(abs(Double(raw) / 100.0 - 2646.0) < 1.0)
    }
  }

  @Test func roundTripHeartRateAndDistance() throws {
    let start = fitEpoch.addingTimeInterval(300)
    let samples = [
      FITActivitySample(timestamp: start, heartRateBpm: 130, distanceMeters: 0, speedMps: 2.0),
      FITActivitySample(
        timestamp: start.addingTimeInterval(10),
        heartRateBpm: 140,
        distanceMeters: 25,
        speedMps: 2.5),
    ]

    let bytes = FITActivityEncoder.encode(
      FITActivityInput(
        startDate: start,
        endDate: start.addingTimeInterval(10),
        sport: .running,
        samples: samples,
        totalDistanceMeters: 25
      ))

    let fit = try FITFile(bytes: bytes)
    let records = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.record }
    #expect(records.count == 2)

    let lastDistance = records[1].fields.first { $0.fieldDefinitionNumber == FITRecordField.distance }
    if case .uint32(let raw)? = lastDistance?.values.first {
      #expect(abs(Double(raw) / 100.0 - 25.0) < 0.01)
    }
  }
}
