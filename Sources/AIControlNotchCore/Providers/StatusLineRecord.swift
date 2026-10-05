import Foundation

/// The rate limits Claude Code passes to its status line, as saved by `aicontrolnotch-tap`.
public struct StatusLineRecord: Equatable, Sendable {
    public struct Limit: Equatable, Sendable {
        public let usedPercentage: Double
        public let resetsAt: Date?
    }

    static let sessionMinutes = 300
    static let weekMinutes = 10_080

    public let capturedAt: Date
    public let fiveHour: Limit?
    public let sevenDay: Limit?

    /// Pulls `rate_limits` out of the status line's stdin JSON; `nil` when absent.
    public static func extract(fromStatusLineInput data: Data, now: Date) -> StatusLineRecord? {
        guard
            let input = try? decoder.decode(InputDTO.self, from: data),
            let limits = input.rateLimits,
            limits.fiveHour != nil || limits.sevenDay != nil
        else { return nil }
        return StatusLineRecord(capturedAt: now, fiveHour: limits.fiveHour?.limit, sevenDay: limits.sevenDay?.limit)
    }

    public static func decode(_ data: Data) throws -> StatusLineRecord {
        guard let record = try? decoder.decode(RecordDTO.self, from: data) else {
            throw UsageError.invalidFormat("statusline record is unreadable")
        }
        return StatusLineRecord(
            capturedAt: Date(timeIntervalSince1970: record.capturedAt),
            fiveHour: record.rateLimits.fiveHour?.limit,
            sevenDay: record.rateLimits.sevenDay?.limit
        )
    }

    public func encoded() throws -> Data {
        let record = RecordDTO(
            capturedAt: capturedAt.timeIntervalSince1970,
            rateLimits: LimitsDTO(fiveHour: fiveHour.map(LimitDTO.init), sevenDay: sevenDay.map(LimitDTO.init))
        )
        return try Self.encoder.encode(record)
    }

    public var windows: [UsageWindow] {
        [(fiveHour, Self.sessionMinutes), (sevenDay, Self.weekMinutes)].compactMap { limit, minutes in
            limit.map {
                UsageWindow(
                    kind: WindowClassifier.kind(minutes: minutes),
                    usedPercent: $0.usedPercentage,
                    durationMinutes: minutes,
                    resetsAt: $0.resetsAt
                )
            }
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

private struct InputDTO: Decodable {
    let rateLimits: LimitsDTO?
}

private struct RecordDTO: Codable {
    let capturedAt: Double
    let rateLimits: LimitsDTO
}

private struct LimitsDTO: Codable {
    let fiveHour: LimitDTO?
    let sevenDay: LimitDTO?
}

private struct LimitDTO: Codable {
    let usedPercentage: Double
    let resetsAt: Double?

    init(_ limit: StatusLineRecord.Limit) {
        usedPercentage = limit.usedPercentage
        resetsAt = limit.resetsAt?.timeIntervalSince1970
    }

    var limit: StatusLineRecord.Limit {
        let reset = resetsAt.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
        return StatusLineRecord.Limit(usedPercentage: usedPercentage, resetsAt: reset)
    }
}
