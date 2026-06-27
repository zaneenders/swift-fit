import Foundation
import Testing

@testable import SwiftFit

@Suite("FITCRC")
struct FITCRCTests {
  @Test
  func emptyInput() {
    #expect(FITCRC.compute(Data()) == 0)
  }

  // "123456789" should produce 0x31C3 for CCITT-0 (poly 0x1021, init 0).
  @Test
  func standardCheck() {
    let bytes: [UInt8] = Array("123456789".utf8)
    #expect(FITCRC.compute(bytes) == 0x31C3)
  }

  @Test
  func tableMatchesByteWise() {
    let data = Data([0x00, 0x01, 0x02, 0xFF, 0x10, 0x42])
    var crc: UInt16 = 0
    for b in data {
      let idx = Int((crc >> 8) ^ UInt16(b)) & 0xFF
      crc = (crc << 8) ^ FITCRC.table[idx]
    }
    #expect(crc == FITCRC.compute(data))
  }
}
