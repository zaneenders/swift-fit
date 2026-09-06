import Testing

@testable import SwiftFit

@Suite struct BaseTypeTests {
  @Test(arguments: [
    (BaseType.enumType, 1),
    (.sint8, 1),
    (.uint8, 1),
    (.string, 1),
    (.uint8z, 1),
    (.byte, 1),
    (.sint16, 2),
    (.uint16, 2),
    (.uint16z, 2),
    (.sint32, 4),
    (.uint32, 4),
    (.float32, 4),
    (.uint32z, 4),
    (.float64, 8),
    (.sint64, 8),
    (.uint64, 8),
    (.uint64z, 8),
    (.invalid, 0),
  ])
  func elementSizes(type: BaseType, expected: Int) {
    #expect(type.size == expected)
  }

  @Test(arguments: [
    (BaseType.enumType, UInt64(0xFF)),
    (.sint8, 0xFF),
    (.uint8, 0xFF),
    (.byte, 0xFF),
    (.sint16, 0xFFFF),
    (.uint16, 0xFFFF),
    (.sint32, 0xFFFF_FFFF),
    (.uint32, 0xFFFF_FFFF),
    (.sint64, 0xFFFF_FFFF_FFFF_FFFF),
    (.uint64, 0xFFFF_FFFF_FFFF_FFFF),
    (.uint64z, 0),
    (.uint8z, 0),
    (.uint16z, 0),
    (.uint32z, 0),
    (.string, 0),
    (.float32, 0xFFFF_FFFF),
    (.float64, 0xFFFF_FFFF_FFFF_FFFF),
    (.invalid, 0),
  ])
  func invalidValues(type: BaseType, expected: UInt64) {
    #expect(type.invalidValue == expected)
  }
}
