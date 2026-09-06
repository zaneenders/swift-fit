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
    let raw = unsigned(at, byteCount: elementSize)
    if raw == baseType.invalidValue {
      result.append(.invalid)
      continue
    }
    switch baseType {
    case .enumType: result.append(.enumType(UInt8(unsigned(at, byteCount: 1))))
    case .sint8: result.append(.sint8(Int8(bitPattern: UInt8(unsigned(at, byteCount: 1)))))
    case .uint8: result.append(.uint8(UInt8(unsigned(at, byteCount: 1))))
    case .uint8z: result.append(.uint8z(UInt8(unsigned(at, byteCount: 1))))
    case .byte: result.append(.byte(UInt8(unsigned(at, byteCount: 1))))
    case .sint16:
      result.append(.sint16(Int16(bitPattern: UInt16(unsigned(at, byteCount: 2)))))
    case .uint16: result.append(.uint16(UInt16(unsigned(at, byteCount: 2))))
    case .uint16z: result.append(.uint16z(UInt16(unsigned(at, byteCount: 2))))
    case .sint32:
      result.append(.sint32(Int32(bitPattern: UInt32(unsigned(at, byteCount: 4)))))
    case .uint32: result.append(.uint32(UInt32(unsigned(at, byteCount: 4))))
    case .uint32z: result.append(.uint32z(UInt32(unsigned(at, byteCount: 4))))
    case .float32:
      result.append(.float32(Float(bitPattern: UInt32(raw))))
    case .float64:
      result.append(.float64(Double(bitPattern: raw)))
    case .sint64: result.append(.sint64(Int64(bitPattern: unsigned(at, byteCount: 8))))
    case .uint64: result.append(.uint64(unsigned(at, byteCount: 8)))
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
