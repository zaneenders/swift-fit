/// FIT base types as defined by the FIT protocol.
public enum BaseType: UInt8, Sendable {
    case enumType  = 0x00
    case sint8     = 0x01
    case uint8     = 0x02
    case sint16    = 0x83 // 0x03 with endianness bit
    case uint16    = 0x84 // 0x04 with endianness bit
    case sint32    = 0x85
    case uint32    = 0x86
    case string    = 0x07
    case float32   = 0x88
    case float64   = 0x89
    case uint8z    = 0x0A
    case uint16z   = 0x8B
    case uint32z   = 0x8C
    case byte      = 0x0D
    case sint64    = 0x8E
    case uint64    = 0x8F
    case invalid   = 0xFF

    /// The size in bytes of a single element of this base type.
    @inline(__always)
    public var size: Int {
        switch self {
        case .enumType, .sint8, .uint8, .string, .uint8z, .byte: return 1
        case .sint16, .uint16, .uint16z: return 2
        case .sint32, .uint32, .float32, .uint32z: return 4
        case .float64, .sint64, .uint64: return 8
        case .invalid: return 0
        }
    }

    /// The "invalid" sentinel value for this base type.
    public var invalidValue: UInt64 {
        switch self {
        case .enumType, .sint8, .uint8, .byte:           return 0xFF
        case .sint16, .uint16:                          return 0xFFFF
        case .sint32, .uint32:                           return 0xFFFFFFFF
        case .sint64, .uint64:                           return 0xFFFFFFFFFFFFFFFF
        case .uint8z:                                     return 0
        case .uint16z:                                    return 0
        case .uint32z:                                    return 0
        case .string:                                     return 0
        case .float32:                                    return 0xFFFFFFFF
        case .float64:                                    return 0xFFFFFFFFFFFFFFFF
        case .invalid:                                    return 0
        }
    }
}

/// A definition for a single field: number, size (in bytes), and base type.
struct FieldDefinition: Sendable {
    let fieldDefinitionNumber: UInt8
    let size: UInt8
    let baseType: BaseType
}

/// A definition message: maps a local message type to a global message number
/// and a list of field definitions.
struct DefinitionMessage: Sendable {
    let architecture: UInt8        // 0 = little-endian, 1 = big-endian
    let globalMessageNumber: UInt16
    let fields: [FieldDefinition]
    let devFields: [FieldDefinition]   // developer fields (optional)
}
