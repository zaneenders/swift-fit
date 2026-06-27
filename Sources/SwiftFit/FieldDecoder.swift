/// Decode the bytes for a field into an array of `Value`s. Fields may
/// contain arrays (size is a multiple of the base type's element size).
///
/// Uses `bytes.withUnsafeBytes` to borrow a raw pointer from the decoder's
/// `[UInt8]` buffer — this avoids per-element bounds checks and intermediate
/// heap copies. The decoder bounds-checks `cursor + size` before every call,
/// so the pointer access is safe.
///
/// Dispatches once per base-type so the inner element loop is branch-free
/// (mirroring the reference interpreter's approach of one `@inline(always)`
/// function per opcode).
@inline(__always)
func decodeField(
  _ bytes: borrowing [UInt8],
  from offset: Int,
  size: Int,
  baseType: BaseType,
  bigEndian: Bool
) -> [Value] {
  guard size > 0, baseType != .invalid else { return [.invalid] }
  if baseType == .string {
    return [.string(decodeFITString(bytes, from: offset, size: size))]
  }
  let elemSize = baseType.size
  guard elemSize > 0 else { return [.invalid] }
  let count = size / elemSize
  guard count > 0 else { return [.invalid] }

  // Borrow a raw pointer once for the entire field decode.
  return unsafe bytes.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> [Value] in
    // Local loaders — unchecked, proven in-bounds by caller's guard.
    // No @inline needed: the outer function is @inline(__always), so these
    // are inlined automatically when the call site is monomorphised.
    func u8(_ at: Int) -> UInt8 { buf[offset &+ at] }
    func u16(_ at: Int) -> UInt16 {
      let o = offset &+ at
      return bigEndian
        ? (UInt16(buf[o]) << 8) | UInt16(buf[o &+ 1])
        : (UInt16(buf[o &+ 1]) << 8) | UInt16(buf[o])
    }
    func u32(_ at: Int) -> UInt32 {
      let raw = buf.loadUnaligned(fromByteOffset: offset &+ at, as: UInt32.self)
      return bigEndian ? raw.byteSwapped : raw
    }
    func u64(_ at: Int) -> UInt64 {
      let raw = buf.loadUnaligned(fromByteOffset: offset &+ at, as: UInt64.self)
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
}

/// Decode a null-terminated FIT string from a buffer slice.
///
/// The caller guarantees `offset + size` is within bounds.
@inline(__always)
func decodeFITString(
  _ bytes: borrowing [UInt8], from offset: Int, size: Int
) -> String {
  // Find the effective end (trim trailing nuls).
  var end = offset &+ size
  while end > offset, bytes[end &- 1] == 0 { end &-= 1 }
  guard end > offset else { return "" }
  // Copy non-nul bytes into a contiguous UTF-8 buffer.
  var cleaned: [UInt8] = []
  cleaned.reserveCapacity(end &- offset)
  for i in offset..<end {
    let b = bytes[i]
    if b != 0 { cleaned.append(b) }
  }
  return String(decoding: cleaned, as: UTF8.self)
}
