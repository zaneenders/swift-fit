#if canImport(Foundation)
import Foundation

public enum FITActivityFixtures {
  public static func sampleRideBytes() throws -> [UInt8] {
    guard let url = Bundle.module.url(forResource: "sample", withExtension: "fit") else {
      struct MissingSampleFixture: Error {}
      throw MissingSampleFixture()
    }
    return Array(try Data(contentsOf: url))
  }
}
#endif
