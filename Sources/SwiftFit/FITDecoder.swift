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
  private mutating func _readU8Advance() throws(FITError) -> UInt8 {
    guard cursor < bytes.count else { throw FITError.truncated }
    let b = bytes[cursor]
    cursor &+= 1
    return b
  }

  /// Read a little-endian `FixedWidthInteger` directly from the byte buffer
  /// without any intermediate heap allocation.
  @inline(__always)
  private mutating func _readIntLE<T: FixedWidthInteger>(
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
  private mutating func _readIntBE<T: FixedWidthInteger>(
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
  private mutating func _readU16(_ bigEndian: Bool) throws(FITError) -> UInt16 {
    bigEndian ? try _readIntBE(UInt16.self) : try _readIntLE(UInt16.self)
  }
  @inline(__always)
  private mutating func _readU32(_ bigEndian: Bool) throws(FITError) -> UInt32 {
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

  private mutating func readDefinitionMessage(
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
  private mutating func readDataMessage(
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

// MARK: - Field decoding (free functions to keep decodeField borrow-scoped)

/// Decode the bytes for a field into an array of `Value`s. Fields may
/// contain arrays (size is a multiple of the base type's element size).
///
/// Operates on an `UnsafeRawBufferPointer` borrowed from the decoder's byte
/// buffer to avoid heap-allocating an intermediate `[UInt8]` for every field.
///
/// Dispatches once per base-type so the inner element loop is branch-free
/// (mirroring the reference interpreter's approach of one `@inline(always)`
/// function per opcode).
///
/// # Safety
/// Caller must ensure `buf` is valid for reads of at least `offset + size` bytes.
@inline(__always)
private func decodeField(
  _ buf: borrowing UnsafeRawBufferPointer,
  from offset: Int,
  size: Int,
  baseType: BaseType,
  bigEndian: Bool
) -> [Value] {
  guard size > 0, baseType != .invalid else { return [.invalid] }
  if baseType == .string {
    return [.string(unsafe decodeFITString(buf, from: offset, size: size))]
  }
  let elemSize = baseType.size
  guard elemSize > 0 else { return [.invalid] }
  let count = size / elemSize
  guard count > 0 else { return [.invalid] }

  // Local loaders that index relative to the slice origin.
  @inline(__always)
  func u8(_ at: Int) -> UInt8 { unsafe buf[offset &+ at] }
  @inline(__always)
  func u16(_ at: Int) -> UInt16 {
    let o = offset &+ at
    return bigEndian
      ? (UInt16(unsafe buf[o]) << 8) | UInt16(unsafe buf[o &+ 1])
      : (UInt16(unsafe buf[o &+ 1]) << 8) | UInt16(unsafe buf[o])
  }
  @inline(__always)
  func u32(_ at: Int) -> UInt32 {
    // Load as little-endian into a UInt32, then byte-swap if big-endian.
    let raw = unsafe buf.loadUnaligned(fromByteOffset: offset &+ at, as: UInt32.self)
    return bigEndian ? raw.byteSwapped : raw
  }
  @inline(__always)
  func u64(_ at: Int) -> UInt64 {
    let raw = unsafe buf.loadUnaligned(fromByteOffset: offset &+ at, as: UInt64.self)
    return bigEndian ? raw.byteSwapped : raw
  }

  // Dispatch once, loop branch-free inside.
  var result: [Value] = []
  result.reserveCapacity(count)
  switch baseType {
  case .enumType:
    for i in 0..<count { result.append(.enumType(u8(i))) }
  case .sint8:
    for i in 0..<count { result.append(.sint8(Int8(bitPattern: u8(i)))) }
  case .uint8:
    for i in 0..<count { result.append(.uint8(u8(i))) }
  case .uint8z:
    for i in 0..<count { result.append(.uint8z(u8(i))) }
  case .byte:
    for i in 0..<count { result.append(.byte(u8(i))) }
  case .sint16:
    for i in 0..<count { result.append(.sint16(Int16(bitPattern: u16(i &* 2)))) }
  case .uint16:
    for i in 0..<count { result.append(.uint16(u16(i &* 2))) }
  case .uint16z:
    for i in 0..<count { result.append(.uint16z(u16(i &* 2))) }
  case .sint32:
    for i in 0..<count { result.append(.sint32(Int32(bitPattern: u32(i &* 4)))) }
  case .uint32:
    for i in 0..<count { result.append(.uint32(u32(i &* 4))) }
  case .uint32z:
    for i in 0..<count { result.append(.uint32z(u32(i &* 4))) }
  case .float32:
    for i in 0..<count {
      let v = Float(bitPattern: u32(i &* 4))
      result.append(v.bitPattern == 0xFFFF_FFFF ? .invalid : .float32(v))
    }
  case .float64:
    for i in 0..<count {
      let v = Double(bitPattern: u64(i &* 8))
      result.append(v.bitPattern == 0xFFFF_FFFF_FFFF_FFFF ? .invalid : .float64(v))
    }
  case .sint64:
    for i in 0..<count { result.append(.sint64(Int64(bitPattern: u64(i &* 8)))) }
  case .uint64:
    for i in 0..<count { result.append(.uint64(u64(i &* 8))) }
  case .string, .invalid:
    for _ in 0..<count { result.append(.invalid) }
  }
  return result
}

/// Decode a null-terminated FIT string from a buffer slice.
///
/// # Safety
/// Caller must ensure `buf` is valid for reads of at least `offset + size` bytes.
@inline(__always)
private func decodeFITString(
  _ buf: borrowing UnsafeRawBufferPointer, from offset: Int, size: Int
) -> String {
  // Find the effective end (trim trailing nuls).
  var end = offset &+ size
  while end > offset, unsafe buf[end &- 1] == 0 { end &-= 1 }
  guard end > offset else { return "" }
  // Copy non-nul bytes into a contiguous UTF-8 buffer.
  var cleaned: [UInt8] = []
  cleaned.reserveCapacity(end &- offset)
  for i in offset..<end {
    let b = unsafe buf[i]
    if b != 0 { cleaned.append(b) }
  }
  return String(decoding: cleaned, as: UTF8.self)
}

// MARK: - CRC

extension FITDecoder {
  mutating func readFileCRC() throws(FITError) {
    // Two trailing bytes: CRC of everything before them (header + data).
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
