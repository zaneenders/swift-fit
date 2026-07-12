/// FIT CRC-16 implementation. Uses polynomial 0x1021 (CCITT), seed 0,
/// bit order MSB-first (matching the Garmin FIT SDK reference).
enum FITCRC {
  static let table: [UInt16] = {
    var t = [UInt16](repeating: 0, count: 256)
    for i in 0..<256 {
      var crc = UInt16(i) << 8
      for _ in 0..<8 {
        if (crc & 0x8000) != 0 {
          crc = (crc << 1) ^ 0x1021
        } else {
          crc <<= 1
        }
      }
      t[i] = crc
    }
    return t
  }()

  /// Compute the FIT CRC-16 over the given bytes.
  static func compute(_ bytes: some Sequence<UInt8>) -> UInt16 {
    var crc: UInt16 = 0
    for byte in bytes {
      let idx = Int((crc >> 8) ^ UInt16(byte)) & 0xFF
      crc = (crc << 8) ^ table[idx]
    }
    return crc
  }
}

extension FITDecoder {
  /// Read and verify the trailing file CRC (2 bytes after header + data).
  mutating func readFileCRC() throws(FITError) {
    let crcStart = Int(header.headerSize) &+ Int(header.dataSize)
    guard crcStart &+ 2 <= bytes.count else { throw FITError.truncated }
    cursor = crcStart
    fileCRC = try _readU16(false)
    fileCRCComputed = FITCRC.compute(bytes[0..<crcStart])
    fileCRCValid = (fileCRCComputed == fileCRC)
    // Mismatch is not fatal: some producers (e.g. Apple Watch) write
    // non-standard CRCs while the message structure is otherwise valid.
  }
}
