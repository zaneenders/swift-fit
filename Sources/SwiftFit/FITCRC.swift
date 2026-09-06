/// Garmin FIT CRC-16 implementation. FIT uses the reflected 0xA001
/// polynomial, an initial value of zero, and no final XOR.
enum FITCRC {
  private static let nibbleTable: [UInt16] = [
    0x0000, 0xCC01, 0xD801, 0x1400,
    0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401,
    0x5000, 0x9C01, 0x8801, 0x4400,
  ]

  /// Compute the FIT CRC-16 over the given bytes.
  static func compute(_ bytes: some Sequence<UInt8>) -> UInt16 {
    var crc: UInt16 = 0
    for byte in bytes {
      var temporary = nibbleTable[Int(crc & 0x0F)]
      crc = (crc >> 4) & 0x0FFF
      crc ^= temporary ^ nibbleTable[Int(byte & 0x0F)]

      temporary = nibbleTable[Int(crc & 0x0F)]
      crc = (crc >> 4) & 0x0FFF
      crc ^= temporary ^ nibbleTable[Int((byte >> 4) & 0x0F)]
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
