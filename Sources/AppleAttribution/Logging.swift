import Foundation

public enum LogLevel: Int, Comparable {
    case none = 0, error, info, debug
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Logger interno: stampa solo se il livello del messaggio è incluso nel livello configurato.
struct Logger {
    let level: LogLevel
    private let sink: (String) -> Void

    init(level: LogLevel, sink: @escaping (String) -> Void = { print($0) }) {
        self.level = level
        self.sink = sink
    }

    func log(_ messageLevel: LogLevel, _ message: @autoclosure () -> String) {
        guard messageLevel != .none, messageLevel <= level else { return }
        sink("[AppleAttribution] \(message())")
    }
}
