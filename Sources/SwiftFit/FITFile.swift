/// Errors that can occur when parsing a FIT file.
public enum FITError: Error, Equatable {
  case invalidHeaderSignature
  case truncated
  case unsupportedArchitecture
  case invalidRecordHeader(UInt8)
  case invalidBaseType(UInt8)
  case crcMismatch(expected: UInt16, actual: UInt16)
  case headerCRCMismatch(expected: UInt16, actual: UInt16)
}

/// Errors that can occur when writing a FIT file.
public enum FITWriterError: Error, Equatable {
  case unknownLocalType(UInt8)
  case tooManyLocalTypes
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
  /// `true` if the header CRC matches the CRC computed over the first 12 bytes.
  /// Always `false` for 12-byte headers.
  public let headerCRCValid: Bool
  /// Parsed `developer_data_id` messages keyed by developer data index.
  public let developerDataIDs: [UInt8: DeveloperDataID]
  /// Parsed `developer_data_definition` messages keyed by index + field number.
  public let developerFieldDefinitions: [DeveloperFieldKey: DeveloperFieldDefinition]

  /// Decode a FIT file from raw bytes.
  public init(
    bytes: consuming [UInt8],
    options: FITDecodeOptions = FITDecodeOptions()
  ) throws(FITError) {
    var decoder = FITDecoder(bytes: bytes, options: options)
    try decoder.readFileHeader()
    if options.validateHeaderCRC, !decoder.headerCRCValid {
      throw FITError.headerCRCMismatch(
        expected: decoder.header.storedCRC ?? 0,
        actual: decoder.headerCRCComputed)
    }
    self.header = decoder.header
    self.messages = try decoder.readMessages()
    try decoder.readFileCRC()
    self.fileCRC = decoder.fileCRC
    self.fileCRCValid = decoder.fileCRCValid
    self.headerCRCValid = decoder.headerCRCValid
    self.developerDataIDs = DeveloperDataParser.developerDataIDs(from: self.messages)
    self.developerFieldDefinitions = DeveloperDataParser.developerFieldDefinitions(
      from: self.messages)
    if options.validateFileCRC, !decoder.fileCRCValid {
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
  public init(data: Data, options: FITDecodeOptions = FITDecodeOptions()) throws(FITError) {
    try self.init(bytes: Array(data), options: options)
  }
}
#endif
