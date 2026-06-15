import XCTest
@testable import AppleAttribution

final class ConfigurationTests: XCTestCase {
    func test_defaultOptions_haveSaneValues() {
        let o = AppleAttributionOptions.default
        XCTAssertEqual(o.logging, .none)
        XCTAssertEqual(o.flushAt, 20)
        XCTAssertEqual(o.flushIntervalSeconds, 30)
        XCTAssertEqual(o.maxQueueSize, 1000)
    }

    func test_logLevel_isOrdered() {
        XCTAssertLessThan(LogLevel.error, LogLevel.debug)
        XCTAssertGreaterThan(LogLevel.info, LogLevel.error)
    }

    func test_logger_respectsLevel() {
        var captured: [String] = []
        let logger = Logger(level: .error) { captured.append($0) }
        logger.log(.debug, "verbose")   // soppresso
        logger.log(.error, "boom")      // emesso
        XCTAssertEqual(captured, ["[AppleAttribution] boom"])
    }
}
