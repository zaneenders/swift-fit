import SwiftFit

public enum FITActivityEncoder {
  private static let semicircleScale = 2_147_483_648.0 / 180.0

  public static func encode(_ summary: FITActivitySummary) throws(FITWriterError) -> [UInt8] {
    var writer = FITWriter()
    writer.useCompressedTimestamps = true

    let fileIdLocal = try writer.define(
      globalMessageNumber: FITGlobalMessage.fileID,
      fields: [
        (0, 1, .enumType),
        (1, 2, .uint16),
        (4, 4, .uint32),
      ])
    try writer.write(
      localType: fileIdLocal,
      values: [
        .enumType(FITFileType.activity.rawValue),
        .uint16(FITManufacturer.development.rawValue),
        .uint32(0),
      ])

    let recordLocal = try writer.define(
      globalMessageNumber: FITGlobalMessage.record,
      fields: [
        (FITRecordField.timestamp, 4, .uint32),
        (FITRecordField.positionLat, 4, .sint32),
        (FITRecordField.positionLong, 4, .sint32),
        (FITRecordField.altitude, 2, .uint16),
        (FITRecordField.heartRate, 1, .uint8),
        (FITRecordField.distance, 4, .uint32),
        (FITRecordField.enhancedSpeed, 4, .uint32),
      ])

    for point in summary.points {
      var values: [Value] = [
        .uint32(point.timestamp ?? 0),
        .invalid,
        .invalid,
        .invalid,
        .invalid,
        .invalid,
        .invalid,
      ]
      if let lat = point.lat {
        values[1] = .sint32(Int32((lat * semicircleScale).rounded()))
      }
      if let lon = point.lon {
        values[2] = .sint32(Int32((lon * semicircleScale).rounded()))
      }
      if let altitudeMeters = point.altitudeMeters {
        values[3] = .uint16(UInt16(((altitudeMeters + 500.0) * 5.0).rounded()))
      }
      if let heartRate = point.heartRate {
        values[4] = .uint8(heartRate)
      }
      if let distanceMeters = point.distanceMeters {
        values[5] = .uint32(UInt32((distanceMeters * 100.0).rounded()))
      }
      if let speedMps = point.speedMps {
        values[6] = .uint32(UInt32((speedMps * 1000.0).rounded()))
      }
      try writer.write(localType: recordLocal, values: values)
    }

    if summary.sport != nil || summary.subSport != nil || summary.sessionDistanceMeters != nil {
      let sessionLocal = try writer.define(
        globalMessageNumber: FITGlobalMessage.session,
        fields: [
          (FITSessionField.sport, 1, .enumType),
          (FITSessionField.subSport, 1, .enumType),
          (FITSessionField.totalDistance, 4, .uint32),
        ])
      var sessionValues: [Value] = [.invalid, .invalid, .invalid]
      if let sport = summary.sport {
        sessionValues[0] = .enumType(sport.rawValue)
      }
      if let subSport = summary.subSport {
        sessionValues[1] = .enumType(subSport.rawValue)
      }
      if let sessionDistanceMeters = summary.sessionDistanceMeters {
        sessionValues[2] = .uint32(UInt32((sessionDistanceMeters * 100.0).rounded()))
      }
      try writer.write(localType: sessionLocal, values: sessionValues)
    }

    return writer.finish()
  }
}

#if canImport(Foundation)
import Foundation

extension FITActivityEncoder {
  public static func encodeData(_ summary: FITActivitySummary) throws(FITWriterError) -> Data {
    Data(try encode(summary))
  }
}
#endif
