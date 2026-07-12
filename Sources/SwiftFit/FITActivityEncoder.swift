#if canImport(Foundation)
import Foundation

public struct FITActivitySample: Sendable {
  public let timestamp: Date
  public var heartRateBpm: UInt8?
  public var distanceMeters: Double?
  public var speedMps: Double?
  public var cadenceRpm: UInt8?
  public var powerWatts: UInt16?

  public init(
    timestamp: Date,
    heartRateBpm: UInt8? = nil,
    distanceMeters: Double? = nil,
    speedMps: Double? = nil,
    cadenceRpm: UInt8? = nil,
    powerWatts: UInt16? = nil
  ) {
    self.timestamp = timestamp
    self.heartRateBpm = heartRateBpm
    self.distanceMeters = distanceMeters
    self.speedMps = speedMps
    self.cadenceRpm = cadenceRpm
    self.powerWatts = powerWatts
  }
}

public struct FITActivityInput: Sendable {
  public let startDate: Date
  public let endDate: Date
  public let sport: FITSport
  public let subSport: FITSubSport
  public let samples: [FITActivitySample]
  public let totalDistanceMeters: Double?
  public let totalEnergyKcal: Double?

  public init(
    startDate: Date,
    endDate: Date,
    sport: FITSport,
    subSport: FITSubSport = .generic,
    samples: [FITActivitySample],
    totalDistanceMeters: Double? = nil,
    totalEnergyKcal: Double? = nil
  ) {
    self.startDate = startDate
    self.endDate = endDate
    self.sport = sport
    self.subSport = subSport
    self.samples = samples
    self.totalDistanceMeters = totalDistanceMeters
    self.totalEnergyKcal = totalEnergyKcal
  }
}

public enum FITActivityEncoder {
  public static func encode(_ input: FITActivityInput) -> [UInt8] {
    var writer = FITWriter()

    let startTimestamp = fitTimestamp(input.startDate)
    let endTimestamp = fitTimestamp(input.endDate)
    let elapsed = max(0, Double(endTimestamp &- startTimestamp))

    let sortedSamples = input.samples.sorted { $0.timestamp < $1.timestamp }
    let recordSamples = sortedSamples.isEmpty
      ? [
        FITActivitySample(timestamp: input.startDate),
        FITActivitySample(timestamp: input.endDate),
      ]
      : sortedSamples

    let heartRates = recordSamples.compactMap(\.heartRateBpm)
    let avgHeartRate = averageHeartRate(from: heartRates)
    let maxHeartRate = heartRates.max()

    let totalDistance = input.totalDistanceMeters
      ?? recordSamples.compactMap(\.distanceMeters).last
      ?? 0

    // file_id
    let fileIDLocal = writer.define(
      globalMessageNumber: FITGlobalMessage.fileID,
      fields: [
        (0, 1, .enumType),
        (1, 2, .uint16),
        (2, 2, .uint16),
        (3, 4, .uint32),
        (4, 4, .uint32),
      ])
    writer.write(
      localType: fileIDLocal,
      values: [
        .enumType(FITFileType.activity.rawValue),
        .uint16(FITManufacturer.development.rawValue),
        .uint16(0),
        .uint32(1),
        .uint32(startTimestamp),
      ])

    // timer start
    let eventLocal = writer.define(
      globalMessageNumber: FITGlobalMessage.event,
      fields: [
        (253, 4, .uint32),
        (0, 1, .enumType),
        (1, 1, .enumType),
      ])
    writer.write(
      localType: eventLocal,
      values: [
        .uint32(startTimestamp),
        .enumType(FITEvent.timer.rawValue),
        .enumType(FITEventType.start.rawValue),
      ])

    // records (no GPS fields)
    let recordLocal = writer.define(
      globalMessageNumber: FITGlobalMessage.record,
      fields: [
        (FITRecordField.timestamp, 4, .uint32),
        (FITRecordField.distance, 4, .uint32),
        (FITRecordField.speed, 2, .uint16),
        (FITRecordField.heartRateAlt, 1, .uint8),
      ])

    for sample in recordSamples {
      let timestamp = fitTimestamp(sample.timestamp)
      let distanceValue: Value
      if let meters = sample.distanceMeters {
        distanceValue = .uint32(UInt32(max(0, meters * 100).rounded()))
      } else {
        distanceValue = .invalid
      }

      let speedValue: Value
      if let speed = sample.speedMps {
        speedValue = .uint16(UInt16(min(65_535, max(0, speed * 1000).rounded())))
      } else {
        speedValue = .invalid
      }

      let heartRateValue: Value
      if let hr = sample.heartRateBpm {
        heartRateValue = .uint8(hr)
      } else {
        heartRateValue = .invalid
      }

      writer.write(
        localType: recordLocal,
        values: [
          .uint32(timestamp),
          distanceValue,
          speedValue,
          heartRateValue,
        ])
    }

    // timer stop
    writer.write(
      localType: eventLocal,
      values: [
        .uint32(endTimestamp),
        .enumType(FITEvent.timer.rawValue),
        .enumType(FITEventType.stopAll.rawValue),
      ])

    // lap
    let lapLocal = writer.define(
      globalMessageNumber: FITGlobalMessage.lap,
      fields: [
        (254, 2, .uint16),
        (253, 4, .uint32),
        (2, 4, .uint32),
        (7, 4, .uint32),
        (8, 4, .uint32),
        (9, 4, .uint32),
      ])
    writer.write(
      localType: lapLocal,
      values: [
        .uint16(0),
        .uint32(endTimestamp),
        .uint32(startTimestamp),
        .uint32(UInt32(elapsed.rounded())),
        .uint32(UInt32(elapsed.rounded())),
        .uint32(UInt32(max(0, totalDistance * 100).rounded())),
      ])

    // session
    let sessionLocal = writer.define(
      globalMessageNumber: FITGlobalMessage.session,
      fields: [
        (254, 2, .uint16),
        (253, 4, .uint32),
        (2, 4, .uint32),
        (5, 1, .enumType),
        (6, 1, .enumType),
        (7, 4, .uint32),
        (8, 4, .uint32),
        (9, 4, .uint32),
        (11, 2, .uint16),
        (14, 1, .uint8),
        (15, 1, .uint8),
        (25, 2, .uint16),
        (26, 2, .uint16),
      ])

    var sessionValues: [Value] = [
      .uint16(0),
      .uint32(endTimestamp),
      .uint32(startTimestamp),
      .enumType(input.sport.rawValue),
      .enumType(input.subSport.rawValue),
      .uint32(UInt32(elapsed.rounded())),
      .uint32(UInt32(elapsed.rounded())),
      .uint32(UInt32(max(0, totalDistance * 100).rounded())),
    ]

    if let kcal = input.totalEnergyKcal {
      sessionValues.append(.uint16(UInt16(min(65_535, max(0, kcal).rounded()))))
    } else {
      sessionValues.append(.invalid)
    }

    if let avgHeartRate {
      sessionValues.append(.uint8(avgHeartRate))
    } else {
      sessionValues.append(.invalid)
    }

    if let maxHeartRate {
      sessionValues.append(.uint8(maxHeartRate))
    } else {
      sessionValues.append(.invalid)
    }

    sessionValues.append(.uint16(0))
    sessionValues.append(.uint16(1))

    writer.write(localType: sessionLocal, values: sessionValues)

    // activity
    let activityLocal = writer.define(
      globalMessageNumber: FITGlobalMessage.activity,
      fields: [
        (253, 4, .uint32),
        (0, 4, .uint32),
        (5, 2, .uint16),
      ])
    writer.write(
      localType: activityLocal,
      values: [
        .uint32(endTimestamp),
        .uint32(UInt32(elapsed.rounded())),
        .uint16(1),
      ])

    return writer.finish()
  }

  public static func encodeData(_ input: FITActivityInput) -> Data {
    Data(encode(input))
  }

  private static func fitTimestamp(_ date: Date) -> UInt32 {
    UInt32(date.timeIntervalSince1970) &- fitEpochOffset
  }

  private static func averageHeartRate(from values: [UInt8]) -> UInt8? {
    guard !values.isEmpty else { return nil }
    let total = values.reduce(UInt(0)) { $0 + UInt($1) }
    return UInt8(total / UInt(values.count))
  }
}

#endif
