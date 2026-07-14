/// Options controlling FIT file decoding behavior.
public struct FITDecodeOptions: Sendable {
  /// When `true`, throw `.crcMismatch` if the trailing file CRC does not verify.
  public var validateFileCRC: Bool

  /// When `true`, throw `.headerCRCMismatch` if a 14-byte header CRC does not verify.
  public var validateHeaderCRC: Bool

  /// When `true`, reject definition messages that declare unknown base types.
  public var strictDefinitions: Bool

  public init(
    validateFileCRC: Bool = false,
    validateHeaderCRC: Bool = false,
    strictDefinitions: Bool = true
  ) {
    self.validateFileCRC = validateFileCRC
    self.validateHeaderCRC = validateHeaderCRC
    self.strictDefinitions = strictDefinitions
  }
}
