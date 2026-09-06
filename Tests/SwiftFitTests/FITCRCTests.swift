import Foundation
import Testing

@testable import SwiftFit

@Suite struct FITCRCTests {
  @Test func emptyInput() {
    #expect(FITCRC.compute(Data()) == 0)
  }

  // Garmin's FIT SDK reference algorithm uses the reflected 0xA001
  // polynomial. Its standard check value for this input is 0xBB3D.
  @Test func standardCheck() {
    let bytes: [UInt8] = Array("123456789".utf8)
    #expect(FITCRC.compute(bytes) == 0xBB3D)
  }

  @Test(arguments: [
    ([UInt8](), UInt16(0x0000)),
    ([0x00], UInt16(0x0000)),
    (Array("123456789".utf8), UInt16(0xBB3D)),
    (Array("The quick brown fox jumps over the lazy dog".utf8), UInt16(0xFCDF)),
  ])
  func knownVectors(bytes: [UInt8], expected: UInt16) {
    #expect(FITCRC.compute(bytes) == expected)
  }

  @Test func worksWithArraySequence() {
    let bytes: [UInt8] = Array("123456789".utf8)
    #expect(FITCRC.compute(bytes) == 0xBB3D)
  }

  @Test func worksWithAnySequence() {
    let lazy = AnySequence(Array("123456789".utf8))
    #expect(FITCRC.compute(lazy) == 0xBB3D)
  }

  @Test func worksWithSlice() {
    let full: [UInt8] = Array("XYZ123456789ABC".utf8)
    let slice = full[3..<12]
    #expect(FITCRC.compute(slice) == 0xBB3D)
  }

  @Test func appendingChangesCRC() {
    let base: [UInt8] = [0x10, 0x20, 0x30]
    #expect(FITCRC.compute(base) != FITCRC.compute(base + [0x40]))
  }

  @Test func repeatedByteIsDeterministic() {
    let bytes = [UInt8](repeating: 0xAA, count: 16)
    let first = FITCRC.compute(bytes)
    #expect(first == FITCRC.compute(bytes))
    #expect(first != 0)
  }

  @Test func largeInputStable() {
    let bytes = [UInt8](repeating: 0, count: 65_536)
    #expect(FITCRC.compute(bytes) == 0)
  }

  @Test func pseudoRandomPayloadReproducible() {
    var rng: UInt32 = 0xDEAD_BEEF
    var bytes = [UInt8]()
    bytes.reserveCapacity(4096)
    for _ in 0..<4096 {
      rng = rng &* 1_664_525 &+ 1_013_904_223
      bytes.append(UInt8(truncatingIfNeeded: rng))
    }
    #expect(FITCRC.compute(bytes) == FITCRC.compute(bytes))
  }

  @Test func orderMatters() {
    #expect(FITCRC.compute([0x01, 0x02]) != FITCRC.compute([0x02, 0x01]))
  }
}
