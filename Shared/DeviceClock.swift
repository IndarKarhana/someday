import Darwin
import Foundation

enum DeviceClock {
    static func read() throws -> ClockReading {
        var info = mach_timebase_info_data_t()
        guard mach_timebase_info(&info) == KERN_SUCCESS, info.denom != 0 else { throw JournalError.invalidClock }
        let ticks = mach_continuous_time()
        let seconds = Double(ticks) * Double(info.numer) / Double(info.denom) / 1_000_000_000
        return ClockReading(wall: Date(), uptime: seconds)
    }
}
