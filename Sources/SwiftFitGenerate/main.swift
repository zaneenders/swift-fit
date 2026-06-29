import Foundation
import SwiftFit

// MARK: - Route generation

/// Generate a route around Central Park, NYC with `pointCount` points.
func generateRoute(pointCount: Int, durationSeconds: Double) -> [(Double, Double, Double)] {
  let centerLat = 40.7829
  let centerLon = -73.9654
  let startAlt = 30.0  // meters

  let majorRadiusLat = 0.015
  let majorRadiusLon = 0.012

  var points: [(Double, Double, Double)] = []
  points.reserveCapacity(pointCount)

  for i in 0..<pointCount {
    let fraction = Double(i) / Double(pointCount - 1)
    let spiralFactor = sin(fraction * .pi)
    let angle = fraction * 3.5 * 2.0 * .pi
    let radiusVariation = 0.7 + 0.3 * sin(fraction * 8.0 * .pi)

    let rLat = majorRadiusLat * spiralFactor * radiusVariation
    let rLon = majorRadiusLon * spiralFactor * radiusVariation

    let lat = centerLat + rLat * cos(angle) + Double.random(in: -0.00002...0.00002)
    let lon = centerLon + rLon * sin(angle) + Double.random(in: -0.00002...0.00002)

    let altVariation = 7.0 * sin(fraction * 6.0 * .pi) + 3.0 * sin(fraction * 14.0 * .pi)
    let alt = startAlt + altVariation + Double.random(in: -0.1...0.1)

    points.append((lat, lon, max(0, alt)))
  }
  return points
}

// MARK: - Coordinate helpers

func degreesToSemicircles(_ degrees: Double) -> Int32 {
  Int32((degrees * (Double(1 << 31) / 180.0)).rounded())
}

func altitudeToFit(_ meters: Double) -> UInt16 {
  UInt16(((meters + 500.0) * 5.0).rounded())
}

// MARK: - Main

let pointCount = 7200
let durationSeconds: Double = 2 * 60 * 60  // 2 hours → ~1 point per second

print("Generating \(pointCount) points over \(Int(durationSeconds / 3600)) hours...")
let route = generateRoute(pointCount: pointCount, durationSeconds: durationSeconds)

let fitEpochOffset: UInt32 = 631_065_600
let startTime = Date(timeIntervalSince1970: 1_751_101_200)  // 2025-06-28 09:00 UTC
let timeInterval = durationSeconds / Double(max(pointCount - 1, 1))

func fitTimestamp(_ date: Date) -> UInt32 {
  UInt32(date.timeIntervalSince1970) - fitEpochOffset
}

print("Building FIT file with SwiftFit...")
var writer = FITWriter()

// -- file_id (global message #0) --
let fileIdLocal = writer.define(
  globalMessageNumber: 0,
  fields: [
    (0, 1, .enumType),  // type
    (1, 2, .uint16),  // manufacturer
    (2, 2, .uint16),  // product
    (3, 4, .uint32),  // serial_number
    (4, 4, .uint32),  // time_created
  ])
writer.write(
  localType: fileIdLocal,
  values: [
    .enumType(4),  // type = activity
    .uint16(1),  // manufacturer = Garmin
    .uint16(0),  // product
    .uint32(123_456_789),  // serial number
    .uint32(fitTimestamp(startTime)),
  ])

// -- record (global message #20) --
let recordLocal = writer.define(
  globalMessageNumber: 20,
  fields: [
    (253, 4, .uint32),  // timestamp
    (0, 4, .sint32),  // position_lat
    (1, 4, .sint32),  // position_long
    (2, 2, .uint16),  // altitude
    (3, 1, .uint8),  // heart_rate
    (6, 2, .uint16),  // speed
  ])

for i in 0..<pointCount {
  let (lat, lon, alt) = route[i]
  let ts = fitTimestamp(startTime.addingTimeInterval(Double(i) * timeInterval))

  let baseHR = 130.0
  let hrVariation =
    20.0 * sin(Double(i) / Double(pointCount) * 8.0 * .pi)
    + 10.0 * sin(Double(i) / Double(pointCount) * 3.0 * .pi)
  let hr = UInt8(max(60, min(200, (baseHR + hrVariation).rounded())))

  let baseSpeed = 3.2
  let speedVariation =
    1.0 * sin(Double(i) / Double(pointCount) * 5.0 * .pi)
    + 0.5 * sin(Double(i) / Double(pointCount) * 12.0 * .pi)
  let speedMps = max(1.5, min(5.5, baseSpeed + speedVariation))

  writer.write(
    localType: recordLocal,
    values: [
      .uint32(ts),
      .sint32(degreesToSemicircles(lat)),
      .sint32(degreesToSemicircles(lon)),
      .uint16(altitudeToFit(alt)),
      .uint8(hr),
      .uint16(UInt16((speedMps * 1000).rounded())),
    ])
}

let fitData = writer.finishData()

// Write to file in the project root
let outputURL = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()  // SwiftFitGenerate/
  .deletingLastPathComponent()  // Sources/
  .deletingLastPathComponent()  // project root
  .appendingPathComponent("central_park_loop_1s.fit")

try fitData.write(to: outputURL)

print("✅ Written: \(outputURL.path)")
print("   Size: \(fitData.count) bytes")
print("   Messages: 1 file_id + \(pointCount) records = \(pointCount + 1) total")
print("   Duration: \(Int(durationSeconds / 60)) minutes")
print("   Route: Central Park, NYC  (\(route.first!.0), \(route.first!.1)) → (\(route.last!.0), \(route.last!.1))")

// Self-test with the decoder
print("\n--- Self-test: decoding ---")
let decoded = try FITFile(data: fitData)
let recordMsgs = decoded.messages.filter { $0.globalMessageNumber == 20 }
print("   Decoded \(recordMsgs.count) records, CRC valid: \(decoded.fileCRCValid)")

if let first = recordMsgs.first?.fields.first(where: { $0.fieldDefinitionNumber == 253 }),
  let last = recordMsgs.last?.fields.first(where: { $0.fieldDefinitionNumber == 253 }),
  case .uint32(let t1) = first.values.first,
  case .uint32(let t2) = last.values.first
{
  print("   Timestamp span: \(Int(t2) - Int(t1)) seconds")
}
print("   ✅ Library parsed own output successfully")
