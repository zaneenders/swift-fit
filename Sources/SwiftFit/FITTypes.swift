/// FIT file header (12 or 14 bytes).
public struct Header: Sendable {
  public let headerSize: UInt8
  public let protocolVersion: UInt8
  public let profileVersion: UInt16
  public let dataSize: UInt32
  public let signature: UInt32
  public let storedCRC: UInt16?

  /// CRC value stored in a 14-byte header, if present.
  public var crc: UInt16? { storedCRC }

  public init(
    headerSize: UInt8,
    protocolVersion: UInt8,
    profileVersion: UInt16,
    dataSize: UInt32,
    signature: UInt32,
    storedCRC: UInt16?
  ) {
    self.headerSize = headerSize
    self.protocolVersion = protocolVersion
    self.profileVersion = profileVersion
    self.dataSize = dataSize
    self.signature = signature
    self.storedCRC = storedCRC
  }

  /// Whether the on-disk header includes a CRC field (14-byte header).
  public var includesCRC: Bool { headerSize >= 14 }
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
  case bytes([UInt8])
  case sint64(Int64)
  case uint64(UInt64)
  case invalid
}
