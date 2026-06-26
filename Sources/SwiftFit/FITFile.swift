import Foundation

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
    public init(data: Data, validateCRC: Bool = false) throws {
        var decoder = FITDecoder(data: data)
        try decoder.readFileHeader()
        self.header = decoder.header
        self.messages = try decoder.readMessages()
        try decoder.readFileCRC()
        self.fileCRC = decoder.fileCRC
        self.fileCRCValid = decoder.fileCRCValid
        if validateCRC, !decoder.fileCRCValid {
            throw FITError.crcMismatch(expected: decoder.fileCRC,
                                       actual: decoder.fileCRCComputed)
        }
    }
}

/// FIT file header (12 or 14 bytes).
public struct Header: Sendable {
    public let headerSize: UInt8
    public let protocolVersion: UInt8
    public let profileVersion: UInt16
    public let dataSize: UInt32
    public let signature: UInt32
    public let crc: UInt16?

    public var isCRCValid: Bool { headerSize >= 14 }
}

/// A single FIT message: a definition plus its decoded values.
public struct Message: Sendable {
    public let globalMessageNumber: UInt16
    public let fields: [Field]
}

/// A single field within a message, decoded into native Swift values.
public struct Field: Sendable {
    public let fieldDefinitionNumber: UInt8
    public let baseType: BaseType
    public let values: [Value]
}

/// Typed value of a FIT field element.
public enum Value: Sendable, Equatable {
    case enumType(UInt8)
    case sint8(Int8)
    case uint8(UInt8)
    case sint16(Int16)
    case uint16(UInt16)
    case sint32(Int32)
    case uint32(UInt32)
    case string(String)
    case float32(Float)
    case float64(Double)
    case uint8z(UInt8)
    case uint16z(UInt16)
    case uint32z(UInt32)
    case byte(UInt8)
    case sint64(Int64)
    case uint64(UInt64)
    case invalid
}