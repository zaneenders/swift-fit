public struct FITWriter: Sendable {
  private var data: [UInt8] = []
  private var nextLocalType: UInt8 = 0
  private var definitions: [LocalTypeDef] = []
  private var lastTimestamp: UInt32 = 0

  /// Profile version written into the header. Defaults to 8468 (21.20).
  public var profileVersion: UInt16 = 8468
  /// Protocol version written into the header. Defaults to 0x10 (1.0).
  public var protocolVersion: UInt8 = 0x10
  /// When `true`, consecutive data messages may use compressed timestamp headers.
  public var useCompressedTimestamps: Bool = true

  /// Create a new FIT writer.
  public init() {}

  // MARK: - Definition

  /// Register a definition message and return its local message type handle.
  /// Up to 16 local types (0–15) are supported.
  @discardableResult
  public mutating func define(
    globalMessageNumber: UInt16,
    fields: [(number: UInt8, size: Int, baseType: BaseType)] = [],
    developerFields: [(number: UInt8, size: Int, baseType: BaseType)] = []
  ) throws(FITWriterError) -> UInt8 {
    guard nextLocalType <= 15 else { throw FITWriterError.tooManyLocalTypes }
    let local = nextLocalType
    nextLocalType &+= 1

    let hasDev = !developerFields.isEmpty
    let hdr: UInt8 = 0b0100_0000 | (hasDev ? 0x20 : 0x00) | (local & 0x0F)
    data.append(hdr)
    data.append(0x00)  // reserved
    data.append(0x00)  // architecture: little-endian
    appendUInt16LE(globalMessageNumber)
    data.append(UInt8(fields.count))

    for (num, size, baseType) in fields {
      data.append(num)
      data.append(UInt8(size))
      data.append(baseType.rawValue)
    }

    if hasDev {
      data.append(UInt8(developerFields.count))
      for (num, size, baseType) in developerFields {
        data.append(num)
        data.append(UInt8(size))
        data.append(baseType.rawValue)
      }
    }

    definitions.append(
      LocalTypeDef(
        local: local,
        globalMessageNumber: globalMessageNumber,
        fields: fields,
        devFields: developerFields
      ))

    return local
  }

  // MARK: - Data

  /// Write a data message for the given local message type.
  public mutating func write(localType: UInt8, values: [Value]) throws(FITWriterError) {
    guard let def = definitions.first(where: { $0.local == localType }) else {
      throw FITWriterError.unknownLocalType(localType)
    }

    if useCompressedTimestamps,
      localType <= 3,
      let timestampIndex = def.fields.firstIndex(where: { $0.number == FITField.timestamp }),
      timestampIndex < values.count,
      case .uint32(let timestamp) = values[timestampIndex],
      lastTimestamp != 0,
      (timestamp & 0xFFFF_FFE0) == (lastTimestamp & 0xFFFF_FFE0)
    {
      let offset = UInt8(timestamp & 0x1F)
      let hdr: UInt8 = 0x80 | ((localType & 0x03) << 5) | offset
      data.append(hdr)
      writeFieldValues(def: def, values: values, skipTimestamp: true)
      lastTimestamp = timestamp
      return
    }

    let hdr: UInt8 = (localType & 0x0F)
    data.append(hdr)
    writeFieldValues(def: def, values: values, skipTimestamp: false)
    if let timestampIndex = def.fields.firstIndex(where: { $0.number == FITField.timestamp }),
      timestampIndex < values.count,
      case .uint32(let timestamp) = values[timestampIndex]
    {
      lastTimestamp = timestamp
    }
  }

  // MARK: - Finish

  /// Finalise the file, returning the complete FIT file bytes (header + data + CRC).
  public consuming func finish() -> [UInt8] {
    let dataSize = UInt32(data.count)

    var header: [UInt8] = []
    header.reserveCapacity(14)
    header.append(14)
    header.append(protocolVersion)
    header.append(UInt8(profileVersion & 0xFF))
    header.append(UInt8((profileVersion >> 8) & 0xFF))
    writeUInt32LE(dataSize, to: &header)
    header.append(0x2E)
    header.append(0x46)
    header.append(0x49)
    header.append(0x54)

    let headerCRC = FITCRC.compute(header.prefix(12))
    header.append(UInt8(headerCRC & 0xFF))
    header.append(UInt8((headerCRC >> 8) & 0xFF))

    var file: [UInt8] = []
    file.reserveCapacity(header.count &+ data.count &+ 2)
    file.append(contentsOf: header)
    file.append(contentsOf: data)

    let fileCRC = FITCRC.compute(file)
    file.append(UInt8(fileCRC & 0xFF))
    file.append(UInt8((fileCRC >> 8) & 0xFF))

    return file
  }

  // MARK: - Internal helpers

  private mutating func writeFieldValues(
    def: LocalTypeDef,
    values: [Value],
    skipTimestamp: Bool
  ) {
    var valueIndex = 0
    for field in def.fields {
      if skipTimestamp, field.number == FITField.timestamp {
        valueIndex &+= 1
        continue
      }
      let value = valueIndex < values.count ? values[valueIndex] : .invalid
      encodeValue(value, size: field.size)
      valueIndex &+= 1
    }
    for field in def.devFields {
      let value = valueIndex < values.count ? values[valueIndex] : .invalid
      encodeValue(value, size: field.size)
      valueIndex &+= 1
    }
  }

  private mutating func appendUInt16LE(_ value: UInt16) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
  }

  private func writeUInt32LE(_ value: UInt32, to buf: inout [UInt8]) {
    buf.append(UInt8(value & 0xFF))
    buf.append(UInt8((value >> 8) & 0xFF))
    buf.append(UInt8((value >> 16) & 0xFF))
    buf.append(UInt8((value >> 24) & 0xFF))
  }

  private mutating func appendUInt32LE(_ value: UInt32) {
    writeUInt32LE(value, to: &data)
  }

  private mutating func appendUInt64LE(_ value: UInt64) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
    data.append(UInt8((value >> 16) & 0xFF))
    data.append(UInt8((value >> 24) & 0xFF))
    data.append(UInt8((value >> 32) & 0xFF))
    data.append(UInt8((value >> 40) & 0xFF))
    data.append(UInt8((value >> 48) & 0xFF))
    data.append(UInt8((value >> 56) & 0xFF))
  }

  private mutating func encodeValue(_ value: Value, size: Int) {
    switch value {
    case .enumType(let v): data.append(v)
    case .uint8(let v): data.append(v)
    case .uint8z(let v): data.append(v)
    case .byte(let v): data.append(v)
    case .bytes(let bytes):
      for i in 0..<size {
        data.append(i < bytes.count ? bytes[i] : 0xFF)
      }
    case .sint8(let v): data.append(UInt8(bitPattern: v))
    case .uint16(let v): appendUInt16LE(v)
    case .uint16z(let v): appendUInt16LE(v)
    case .sint16(let v): appendUInt16LE(UInt16(bitPattern: v))
    case .uint32(let v): appendUInt32LE(v)
    case .uint32z(let v): appendUInt32LE(v)
    case .sint32(let v): appendUInt32LE(UInt32(bitPattern: v))
    case .float32(let v): appendUInt32LE(v.bitPattern)
    case .float64(let v): appendUInt64LE(v.bitPattern)
    case .uint64(let v): appendUInt64LE(v)
    case .sint64(let v): appendUInt64LE(UInt64(bitPattern: v))
    case .string(let s):
      var strData = [UInt8](s.utf8)
      strData.append(0)
      while strData.count < size { strData.append(0) }
      data.append(contentsOf: strData.prefix(size))
    case .invalid:
      for _ in 0..<size { data.append(0xFF) }
    }
  }
}

/// Internal: stored definition for a local message type.
private struct LocalTypeDef: Sendable {
  let local: UInt8
  let globalMessageNumber: UInt16
  let fields: [(number: UInt8, size: Int, baseType: BaseType)]
  let devFields: [(number: UInt8, size: Int, baseType: BaseType)]
}

// MARK: - Foundation convenience

#if canImport(Foundation)
import Foundation

extension FITWriter {
  /// Finalise and return `Data` instead of `[UInt8]`.
  public consuming func finishData() -> Data {
    Data(finish())
  }
}
#endif
