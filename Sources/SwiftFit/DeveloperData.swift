/// Parsed `developer_data_id` message (global message #207).
public struct DeveloperDataID: Sendable, Equatable {
  public let developerDataIndex: UInt8
  public let developerId: UInt8
  public let applicationId: [UInt8]

  public init(developerDataIndex: UInt8, developerId: UInt8, applicationId: [UInt8]) {
    self.developerDataIndex = developerDataIndex
    self.developerId = developerId
    self.applicationId = applicationId
  }
}

/// Parsed `developer_data_definition` message (global message #206).
public struct DeveloperFieldDefinition: Sendable, Equatable {
  public let developerDataIndex: UInt8
  public let fieldDefinitionNumber: UInt8
  public let baseType: BaseType
  public let fieldName: String
  public let units: String?

  public init(
    developerDataIndex: UInt8,
    fieldDefinitionNumber: UInt8,
    baseType: BaseType,
    fieldName: String,
    units: String?
  ) {
    self.developerDataIndex = developerDataIndex
    self.fieldDefinitionNumber = fieldDefinitionNumber
    self.baseType = baseType
    self.fieldName = fieldName
    self.units = units
  }
}

/// Key for looking up a developer field definition.
public struct DeveloperFieldKey: Sendable, Hashable, Equatable {
  public let developerDataIndex: UInt8
  public let fieldDefinitionNumber: UInt8

  public init(developerDataIndex: UInt8, fieldDefinitionNumber: UInt8) {
    self.developerDataIndex = developerDataIndex
    self.fieldDefinitionNumber = fieldDefinitionNumber
  }
}

enum DeveloperDataParser {
  static let timestampFieldNumber: UInt8 = 253

  static func developerDataIDs(from messages: [Message]) -> [UInt8: DeveloperDataID] {
    var result: [UInt8: DeveloperDataID] = [:]
    for message in messages where message.globalMessageNumber == FITGlobalMessage.developerDataID {
      guard
        let index = message.uint8Field(number: FITDeveloperDataIDField.developerDataIndex),
        let developerId = message.uint8Field(number: FITDeveloperDataIDField.developerId)
      else { continue }
      let applicationId = message.byteArrayField(number: FITDeveloperDataIDField.applicationId) ?? []
      result[index] = DeveloperDataID(
        developerDataIndex: index,
        developerId: developerId,
        applicationId: applicationId
      )
    }
    return result
  }

  static func developerFieldDefinitions(
    from messages: [Message]
  ) -> [DeveloperFieldKey: DeveloperFieldDefinition] {
    var result: [DeveloperFieldKey: DeveloperFieldDefinition] = [:]
    for message in messages where message.globalMessageNumber == FITGlobalMessage.developerDataDefinition {
      guard
        let index = message.uint8Field(number: FITDeveloperDataDefinitionField.developerDataIndex),
        let fieldNumber = message.uint8Field(
          number: FITDeveloperDataDefinitionField.fieldDefinitionNumber),
        let baseTypeRaw = message.uint8Field(number: FITDeveloperDataDefinitionField.fitBaseTypeId),
        let baseType = BaseType(rawValue: baseTypeRaw)
      else { continue }
      let fieldName = message.stringField(number: FITDeveloperDataDefinitionField.fieldName) ?? ""
      let units = message.stringField(number: FITDeveloperDataDefinitionField.units)
      let key = DeveloperFieldKey(
        developerDataIndex: index,
        fieldDefinitionNumber: fieldNumber
      )
      result[key] = DeveloperFieldDefinition(
        developerDataIndex: index,
        fieldDefinitionNumber: fieldNumber,
        baseType: baseType,
        fieldName: fieldName,
        units: units
      )
    }
    return result
  }
}

extension Message {
  fileprivate func byteArrayField(number: UInt8) -> [UInt8]? {
    guard let field = field(number: number) else { return nil }
    return field.values.compactMap { value in
      switch value {
      case .byte(let byte): byte
      case .uint8(let byte): byte
      default: nil
      }
    }
  }
}
