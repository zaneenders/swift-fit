import Foundation
import SwiftFit
import SwiftFitActivity
import SwiftFitActivityFixtures
import Testing

@Suite struct FITActivityParserTests {
  @Test func parsesSampleActivityFile() throws {
    let bytes = try FITActivityFixtures.sampleRideBytes()
    let summary = try FITActivityParser.parse(bytes: bytes)

    #expect(summary.points.count == 4_270)
    #expect(summary.sessionDistanceMeters ?? 0 > 0)
    #expect(abs((summary.sessionDistanceMeters ?? 0) - 10_971.36) < 0.1)
    #expect(summary.sport == .cycling)
    #expect(summary.subSport == nil)
  }

  @Test func decodesRecordFieldsWithCorrectScaling() throws {
    let fitEpoch = Date(timeIntervalSince1970: TimeInterval(fitEpochOffset))
    let startTimestamp = UInt32(fitEpoch.addingTimeInterval(60).timeIntervalSince1970) &- fitEpochOffset

    var writer = FITWriter()
    let recordLocal = try writer.define(
      globalMessageNumber: FITGlobalMessage.record,
      fields: [
        (FITRecordField.timestamp, 4, .uint32),
        (FITRecordField.positionLat, 4, .sint32),
        (FITRecordField.positionLong, 4, .sint32),
        (FITRecordField.altitude, 2, .uint16),
        (FITRecordField.distance, 4, .uint32),
        (FITRecordField.enhancedSpeed, 4, .uint32),
        (FITRecordField.heartRateAlt, 1, .uint8),
      ])

    let semicirclesPerDegree = 2_147_483_648.0 / 180.0
    try writer.write(
      localType: recordLocal,
      values: [
        .uint32(startTimestamp),
        .sint32(Int32((40.7608 * semicirclesPerDegree).rounded())),
        .sint32(Int32((-111.8910 * semicirclesPerDegree).rounded())),
        .uint16(UInt16(((1_300.0 + 500.0) * 5.0).rounded())),
        .uint32(10_000),
        .uint32(5_000),
        .uint8(140),
      ])

    let summary = try FITActivityParser.parse(bytes: writer.finish())
    let point = try #require(summary.points.first)

    #expect(point.timestamp == startTimestamp)
    #expect(abs((point.lat ?? 0) - 40.7608) < 0.0001)
    #expect(abs((point.lon ?? 0) - -111.8910) < 0.0001)
    #expect(abs((point.altitudeMeters ?? 0) - 1_300.0) < 0.1)
    #expect(abs((point.distanceMeters ?? 0) - 100.0) < 0.01)
    #expect(abs((point.speedMps ?? 0) - 5.0) < 0.01)
    #expect(point.heartRate == 140)
  }

  @Test func decodesSessionSportAndDistance() throws {
    var writer = FITWriter()
    let sessionLocal = try writer.define(
      globalMessageNumber: FITGlobalMessage.session,
      fields: [
        (FITSessionField.sport, 1, .enumType),
        (FITSessionField.subSport, 1, .enumType),
        (FITSessionField.totalDistance, 4, .uint32),
      ])
    try writer.write(
      localType: sessionLocal,
      values: [
        .enumType(FITSport.running.rawValue),
        .enumType(FITSubSport.treadmill.rawValue),
        .uint32(42_500),
      ])

    let summary = try FITActivityParser.parse(bytes: writer.finish())

    #expect(summary.sport == .running)
    #expect(summary.subSport == .treadmill)
    #expect(abs((summary.sessionDistanceMeters ?? 0) - 425.0) < 0.01)
  }
}
