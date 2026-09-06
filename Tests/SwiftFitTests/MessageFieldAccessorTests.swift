import Testing

@testable import SwiftFit

@Suite struct MessageFieldAccessorTests {
  @Test func typedAccessorsAcceptCompatibleValues() {
    let message = Message(globalMessageNumber: 1, fields: [
      Field(fieldDefinitionNumber: 0, baseType: .uint8z, values: [.uint8z(1)]),
      Field(fieldDefinitionNumber: 1, baseType: .enumType, values: [.enumType(2)]),
      Field(fieldDefinitionNumber: 2, baseType: .byte, values: [.byte(3)]),
      Field(fieldDefinitionNumber: 3, baseType: .uint16z, values: [.uint16z(4)]),
      Field(fieldDefinitionNumber: 4, baseType: .uint32z, values: [.uint32z(5)]),
      Field(fieldDefinitionNumber: 5, baseType: .sint32, values: [.sint32(-6)]),
    ])

    #expect(message.uint8Field(number: 0) == 1)
    #expect(message.enumField(number: 1) == 2)
    #expect(message.uint8Field(number: 2) == 3)
    #expect(message.uint16Field(number: 3) == 4)
    #expect(message.uint32Field(number: 4) == 5)
    #expect(message.sint32Field(number: 5) == -6)
    #expect(message.field(number: 99) == nil)
    #expect(message.firstValue(number: 99) == nil)
  }

  @Test func typedAccessorsRejectIncompatibleAndEmptyValues() {
    let message = Message(globalMessageNumber: 1, fields: [
      Field(fieldDefinitionNumber: 0, baseType: .string, values: [.string("value")]),
      Field(fieldDefinitionNumber: 1, baseType: .uint8, values: []),
    ])

    #expect(message.uint8Field(number: 0) == nil)
    #expect(message.uint16Field(number: 0) == nil)
    #expect(message.uint32Field(number: 0) == nil)
    #expect(message.sint32Field(number: 0) == nil)
    #expect(message.stringField(number: 1) == nil)
  }

  @Test func stringAccessorTrimsWhitespaceAndRejectsBlankOrWrongType() {
    let message = Message(globalMessageNumber: 1, fields: [
      Field(fieldDefinitionNumber: 0, baseType: .string, values: [.string("  hello \n")]),
      Field(fieldDefinitionNumber: 1, baseType: .string, values: [.string(" \t\n ")]),
      Field(fieldDefinitionNumber: 2, baseType: .uint8, values: [.uint8(1)]),
    ])

    #expect(message.stringField(number: 0) == "hello")
    #expect(message.stringField(number: 1) == nil)
    #expect(message.stringField(number: 2) == nil)
    #expect(message.stringField(number: 99) == nil)
  }

  @Test func headerComputedProperties() {
    let short = Header(
      headerSize: 12, protocolVersion: 0x10, profileVersion: 1,
      dataSize: 0, signature: 0x5449_462E, storedCRC: nil)
    let full = Header(
      headerSize: 14, protocolVersion: 0x10, profileVersion: 1,
      dataSize: 0, signature: 0x5449_462E, storedCRC: 42)

    #expect(short.includesCRC == false)
    #expect(short.crc == nil)
    #expect(full.includesCRC == true)
    #expect(full.crc == 42)
  }
}
