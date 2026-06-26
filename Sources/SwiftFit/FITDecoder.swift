import Foundation

/// Internal decoder for FIT data. Reads the header, definitions, data messages,
/// and trailing CRC from a `Data` buffer.
struct FITDecoder: @unchecked Sendable {
    let data: Data
    var cursor: Int = 0

    var header: Header = .init(headerSize: 0, protocolVersion: 0,
                                profileVersion: 0, dataSize: 0,
                                signature: 0, crc: nil)
    var fileCRC: UInt16 = 0
    var fileCRCComputed: UInt16 = 0
    var fileCRCValid: Bool = false

    /// Active definition messages keyed by local message type (0–15).
    var definitions: [UInt8: DefinitionMessage] = [:]
    /// Last timestamp message (for compressed timestamp headers). Not yet used.
    var lastTimeOffset: UInt32 = 0

    init(data: Data) {
        self.data = data
    }

    // MARK: - Byte access

    private mutating func readUInt8() throws -> UInt8 {
        guard cursor < data.count else { throw FITError.truncated }
        let b = data[cursor]; cursor += 1; return b
    }

    private mutating func readBytes(_ count: Int) throws -> Data {
        guard cursor + count <= data.count else { throw FITError.truncated }
        let d = data.subdata(in: cursor..<(cursor + count))
        cursor += count
        return d
    }

    private mutating func readIntLE<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let n = MemoryLayout<T>.size
        let bytes = try readBytes(n)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: T.self) }
    }

    private mutating func readIntBE<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let n = MemoryLayout<T>.size
        let bytes = try readBytes(n)
        var value: T = 0
        for byte in bytes { value = (value << 8) | T(byte) }
        return value
    }

    private mutating func readU16(_ bigEndian: Bool) throws -> UInt16 {
        bigEndian ? try readIntBE(UInt16.self) : try readIntLE(UInt16.self)
    }
    private mutating func readU32(_ bigEndian: Bool) throws -> UInt32 {
        bigEndian ? try readIntBE(UInt32.self) : try readIntLE(UInt32.self)
    }

    // MARK: - Header

    mutating func readFileHeader() throws {
        guard data.count >= 12 else { throw FITError.truncated }
        let headerSize = data[0]
        guard headerSize == 12 || headerSize == 14 else { throw FITError.truncated }
        cursor = 0
        let size = try readUInt8()
        let proto = try readUInt8()
        let profile = try readU16(false)
        let dataSize = try readU32(false)
        // ".FIT" stored little-endian as UInt32 == 0x5449462E.
        let signature = try readIntLE(UInt32.self)
        guard signature == 0x5449462E else {
            throw FITError.invalidHeaderSignature
        }

        var crc: UInt16? = nil
        if size >= 14 { crc = try readU16(false) }
        self.header = Header(headerSize: size, protocolVersion: proto,
                             profileVersion: profile, dataSize: dataSize,
                             signature: signature, crc: crc)
        _ = proto
    }

    // MARK: - Messages

    mutating func readMessages() throws -> [Message] {
        var messages: [Message] = []
        let end = cursor + Int(header.dataSize)
        guard end <= data.count else { throw FITError.truncated }
        while cursor < end {
            let recordHeader = try readUInt8()
            let isCompressed = (recordHeader & 0x80) != 0
            if isCompressed {
                // Compressed timestamp header (bit 7 = 1).
                //   bits 6–5:     local mesg type
                //   bits 4–0:     time offset
                let localMesgType = (recordHeader >> 5) & 0x03
                guard let def = definitions[localMesgType] else {
                    throw FITError.invalidRecordHeader(recordHeader)
                }
                lastTimeOffset = (lastTimeOffset & 0xFFFFFFE0)
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
                    try readDefinitionMessage(localMesgType: localMesgType,
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

    private mutating func readDefinitionMessage(localMesgType: UInt8,
                                                hasDevData: Bool) throws {
        // Reserved byte
        _ = try readUInt8()
        let architecture = try readUInt8()
        guard architecture == 0 || architecture == 1 else {
            throw FITError.unsupportedArchitecture
        }
        let bigEndian = architecture == 1
        let globalMessageNumber = try readU16(bigEndian)
        let nFields = try readUInt8()
        var fields: [FieldDefinition] = []
        fields.reserveCapacity(Int(nFields))
        for _ in 0..<nFields {
            let num = try readUInt8()
            let size = try readUInt8()
            let base = try readUInt8()
            let baseType = BaseType(rawValue: base) ?? .invalid
            fields.append(FieldDefinition(fieldDefinitionNumber: num,
                                          size: size, baseType: baseType))
        }
        var devFields: [FieldDefinition] = []
        if hasDevData {
            let nDev = try readUInt8()
            for _ in 0..<nDev {
                let num = try readUInt8()
                let size = try readUInt8()
                let base = try readUInt8()
                let baseType = BaseType(rawValue: base) ?? .invalid
                devFields.append(FieldDefinition(fieldDefinitionNumber: num,
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

    private mutating func readDataMessage(_ def: DefinitionMessage) throws -> Message {
        var fields: [Field] = []
        for fd in def.fields {
            let payload = try readBytes(Int(fd.size))
            let values = decodeField(payload, baseType: fd.baseType,
                                     bigEndian: def.architecture == 1)
            fields.append(Field(fieldDefinitionNumber: fd.fieldDefinitionNumber,
                                baseType: fd.baseType, values: values))
        }
        // Developer field values are present whenever the active definition
        // declares dev fields, regardless of the data record's dev flag
        // (Apple Watch omits the flag while still writing the payload).
        for fd in def.devFields {
            let payload = try readBytes(Int(fd.size))
            let values = decodeField(payload, baseType: fd.baseType,
                                     bigEndian: def.architecture == 1)
            fields.append(Field(fieldDefinitionNumber: fd.fieldDefinitionNumber,
                                baseType: fd.baseType, values: values))
        }
        return Message(globalMessageNumber: def.globalMessageNumber,
                       fields: fields)
    }

    // Decode the bytes for a field into an array of `Value`s. Fields may
    // contain arrays (size is a multiple of the base type's element size).
    private func decodeField(_ payload: Data, baseType: BaseType,
                             bigEndian: Bool) -> [Value] {
        guard payload.count > 0, baseType != .invalid else { return [.invalid] }
        let elemSize = baseType.size
        guard elemSize > 0 else { return [.invalid] }
        if baseType == .string {
            // NUL-terminated, multiple strings separated by NUL.
            let raw = String(data: payload, encoding: .utf8) ?? String(decoding: payload, as: UTF8.self)
            return [.string(raw.replacingOccurrences(of: "\u{0}", with: ""))]
        }

        let count = payload.count / elemSize
        guard count > 0 else { return [.invalid] }

        func loadU8(_ at: Int) -> UInt8 { payload[at] }
        func loadU16(_ at: Int) -> UInt16 {
            let b0 = UInt16(payload[at]); let b1 = UInt16(payload[at + 1])
            return bigEndian ? (b0 << 8) | b1 : (b1 << 8) | b0
        }
        func loadU32(_ at: Int) -> UInt32 {
            var v: UInt32 = 0
            for i in 0..<4 { v = (v << 8) | UInt32(payload[at + i]) }
            return bigEndian ? v : v.byteSwapped
        }
        func loadU64(_ at: Int) -> UInt64 {
            var v: UInt64 = 0
            for i in 0..<8 { v = (v << 8) | UInt64(payload[at + i]) }
            return bigEndian ? v : v.byteSwapped
        }
        func loadF32(_ at: Int) -> Float {
            Float(bitPattern: loadU32(at))
        }
        func loadF64(_ at: Int) -> Double {
            Double(bitPattern: loadU64(at))
        }

        func u8Invalid(_ v: UInt8) -> Bool { return v == UInt8(truncatingIfNeeded: baseType.invalidValue) }
        func u16Invalid(_ v: UInt16) -> Bool { return v == UInt16(truncatingIfNeeded: baseType.invalidValue) }
        func u32Invalid(_ v: UInt32) -> Bool { return v == UInt32(truncatingIfNeeded: baseType.invalidValue) }
        func u64Invalid(_ v: UInt64) -> Bool { return v == baseType.invalidValue }

        var result: [Value] = []
        for i in 0..<count {
            let off = i * elemSize
            switch baseType {
            case .enumType:
                result.append(.enumType(loadU8(off)))
            case .sint8:
                let v = Int8(bitPattern: loadU8(off)); result.append(.sint8(v))
            case .uint8:
                result.append(.uint8(loadU8(off)))
            case .sint16:
                result.append(.sint16(Int16(bitPattern: loadU16(off))))
            case .uint16:
                result.append(.uint16(loadU16(off)))
            case .sint32:
                result.append(.sint32(Int32(bitPattern: loadU32(off))))
            case .uint32:
                result.append(.uint32(loadU32(off)))
            case .float32:
                let v = loadF32(off); result.append(v.bitPattern == 0xFFFFFFFF ? .invalid : .float32(v))
            case .float64:
                let v = loadF64(off); result.append(v.bitPattern == 0xFFFFFFFFFFFFFFFF ? .invalid : .float64(v))
            case .uint8z:
                result.append(.uint8z(loadU8(off)))
            case .uint16z:
                result.append(.uint16z(loadU16(off)))
            case .uint32z:
                result.append(.uint32z(loadU32(off)))
            case .byte:
                result.append(.byte(loadU8(off)))
            case .sint64:
                result.append(.sint64(Int64(bitPattern: loadU64(off))))
            case .uint64:
                result.append(.uint64(loadU64(off)))
            case .string, .invalid:
                result.append(.invalid)
            }
        }
        return result
    }

    // MARK: - CRC

    mutating func readFileCRC() throws {
        // Two trailing bytes: CRC of everything before them (header + data).
        let crcStart = Int(header.headerSize) + Int(header.dataSize)
        guard crcStart + 2 <= data.count else { throw FITError.truncated }
        cursor = crcStart
        fileCRC = try readU16(false)
        fileCRCComputed = FITCRC.compute(data[0..<crcStart])
        fileCRCValid = (fileCRCComputed == fileCRC)
        // Mismatch is not fatal: some producers (e.g. Apple Watch) write
        // non-standard CRCs while the message structure is otherwise valid.
    }
}