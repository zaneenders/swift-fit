import SwiftFit

public struct FITTrackPoint: Sendable {
  public let lat: Double?
  public let lon: Double?
  public let altitudeMeters: Double?
  public let heartRate: UInt8?
  public let speedMps: Double?
  public let distanceMeters: Double?
  public let timestamp: UInt32?

  public init(
    lat: Double?,
    lon: Double?,
    altitudeMeters: Double?,
    heartRate: UInt8?,
    speedMps: Double?,
    distanceMeters: Double?,
    timestamp: UInt32?
  ) {
    self.lat = lat
    self.lon = lon
    self.altitudeMeters = altitudeMeters
    self.heartRate = heartRate
    self.speedMps = speedMps
    self.distanceMeters = distanceMeters
    self.timestamp = timestamp
  }
}

/// Decoded activity file messages: record points and session metadata.
public struct FITActivitySummary: Sendable {
  public let points: [FITTrackPoint]
  public let sport: FITSport?
  public let subSport: FITSubSport?
  public let sessionDistanceMeters: Double?

  public init(
    points: [FITTrackPoint],
    sport: FITSport?,
    subSport: FITSubSport?,
    sessionDistanceMeters: Double?
  ) {
    self.points = points
    self.sport = sport
    self.subSport = subSport
    self.sessionDistanceMeters = sessionDistanceMeters
  }
}

public enum FITActivityParser {
  private static let semicircleScale = 180.0 / 2_147_483_648.0

  public static func parse(
    bytes: [UInt8],
    options: FITDecodeOptions = FITDecodeOptions()
  ) throws(FITError) -> FITActivitySummary {
    let fit = try FITFile(bytes: bytes, options: options)
    var points: [FITTrackPoint] = []
    points.reserveCapacity(fit.messages.count / 4)

    for message in fit.messages where message.globalMessageNumber == FITGlobalMessage.record {
      guard let point = recordPoint(from: message) else { continue }
      points.append(point)
    }

    let session = fit.messages.first { $0.globalMessageNumber == FITGlobalMessage.session }
    let sport = session.flatMap { message in
      message.enumField(number: FITSessionField.sport).flatMap(FITSport.init(rawValue:))
    }
    let subSport = session.flatMap { message in
      message.enumField(number: FITSessionField.subSport).flatMap(FITSubSport.init(rawValue:))
    }
    let sessionDistanceMeters = session.flatMap(sessionDistanceMeters(from:))

    return FITActivitySummary(
      points: points,
      sport: sport,
      subSport: subSport,
      sessionDistanceMeters: sessionDistanceMeters
    )
  }

  private static func recordPoint(from message: Message) -> FITTrackPoint? {
    let timestamp = message.uint32Field(number: FITRecordField.timestamp)

    let latLon: (lat: Double, lon: Double)?
    if let lat = message.sint32Field(number: FITRecordField.positionLat),
      let lon = message.sint32Field(number: FITRecordField.positionLong)
    {
      let latDegrees = Double(lat) * semicircleScale
      let lonDegrees = Double(lon) * semicircleScale
      if latDegrees.isFinite, lonDegrees.isFinite, abs(latDegrees) <= 90, abs(lonDegrees) <= 180 {
        latLon = (latDegrees, lonDegrees)
      } else {
        latLon = nil
      }
    } else {
      latLon = nil
    }

    let altitude: Double?
    if let raw = message.uint16Field(number: FITRecordField.altitude), raw != 0xFFFF {
      altitude = (Double(raw) / 5.0) - 500.0
    } else {
      altitude = nil
    }

    let heartRate =
      message.uint8Field(number: FITRecordField.heartRate)
      ?? message.uint8Field(number: FITRecordField.heartRateAlt)

    let speedMps: Double?
    if let raw = message.uint32Field(number: FITRecordField.enhancedSpeed), raw != 0xFFFF_FFFF {
      speedMps = Double(raw) / 1000.0
    } else if let raw = message.uint16Field(number: FITRecordField.speed), raw != 0xFFFF {
      speedMps = Double(raw) / 1000.0
    } else {
      speedMps = nil
    }

    let distanceMeters: Double?
    if let raw = message.uint32Field(number: FITRecordField.distance) {
      distanceMeters = Double(raw) / 100.0
    } else {
      distanceMeters = nil
    }

    guard latLon != nil
      || timestamp != nil
      || heartRate != nil
      || speedMps != nil
      || distanceMeters != nil
    else { return nil }

    return FITTrackPoint(
      lat: latLon?.lat,
      lon: latLon?.lon,
      altitudeMeters: altitude,
      heartRate: heartRate,
      speedMps: speedMps,
      distanceMeters: distanceMeters,
      timestamp: timestamp
    )
  }

  private static func sessionDistanceMeters(from message: Message) -> Double? {
    guard let raw = message.uint32Field(number: FITSessionField.totalDistance) else { return nil }
    return Double(raw) / 100.0
  }
}
