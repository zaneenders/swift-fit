import Foundation
import Testing

@testable import SwiftFit

@Suite struct FITProtocolTests {
  @Test func decodesCompressedTimestampRecords() throws {
    var writer = FITWriter()
    writer.useCompressedTimestamps = true
    let recordLocal = try writer.define(
      globalMessageNumber: FITGlobalMessage.record,
      fields: [
        (FITField.timestamp, 4, .uint32),
        (0, 1, .uint8),
      ])

    let baseTimestamp: UInt32 = 1_000_000
    try writer.write(
      localType: recordLocal,
      values: [.uint32(baseTimestamp), .uint8(10)])
    try writer.write(
      localType: recordLocal,
      values: [.uint32(baseTimestamp &+ 3), .uint8(11)])
    try writer.write(
      localType: recordLocal,
      values: [.uint32(baseTimestamp &+ 7), .uint8(12)])

    let fit = try FITFile(data: writer.finishData())
    #expect(fit.messages.count == 3)
    #expect(fit.messages[0].uint32Field(number: FITField.timestamp) == baseTimestamp)
    #expect(fit.messages[1].uint32Field(number: FITField.timestamp) == baseTimestamp &+ 3)
    #expect(fit.messages[2].uint32Field(number: FITField.timestamp) == baseTimestamp &+ 7)
  }

  @Test func writerRejectsUnknownLocalType() throws {
    var writer = FITWriter()
    #expect(throws: FITWriterError.unknownLocalType(9)) {
      try writer.write(localType: 9, values: [.uint8(1)])
    }
  }

  @Test func writerRejectsTooManyLocalTypes() throws {
    var writer = FITWriter()
    for index in 0..<16 {
      _ = try writer.define(
        globalMessageNumber: UInt16(index),
        fields: [(0, 1, .uint8)])
    }
    #expect(throws: FITWriterError.tooManyLocalTypes) {
      try writer.define(globalMessageNumber: 99, fields: [(0, 1, .uint8)])
    }
  }

  @Test func strictDefinitionsRejectUnknownBaseType() throws {
    var payload = Data()
    payload.append(0b0100_0000)
    payload.append(0x00)
    payload.append(0x00)
    payload.append(UInt8(0))
    payload.append(UInt8(0))
    payload.append(1)
    payload.append(0)
    payload.append(1)
    payload.append(0x7F)  // unknown base type

    var header = Data()
    header.append(14)
    header.append(0x10)
    header.append(0x14)
    header.append(0x21)
    let dataSize = UInt32(payload.count)
    header.append(UInt8(dataSize & 0xFF))
    header.append(UInt8((dataSize >> 8) & 0xFF))
    header.append(UInt8((dataSize >> 16) & 0xFF))
    header.append(UInt8((dataSize >> 24) & 0xFF))
    header.append(0x2E)
    header.append(0x46)
    header.append(0x49)
    header.append(0x54)
    let headerCRC = FITCRC.compute(header.prefix(12))
    header.append(UInt8(headerCRC & 0xFF))
    header.append(UInt8((headerCRC >> 8) & 0xFF))

    var file = Data()
    file.append(header)
    file.append(payload)
    let fileCRC = FITCRC.compute(file)
    file.append(UInt8(fileCRC & 0xFF))
    file.append(UInt8((fileCRC >> 8) & 0xFF))

    var options = FITDecodeOptions()
    options.strictDefinitions = true
    #expect(throws: FITError.invalidBaseType(0x7F)) {
      try FITFile(data: file, options: options)
    }
  }

  @Test func parsesDeveloperDataMessages() throws {
    var writer = FITWriter()
    let developerIDLocal = try writer.define(
      globalMessageNumber: FITGlobalMessage.developerDataID,
      fields: [
        (FITDeveloperDataIDField.developerDataIndex, 1, .uint8),
        (FITDeveloperDataIDField.developerId, 1, .uint8),
        (FITDeveloperDataIDField.applicationId, 4, .byte),
      ])
    try writer.write(
      localType: developerIDLocal,
      values: [
        .uint8(1),
        .uint8(42),
        .bytes([0x01, 0x02, 0x03, 0x04]),
      ])

    let developerDefinitionLocal = try writer.define(
      globalMessageNumber: FITGlobalMessage.developerDataDefinition,
      fields: [
        (FITDeveloperDataDefinitionField.developerDataIndex, 1, .uint8),
        (FITDeveloperDataDefinitionField.fieldDefinitionNumber, 1, .uint8),
        (FITDeveloperDataDefinitionField.fitBaseTypeId, 1, .uint8),
        (FITDeveloperDataDefinitionField.fieldName, 8, .string),
        (FITDeveloperDataDefinitionField.units, 6, .string),
      ])
    try writer.write(
      localType: developerDefinitionLocal,
      values: [
        .uint8(1),
        .uint8(0),
        .uint8(BaseType.float32.rawValue),
        .string("power"),
        .string("watts"),
      ])

    let fit = try FITFile(data: writer.finishData())
    let developerID = try #require(fit.developerDataIDs[1])
    #expect(developerID.developerId == 42)
    #expect(developerID.applicationId == [0x01, 0x02, 0x03, 0x04])

    let key = DeveloperFieldKey(developerDataIndex: 1, fieldDefinitionNumber: 0)
    let fieldDefinition = try #require(fit.developerFieldDefinitions[key])
    #expect(fieldDefinition.fieldName == "power")
    #expect(fieldDefinition.units == "watts")
    #expect(fieldDefinition.baseType == .float32)
  }
}
