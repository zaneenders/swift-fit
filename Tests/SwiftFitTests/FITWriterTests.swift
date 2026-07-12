import Foundation
import Testing

@testable import SwiftFit

@Suite struct FITWriterTests {

  @Test func roundTripEnumType() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 1, .enumType)])
    w.write(localType: 0, values: [.enumType(4)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages.count == 1)
    #expect(fit.messages[0].fields[0].values == [.enumType(4)])
  }

  @Test func roundTripUInt8() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 1, .uint8)])
    w.write(localType: 0, values: [.uint8(200)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.uint8(200)])
  }

  @Test func roundTripSInt32() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 4, .sint32)])
    w.write(localType: 0, values: [.sint32(-12_345_678)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.sint32(-12_345_678)])
  }

  @Test func roundTripUInt32() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 4, .uint32)])
    w.write(localType: 0, values: [.uint32(0xDEAD_BEEF)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.uint32(0xDEAD_BEEF)])
  }

  @Test func roundTripFloat32() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 4, .float32)])
    w.write(localType: 0, values: [.float32(3.14)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.float32(3.14)])
  }

  @Test func roundTripFloat64() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 8, .float64)])
    w.write(localType: 0, values: [.float64(.pi)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.float64(.pi)])
  }

  @Test func roundTripString() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 10, .string)])
    w.write(localType: 0, values: [.string("hello")])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.string("hello")])
  }

  @Test func roundTripSInt16() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 2, .sint16)])
    w.write(localType: 0, values: [.sint16(-12345)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.sint16(-12345)])
  }

  @Test func roundTripUInt16() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 2, .uint16)])
    w.write(localType: 0, values: [.uint16(65000)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.uint16(65000)])
  }

  @Test func roundTripSInt64() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 8, .sint64)])
    w.write(localType: 0, values: [.sint64(-9_223_372_036_854_775_807)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.sint64(-9_223_372_036_854_775_807)])
  }

  @Test func roundTripUInt64() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 8, .uint64)])
    w.write(localType: 0, values: [.uint64(18_446_744_073_709_551_615)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.uint64(18_446_744_073_709_551_615)])
  }

  @Test func roundTripByte() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 1, .byte)])
    w.write(localType: 0, values: [.byte(0xAB)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields[0].values == [.byte(0xAB)])
  }

  @Test func multipleLocalTypes() throws {
    var w = FITWriter()
    let a = w.define(globalMessageNumber: 10, fields: [(0, 1, .uint8)])
    let b = w.define(globalMessageNumber: 20, fields: [(1, 2, .uint16)])
    w.write(localType: a, values: [.uint8(42)])
    w.write(localType: b, values: [.uint16(999)])
    w.write(localType: a, values: [.uint8(43)])

    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages.count == 3)
    #expect(fit.messages[0].globalMessageNumber == 10)
    #expect(fit.messages[1].globalMessageNumber == 20)
    #expect(fit.messages[2].globalMessageNumber == 10)
    #expect(fit.messages[0].fields[0].values == [.uint8(42)])
    #expect(fit.messages[1].fields[0].values == [.uint16(999)])
    #expect(fit.messages[2].fields[0].values == [.uint8(43)])
  }

  @Test func manyRecords() throws {
    var w = FITWriter()
    w.define(
      globalMessageNumber: 20,
      fields: [
        (0, 4, .sint32),
        (1, 2, .uint16),
      ])
    for i in 0..<1000 {
      w.write(localType: 0, values: [.sint32(Int32(i)), .uint16(UInt16(i & 0xFFFF))])
    }
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages.count == 1000)
    #expect(fit.fileCRCValid == true)

    // Spot-check
    if case .sint32(let v) = fit.messages[0].fields[0].values.first {
      #expect(v == 0)
    }
    if case .sint32(let v) = fit.messages[999].fields[0].values.first {
      #expect(v == 999)
    }
  }

  @Test func writerProducesValidCRC() throws {
    var w = FITWriter()
    w.define(globalMessageNumber: 0, fields: [(0, 4, .uint32)])
    w.write(localType: 0, values: [.uint32(12345)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.fileCRCValid == true)
  }

  @Test func customHeaderVersions() throws {
    var w = FITWriter()
    w.protocolVersion = 0x20
    w.profileVersion = 1234
    w.define(globalMessageNumber: 0, fields: [(0, 1, .uint8)])
    w.write(localType: 0, values: [.uint8(1)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.header.protocolVersion == 0x20)
    #expect(fit.header.profileVersion == 1234)
  }

  @Test func developerFields() throws {
    var w = FITWriter()
    w.define(
      globalMessageNumber: 99,
      fields: [(0, 2, .uint16)],
      developerFields: [(0, 4, .float32)]
    )
    w.write(localType: 0, values: [.uint16(100), .float32(1.5)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages.count == 1)
    #expect(fit.messages[0].fields.count == 2)
    #expect(fit.messages[0].fields[0].values == [.uint16(100)])
    #expect(fit.messages[0].fields[1].values == [.float32(1.5)])
  }

  @Test func fewerValuesThanFieldsWritesInvalidSentinel() throws {
    var w = FITWriter()
    w.define(
      globalMessageNumber: 0,
      fields: [
        (0, 4, .uint32),
        (1, 2, .uint16),
      ])
    // Only provide one value — the second field gets 0xFF bytes
    w.write(localType: 0, values: [.uint32(42)])
    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages[0].fields.count == 2)
    #expect(fit.messages[0].fields[0].values == [.uint32(42)])
    // 0xFFFF is the FIT invalid sentinel for uint16;
    // the decoder preserves it as .uint16(65535) (only floats get .invalid)
    #expect(fit.messages[0].fields[1].values == [.uint16(65535)])
  }

  @Test func realisticFileIdAndRecord() throws {
    var w = FITWriter()
    let fileId = w.define(
      globalMessageNumber: 0,
      fields: [
        (0, 1, .enumType),  // type
        (1, 2, .uint16),  // manufacturer
        (2, 2, .uint16),  // product
        (3, 4, .uint32),  // serial_number
        (4, 4, .uint32),  // time_created
      ])
    let record = w.define(
      globalMessageNumber: 20,
      fields: [
        (253, 4, .uint32),  // timestamp
        (0, 4, .sint32),  // position_lat
        (1, 4, .sint32),  // position_long
        (2, 2, .uint16),  // altitude
        (3, 1, .uint8),  // heart_rate
      ])

    w.write(
      localType: fileId,
      values: [
        .enumType(4),
        .uint16(1),
        .uint16(0),
        .uint32(123_456_789),
        .uint32(900_000_000),
      ])
    w.write(
      localType: record,
      values: [
        .uint32(900_000_001),
        .sint32(1_111_111_111),
        .sint32(-444_444_444),
        .uint16(3000),
        .uint8(142),
      ])

    let fit = try FITFile(data: w.finishData())
    #expect(fit.messages.count == 2)

    // file_id
    let fm = fit.messages[0]
    #expect(fm.globalMessageNumber == 0)
    #expect(fm.fields[0].values == [.enumType(4)])

    // record
    let rm = fit.messages[1]
    #expect(rm.globalMessageNumber == 20)
    #expect(rm.fields[0].values == [.uint32(900_000_001)])  // timestamp
    #expect(rm.fields[1].values == [.sint32(1_111_111_111)])  // lat
    #expect(rm.fields[2].values == [.sint32(-444_444_444)])  // lon
    #expect(rm.fields[3].values == [.uint16(3000)])  // altitude
    #expect(rm.fields[4].values == [.uint8(142)])  // hr
  }

  @Test func emptyFileStillHasValidCRC() throws {
    var w = FITWriter()
    _ = w.define(globalMessageNumber: 0, fields: [(0, 1, .uint8)])
    w.write(localType: 0, values: [.uint8(0)])
    let data = w.finishData()
    let fit = try FITFile(data: data)
    #expect(fit.fileCRCValid == true)
  }

  @Test func generatedFileIsReasonableSize() throws {
    // 7200 records should be well under 200 KB
    var w = FITWriter()
    w.define(
      globalMessageNumber: 20,
      fields: [
        (253, 4, .uint32),
        (0, 4, .sint32),
        (1, 4, .sint32),
      ])
    for i in 0..<7200 {
      w.write(
        localType: 0,
        values: [
          .uint32(UInt32(i)),
          .sint32(0),
          .sint32(0),
        ])
    }
    let data = w.finishData()
    #expect(data.count > 1000)
    #expect(data.count < 200_000)

    let fit = try FITFile(data: data)
    #expect(fit.messages.count == 7200)
    #expect(fit.fileCRCValid == true)
  }
}
