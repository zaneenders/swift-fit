import Foundation
import Testing

@testable import SwiftFit

@Suite struct FITCRCTests {
  @Test func emptyInput() {
    #expect(FITCRC.compute(Data()) == 0)
  }

  // "123456789" should produce 0x31C3 for CCITT-0 (poly 0x1021, init 0).
  @Test func standardCheck() {
    let bytes: [UInt8] = Array("123456789".utf8)
    #expect(FITCRC.compute(bytes) == 0x31C3)
  }

  @Test func tableMatchesByteWise() {
    let data = Data([0x00, 0x01, 0x02, 0xFF, 0x10, 0x42])
    var crc: UInt16 = 0
    for b in data {
      let idx = Int((crc >> 8) ^ UInt16(b)) & 0xFF
      crc = (crc << 8) ^ FITCRC.table[idx]
    }
    #expect(crc == FITCRC.compute(data))
  }

  // Known-answer vectors for CRC-16/XMODEM (poly 0x1021, seed 0, no final XOR).
  // "123456789" check value 0x31C3 per the CRC catalogue.
  @Test(arguments: [
    ([UInt8](), UInt16(0x0000)),
    ([0x00], UInt16(0x0000)),
    (Array("123456789".utf8), UInt16(0x31C3)),
    (Array("The quick brown fox jumps over the lazy dog".utf8), UInt16(0xF0C8)),
  ])
  func knownVectors(bytes: [UInt8], expected: UInt16) {
    #expect(FITCRC.compute(bytes) == expected)
  }

  // Single-byte CRC equals table[byte] (since seed is 0).
  @Test(arguments: [UInt8(0x00), 0x01, 0x7F, 0x80, 0xFF])
  func singleByteMatchesTableEntry(byte: UInt8) {
    #expect(FITCRC.compute([byte]) == FITCRC.table[Int(byte)])
  }

  @Test func tableHas256Entries() {
    #expect(FITCRC.table.count == 256)
  }

  @Test func tableEntryZeroIsEmpty() {
    #expect(FITCRC.table[0] == 0)
  }

  @Test func tableIsCachedSingleton() {
    let a = FITCRC.table
    let b = FITCRC.table
    #expect(a.count == b.count)
    #expect(a == b)
  }

  @Test func tableEntriesMatchDefinition() {
    for i in 0..<256 {
      var crc = UInt16(i) << 8
      for _ in 0..<8 {
        if (crc & 0x8000) != 0 {
          crc = (crc << 1) ^ 0x1021
        } else {
          crc <<= 1
        }
      }
      #expect(FITCRC.table[i] == crc, "table[\(i)] mismatch")
    }
  }

  @Test func worksWithArraySequence() {
    let bytes: [UInt8] = Array("123456789".utf8)
    #expect(FITCRC.compute(bytes) == 0x31C3)
  }

  @Test func worksWithAnySequence() {
    let lazy = AnySequence(Array("123456789".utf8))
    #expect(FITCRC.compute(lazy) == 0x31C3)
  }

  @Test func worksWithSlice() {
    let full: [UInt8] = Array("XYZ123456789ABC".utf8)
    let slice = full[3..<12]
    #expect(FITCRC.compute(slice) == 0x31C3)
  }

  @Test func appendingChangesCRC() {
    let base: [UInt8] = [0x10, 0x20, 0x30]
    let a = FITCRC.compute(base)
    let b = FITCRC.compute(base + [0x40])
    #expect(a != b)
  }

  @Test func repeatedByteIsDeterministic() {
    let bytes = [UInt8](repeating: 0xAA, count: 16)
    let first = FITCRC.compute(bytes)
    let second = FITCRC.compute(bytes)
    #expect(first == second)
    #expect(first != 0)
  }

  @Test func largeInputStable() {
    let bytes = [UInt8](repeating: 0, count: 65_536)
    let first = FITCRC.compute(bytes)
    let second = FITCRC.compute(bytes)
    #expect(first == second)
    // CRC of all-zero input of any length equals 0 with seed 0.
    #expect(first == 0)
  }

  @Test func pseudoRandomPayloadReproducible() {
    var rng: UInt32 = 0xDEAD_BEEF
    var bytes = [UInt8]()
    bytes.reserveCapacity(4096)
    for _ in 0..<4096 {
      rng = rng &* 1_664_525 &+ 1_013_904_223
      bytes.append(UInt8(truncatingIfNeeded: rng))
    }
    let first = FITCRC.compute(bytes)
    let second = FITCRC.compute(bytes)
    #expect(first == second)
  }

  @Test func orderMatters() {
    let a: [UInt8] = [0x01, 0x02]
    let b: [UInt8] = [0x02, 0x01]
    #expect(FITCRC.compute(a) != FITCRC.compute(b))
  }
}
