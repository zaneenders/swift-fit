extension Message {
  /// Returns the field with the given definition number, if present.
  public func field(number: UInt8) -> Field? {
    fields.first { $0.fieldDefinitionNumber == number }
  }

  /// Returns the first decoded value for the given field number.
  public func firstValue(number: UInt8) -> Value? {
    field(number: number)?.values.first
  }

  public func uint8Field(number: UInt8) -> UInt8? {
    guard let value = firstValue(number: number) else { return nil }
    switch value {
    case .uint8(let v), .uint8z(let v), .enumType(let v), .byte(let v): return v
    default: return nil
    }
  }

  public func uint16Field(number: UInt8) -> UInt16? {
    guard let value = firstValue(number: number) else { return nil }
    switch value {
    case .uint16(let v), .uint16z(let v): return v
    default: return nil
    }
  }

  public func uint32Field(number: UInt8) -> UInt32? {
    guard let value = firstValue(number: number) else { return nil }
    switch value {
    case .uint32(let v), .uint32z(let v): return v
    default: return nil
    }
  }

  public func sint32Field(number: UInt8) -> Int32? {
    guard let value = firstValue(number: number) else { return nil }
    switch value {
    case .sint32(let v): return v
    default: return nil
    }
  }

  public func enumField(number: UInt8) -> UInt8? {
    uint8Field(number: number)
  }

  public func stringField(number: UInt8) -> String? {
    guard let value = firstValue(number: number) else { return nil }
    if case .string(let text) = value {
      let trimmed = Self.trimWhitespace(text)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }

  private static func trimWhitespace(_ text: String) -> String {
    var start = text.startIndex
    var end = text.endIndex
    while start < end, text[start].isWhitespace {
      start = text.index(after: start)
    }
    while end > start {
      let prior = text.index(before: end)
      if !text[prior].isWhitespace { break }
      end = prior
    }
    return String(text[start..<end])
  }
}
