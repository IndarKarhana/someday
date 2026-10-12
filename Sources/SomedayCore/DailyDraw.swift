import CryptoKit
import Foundation

public struct DailyDraw: Sendable {
    private let seed: Data

    public init(seed: Data) { self.seed = seed }

    public func result(on day: String) -> LuckyNumber? {
        LuckyNumber.winner(forTicket: ticket(on: day))
    }

    public func ticket(on day: String) -> Int {
        let bound = UInt64(LuckyNumber.ticketCount)
        let rejectionThreshold = (UInt64.max - bound + 1) % bound
        var attempt: UInt64 = 0
        while true {
            let message = Data("someday.draw.v1|\(day)|\(attempt)".utf8)
            let digest = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: seed))
            let value = digest.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            // Rejection sampling avoids modulo bias. Usually the first value is accepted.
            if value >= rejectionThreshold { return Int(value % bound) }
            attempt += 1
        }
    }
}
