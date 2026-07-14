/// FIT global message numbers used for activity files.
public enum FITGlobalMessage {
  public static let fileID: UInt16 = 0
  public static let session: UInt16 = 18
  public static let lap: UInt16 = 19
  public static let record: UInt16 = 20
  public static let event: UInt16 = 21
  public static let activity: UInt16 = 34
}

/// Common FIT record message field numbers.
public enum FITRecordField {
  public static let timestamp: UInt8 = 253
  public static let positionLat: UInt8 = 0
  public static let positionLong: UInt8 = 1
  public static let altitude: UInt8 = 2
  public static let heartRate: UInt8 = 3
  public static let distance: UInt8 = 5
  public static let speed: UInt8 = 6
  public static let heartRateAlt: UInt8 = 7
  public static let enhancedSpeed: UInt8 = 73
}

/// Common FIT session message field numbers.
public enum FITSessionField {
  public static let timestamp: UInt8 = 253
  public static let startTime: UInt8 = 2
  public static let sport: UInt8 = 5
  public static let subSport: UInt8 = 6
  public static let totalElapsedTime: UInt8 = 7
  public static let totalTimerTime: UInt8 = 8
  public static let totalDistance: UInt8 = 9
}

/// Seconds between the FIT epoch (1989-12-31 00:00:00 UTC) and Unix epoch.
public let fitEpochOffset: UInt32 = 631_065_600

public enum FITFileType: UInt8, Sendable {
  case activity = 4
}

public enum FITManufacturer: UInt16, Sendable {
  case development = 255
}

public enum FITSport: UInt8, Sendable {
  case running = 1
  case cycling = 2
}

public enum FITSubSport: UInt8, Sendable {
  case generic = 0
  case treadmill = 1
  case indoorCycling = 6
}

public enum FITEvent: UInt8, Sendable {
  case timer = 0
}

public enum FITEventType: UInt8, Sendable {
  case start = 0
  case stopAll = 4
}
