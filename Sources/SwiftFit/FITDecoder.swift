/// Internal decoder for FIT data. Reads the header, definitions, data messages,
/// and trailing CRC from a byte buffer.
///
/// `~Copyable` ensures the decoder has unique ownership of its state throughout
/// the decode. This prevents accidental buffer duplication and enables the compiler
/// to eliminate retain/release traffic on the hot path.
struct FITDecoder: ~Copyable {
  /// The raw bytes. Stored as `[UInt8]` so Foundation-free callers can pass
  /// the buffer directly; the decoder borrows from it.
  let bytes: [UInt8]
  var cursor: Int = 0

  var header: Header = .init(
    headerSize: 0, protocolVersion: 0,
    profileVersion: 0, dataSize: 0,
    signature: 0, crc: nil)
  var fileCRC: UInt16 = 0
  var fileCRCComputed: UInt16 = 0
  var fileCRCValid: Bool = false

  /// Active definition messages keyed by local message type (0–15).
  var definitions: [UInt8: DefinitionMessage] = [:]
  /// Last timestamp message (for compressed timestamp headers). Not yet used.
  var lastTimeOffset: UInt32 = 0

  /// Create a decoder that takes ownership of `bytes`.
  init(bytes: consuming [UInt8]) {
    self.bytes = bytes
  }

  // MARK: - Byte access (inlined, borrows from buffer to avoid copies)

  /// Advance cursor and return the byte at the new position.
  @inline(__always)
  mutating func _readU8Advance() throws(FITError) -> UInt8 {
    guard cursor < bytes.count else { throw FITError.truncated }
    let b = bytes[cursor]
    cursor &+= 1
    return b
  }

  /// Read a little-endian `FixedWidthInteger` directly from the byte buffer
  /// without any intermediate heap allocation.
  @inline(__always)
  mutating func _readIntLE<T: FixedWidthInteger>(
    _ type: T.Type
  ) throws(FITError) -> T {
    let n = MemoryLayout<T>.size
    guard cursor &+ n <= bytes.count else { throw FITError.truncated }
    let value = unsafe bytes.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> T in
      unsafe buf.loadUnaligned(fromByteOffset: cursor, as: T.self)
    }
    cursor &+= n
    return value
  }

  /// Read a big-endian `FixedWidthInteger` directly from the byte buffer
  /// without any intermediate heap allocation.
  @inline(__always)
  mutating func _readIntBE<T: FixedWidthInteger>(
    _ type: T.Type
  ) throws(FITError) -> T {
    let n = MemoryLayout<T>.size
    guard cursor &+ n <= bytes.count else { throw FITError.truncated }
    let value = unsafe bytes.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> T in
      var v: T = 0
      for i in cursor..<(cursor &+ n) {
        v = (v << 8) | T(unsafe buf[i])
      }
      return v
    }
    cursor &+= n
    return value
  }

  @inline(__always)
  mutating func _readU16(_ bigEndian: Bool) throws(FITError) -> UInt16 {
    bigEndian ? try _readIntBE(UInt16.self) : try _readIntLE(UInt16.self)
  }
  @inline(__always)
  mutating func _readU32(_ bigEndian: Bool) throws(FITError) -> UInt32 {
    bigEndian ? try _readIntBE(UInt32.self) : try _readIntLE(UInt32.self)
  }

  // MARK: - Header

  mutating func readFileHeader() throws(FITError) {
    guard bytes.count >= 12 else { throw FITError.truncated }
    let headerSize = bytes[0]
    guard headerSize == 12 || headerSize == 14 else { throw FITError.truncated }
    cursor = 0
    let size = try _readU8Advance()
    let proto = try _readU8Advance()
    let profile = try _readU16(false)
    let dataSize = try _readU32(false)
    // ".FIT" stored little-endian as UInt32 == 0x5449462E.
    let signature = try _readIntLE(UInt32.self)
    guard signature == 0x5449_462E else {
      throw FITError.invalidHeaderSignature
    }

    var crc: UInt16? = nil
    if size >= 14 { crc = try _readU16(false) }
    self.header = Header(
      headerSize: size, protocolVersion: proto,
      profileVersion: profile, dataSize: dataSize,
      signature: signature, crc: crc)
    _ = proto
  }

  // MARK: - Messages

  mutating func readMessages() throws(FITError) -> [Message] {
    var messages: [Message] = []
    let end = cursor &+ Int(header.dataSize)
    guard end <= bytes.count else { throw FITError.truncated }
    while cursor < end {
      let recordHeader = try _readU8Advance()
      let isCompressed = (recordHeader & 0x80) != 0
      if isCompressed {
        // Compressed timestamp header (bit 7 = 1).
        //   bits 6–5:     local mesg type
        //   bits 4–0:     time offset
        let localMesgType = (recordHeader >> 5) & 0x03
        guard let def = definitions[localMesgType] else {
          throw FITError.invalidRecordHeader(recordHeader)
        }
        lastTimeOffset =
          (lastTimeOffset & 0xFFFF_FFE0)
          | UInt32(recordHeader & 0x1F)
        messages.append(try readDataMessage(def))
      } else {
        // Normal header (bit 7 = 0).
        //   bit 6:        mesg_type (1 = definition, 0 = data)
        //   bit 5:        developer data flag
        //   bits 3–0:     local mesg type
        let isDefinition = (recordHeader & 0x40) != 0
        let localMesgType = recordHeader & 0x0F
        let hasDevData = (recordHeader & 0x20) != 0
        if isDefinition {
          try readDefinitionMessage(
            localMesgType: localMesgType,
            hasDevData: hasDevData)
        } else {
          guard let def = definitions[localMesgType] else {
            throw FITError.invalidRecordHeader(recordHeader)
          }
          messages.append(try readDataMessage(def))
        }
      }
    }
    return messages
  }

  // MARK: Definition

  mutating func readDefinitionMessage(
    localMesgType: UInt8,
    hasDevData: Bool
  ) throws(FITError) {
    // Reserved byte
    _ = try _readU8Advance()
    let architecture = try _readU8Advance()
    guard architecture == 0 || architecture == 1 else {
      throw FITError.unsupportedArchitecture
    }
    let bigEndian = architecture == 1
    let globalMessageNumber = try _readU16(bigEndian)
    let nFields = try _readU8Advance()
    var fields: [FieldDefinition] = []
    fields.reserveCapacity(Int(nFields))
    for _ in 0..<nFields {
      let num = try _readU8Advance()
      let size = try _readU8Advance()
      let base = try _readU8Advance()
      let baseType = BaseType(rawValue: base) ?? .invalid
      fields.append(
        FieldDefinition(
          fieldDefinitionNumber: num,
          size: size, baseType: baseType))
    }
    var devFields: [FieldDefinition] = []
    if hasDevData {
      let nDev = try _readU8Advance()
      for _ in 0..<nDev {
        let num = try _readU8Advance()
        let size = try _readU8Advance()
        let base = try _readU8Advance()
        let baseType = BaseType(rawValue: base) ?? .invalid
        devFields.append(
          FieldDefinition(
            fieldDefinitionNumber: num,
            size: size, baseType: baseType))
      }
    }
    definitions[localMesgType] = DefinitionMessage(
      architecture: architecture,
      globalMessageNumber: globalMessageNumber,
      fields: fields,
      devFields: devFields
    )
  }

  // MARK: Data

  /// Read a data message. Field payloads are decoded by borrowing directly
  /// from the byte buffer — no intermediate `[UInt8]` copies on the hot path.
  mutating func readDataMessage(
    _ def: DefinitionMessage
  ) throws(FITError) -> Message {
    let bigEndian = def.architecture == 1
    var fields: [Field] = []
    fields.reserveCapacity(def.fields.count &+ def.devFields.count)
    for fd in def.fields {
      let size = Int(fd.size)
      guard cursor &+ size <= bytes.count else { throw FITError.truncated }
      let values = unsafe bytes.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> [Value] in
        unsafe decodeField(
          buf, from: cursor, size: size,
          baseType: fd.baseType, bigEndian: bigEndian)
      }
      cursor &+= size
      fields.append(
        Field(
          fieldDefinitionNumber: fd.fieldDefinitionNumber,
          baseType: fd.baseType, values: values))
    }
    // Developer field values are present whenever the active definition
    // declares dev fields, regardless of the data record's dev flag
    // (Apple Watch omits the flag while still writing the payload).
    for fd in def.devFields {
      let size = Int(fd.size)
      guard cursor &+ size <= bytes.count else { throw FITError.truncated }
      let values = unsafe bytes.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> [Value] in
        unsafe decodeField(
          buf, from: cursor, size: size,
          baseType: fd.baseType, bigEndian: bigEndian)
      }
      cursor &+= size
      fields.append(
        Field(
          fieldDefinitionNumber: fd.fieldDefinitionNumber,
          baseType: fd.baseType, values: values))
    }
    return Message(
      globalMessageNumber: def.globalMessageNumber,
      fields: fields)
  }
}
