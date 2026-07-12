/// Errors that can occur when parsing a FIT file.
public enum FITError: Error, Equatable {
  case invalidHeaderSignature
  case truncated
  case unsupportedArchitecture
  case invalidRecordHeader(UInt8)
  case crcMismatch(expected: UInt16, actual: UInt16)
}

/// A decoded FIT file.
public struct FITFile: Sendable {
  public let header: Header
  public let messages: [Message]
  public let fileCRC: UInt16
  /// `true` if the trailing file CRC matches the CRC computed over the
  /// header + data. Some producers (e.g. Apple Watch) write non-standard
  /// CRCs, so a `false` value does not imply a corrupt structure.
  public let fileCRCValid: Bool

  /// Decode a FIT file from raw bytes.
  /// - Parameter validateCRC: When `true`, throw `.crcMismatch` if the
  ///   trailing CRC does not verify. Defaults to `false` so that files with
  ///   non-standard CRCs but valid structure can still be read.
  public init(bytes: consuming [UInt8], validateCRC: Bool = false) throws(FITError) {
    var decoder = FITDecoder(bytes: bytes)
    try decoder.readFileHeader()
    self.header = decoder.header
    self.messages = try decoder.readMessages()
    try decoder.readFileCRC()
    self.fileCRC = decoder.fileCRC
    self.fileCRCValid = decoder.fileCRCValid
    if validateCRC, !decoder.fileCRCValid {
      throw FITError.crcMismatch(
        expected: decoder.fileCRC,
        actual: decoder.fileCRCComputed)
    }
  }
}

#if canImport(Foundation)
import Foundation

extension FITFile {
  /// Decode a FIT file from `Data` when Foundation is available.
  public init(data: Data, validateCRC: Bool = false) throws(FITError) {
    try self.init(bytes: Array(data), validateCRC: validateCRC)
  }
}
#endif
