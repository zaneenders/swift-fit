import Foundation
import Testing

@testable import SwiftFit

enum FITFixture {
  static func build(
    globalMessageNumber: UInt16 = 0,
    fields: [(
      UInt8 /* num */, UInt8 /* size */,
      UInt8 /* baseType */, Data /* bytes */
    )]
  ) -> Data {
    var buffer = Data()

    buffer.append(0b01000000)
    buffer.append(0x00)  // reserved
    buffer.append(0x00)  // architecture = little-endian
    buffer.append(UInt8(globalMessageNumber & 0xFF))
    buffer.append(UInt8((globalMessageNumber >> 8) & 0xFF))
    buffer.append(UInt8(fields.count))
    for (num, size, baseType, _) in fields {
      buffer.append(num)
      buffer.append(size)
      buffer.append(baseType)
    }

    buffer.append(0b00000000)
    for (_, _, _, bytes) in fields { buffer.append(bytes) }

    var header = Data()
    header.append(14)  // header size
    header.append(0x10)  // protocol version 1.0
    header.append(0x14)
    header.append(0x21)  // profile version 8468 (little-endian)
    let dataSize = UInt32(buffer.count)
    header.append(UInt8(dataSize & 0xFF))
    header.append(UInt8((dataSize >> 8) & 0xFF))
    header.append(UInt8((dataSize >> 16) & 0xFF))
    header.append(UInt8((dataSize >> 24) & 0xFF))
    header.append(0x2E)
    header.append(0x46)  // ".FIT"
    header.append(0x49)
    header.append(0x54)
    // CRC of the first 12 header bytes goes here (2 bytes).
    let headerCRC = FITCRC.compute(header.prefix(12))
    header.append(UInt8(headerCRC & 0xFF))
    header.append(UInt8((headerCRC >> 8) & 0xFF))

    var file = Data()
    file.append(header)
    file.append(buffer)

    let crc = FITCRC.compute(file)
    file.append(UInt8(crc & 0xFF))
    file.append(UInt8((crc >> 8) & 0xFF))
    return file
  }
}

@Suite struct FITFileTests {
  @Test func parseMinimalFile() throws {
    let serialBytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
    let data = FITFixture.build(
      fields: [
        (0, 4, BaseType.uint32.rawValue, Data(serialBytes))
      ]
    )

    let fit = try FITFile(data: data)
    #expect(fit.header.profileVersion == 8468)
    #expect(fit.messages.count == 1)
    #expect(fit.messages[0].globalMessageNumber == 0)
    #expect(fit.messages[0].fields.count == 1)
    #expect(fit.messages[0].fields[0].fieldDefinitionNumber == 0)

    guard case .uint32(let v) = fit.messages[0].fields[0].values.first
    else {
      Issue.record("expected uint32 value")
      return
    }
    #expect(v == 0xEFBE_ADDE)
  }

  @Test func parseStringField() throws {
    let data = FITFixture.build(fields: [
      (3, 6, BaseType.string.rawValue, Data("hello".utf8) + Data([0]))
    ])
    let fit = try FITFile(data: data)
    guard case .string(let s) = fit.messages[0].fields[0].values.first
    else {
      Issue.record("expected string")
      return
    }
    #expect(s == "hello")
  }

  @Test func invalidSignatureRejected() throws {
    var bad = FITFixture.build(fields: [])
    bad[8] = 0x00  // corrupt ".FIT" (signature starts at byte 8)
    #expect(throws: FITError.invalidHeaderSignature) {
      try FITFile(data: bad)
    }
  }

  @Test func crcMismatchNotFatalByDefault() throws {
    var bad = FITFixture.build(fields: [
      (0, 1, BaseType.uint8.rawValue, Data([0xFF]))
    ])
    let last = bad.count - 1
    bad[last] = bad[last] ^ 0xFF  // flip the CRC
    // Default: parse succeeds, but validity flag is false.
    let fit = try FITFile(data: bad)
    #expect(fit.fileCRCValid == false)
  }

  @Test func crcMismatchRejectedWhenValidating() throws {
    var bad = FITFixture.build(fields: [
      (0, 1, BaseType.uint8.rawValue, Data([0xFF]))
    ])
    let last = bad.count - 1
    bad[last] = bad[last] ^ 0xFF  // flip the CRC
    var options = FITDecodeOptions()
    options.validateFileCRC = true
    #expect(throws: FITError.self) {
      try FITFile(data: bad, options: options)
    }
  }

  @Test func headerCRCValidFlaggedForGoodFile() throws {
    let data = FITFixture.build(fields: [
      (0, 1, BaseType.uint8.rawValue, Data([0x42]))
    ])
    let fit = try FITFile(data: data)
    #expect(fit.headerCRCValid == true)
  }

  @Test func headerCRCMismatchRejectedWhenValidating() throws {
    var bad = FITFixture.build(fields: [
      (0, 1, BaseType.uint8.rawValue, Data([0x42]))
    ])
    let crcIndex = 12
    bad[crcIndex] = bad[crcIndex] ^ 0xFF
    var options = FITDecodeOptions()
    options.validateHeaderCRC = true
    #expect(throws: FITError.self) {
      try FITFile(data: bad, options: options)
    }
  }

  @Test func crcValidFlaggedForGoodFile() throws {
    let data = FITFixture.build(fields: [
      (0, 1, BaseType.uint8.rawValue, Data([0x42]))
    ])
    let fit = try FITFile(data: data)
    #expect(fit.fileCRCValid == true)
  }
}
