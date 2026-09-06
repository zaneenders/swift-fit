/// Decode the bytes for a field into an array of `Value`s. Fields may
/// contain arrays (size is a multiple of the base type's element size).
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
  let elementSize = baseType.size
  guard elementSize > 0 else { return [.invalid] }
  let count = size / elementSize
  guard count > 0 else { return [.invalid] }

  func unsigned(_ at: Int, byteCount: Int) -> UInt64 {
    var value: UInt64 = 0
    if bigEndian {
      for index in 0..<byteCount {
        value = (value << 8) | UInt64(bytes[offset &+ at &+ index])
      }
    } else {
      for index in 0..<byteCount {
        value |= UInt64(bytes[offset &+ at &+ index]) << UInt64(index &* 8)
      }
    }
    return value
  }

  var result: [Value] = []
  result.reserveCapacity(count)
  for index in 0..<count {
    let at = index &* elementSize
    switch baseType {
    case .enumType:
      let raw = UInt8(unsigned(at, byteCount: 1))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .enumType(raw))
    case .sint8:
      let raw = UInt8(unsigned(at, byteCount: 1))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .sint8(Int8(bitPattern: raw)))
    case .uint8:
      let raw = UInt8(unsigned(at, byteCount: 1))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .uint8(raw))
    case .uint8z:
      let raw = UInt8(unsigned(at, byteCount: 1))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .uint8z(raw))
    case .byte:
      let raw = UInt8(unsigned(at, byteCount: 1))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .byte(raw))
    case .sint16:
      let raw = UInt16(unsigned(at, byteCount: 2))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .sint16(Int16(bitPattern: raw)))
    case .uint16:
      let raw = UInt16(unsigned(at, byteCount: 2))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .uint16(raw))
    case .uint16z:
      let raw = UInt16(unsigned(at, byteCount: 2))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .uint16z(raw))
    case .sint32:
      let raw = UInt32(unsigned(at, byteCount: 4))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .sint32(Int32(bitPattern: raw)))
    case .uint32:
      let raw = UInt32(unsigned(at, byteCount: 4))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .uint32(raw))
    case .uint32z:
      let raw = UInt32(unsigned(at, byteCount: 4))
      result.append(UInt64(raw) == baseType.invalidValue ? .invalid : .uint32z(raw))
    case .float32:
      let raw = UInt32(unsigned(at, byteCount: 4))
      result.append(raw == 0xFFFF_FFFF ? .invalid : .float32(Float(bitPattern: raw)))
    case .float64:
      let raw = unsigned(at, byteCount: 8)
      result.append(raw == 0xFFFF_FFFF_FFFF_FFFF ? .invalid : .float64(Double(bitPattern: raw)))
    case .sint64:
      let raw = unsigned(at, byteCount: 8)
      result.append(raw == baseType.invalidValue ? .invalid : .sint64(Int64(bitPattern: raw)))
    case .uint64:
      let raw = unsigned(at, byteCount: 8)
      result.append(raw == baseType.invalidValue ? .invalid : .uint64(raw))
    case .string, .invalid: result.append(.invalid)
    }
  }
  return result
}

/// Decode a null-terminated FIT string from a buffer slice.
///
/// The caller guarantees `offset + size` is within bounds.
@inline(__always)
func decodeFITString(
  _ bytes: borrowing [UInt8], from offset: Int, size: Int
) -> String {
  var end = offset &+ size
  while end > offset, bytes[end &- 1] == 0 { end &-= 1 }
  guard end > offset else { return "" }
  var cleaned: [UInt8] = []
  cleaned.reserveCapacity(end &- offset)
  for index in offset..<end {
    let byte = bytes[index]
    if byte != 0 { cleaned.append(byte) }
  }
  return String(decoding: cleaned, as: UTF8.self)
}
