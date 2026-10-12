import SwiftUI
import WidgetKit

private struct DailyEntry: TimelineEntry {
    let date: Date
    let number: LuckyNumber?
    let dayNumber: Int
    let enrolled: Bool
    let sample: Bool
    var pending: Bool = false
    var validUntil: Date? = nil
}

private struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: Date(), number: nil, dayNumber: 1, enrolled: true, sample: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        if context.isPreview {
            completion(DailyEntry(date: Date(), number: .five, dayNumber: 60, enrolled: true, sample: true))
        } else { completion(currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let current = currentEntry()
        let refresh = Date().addingTimeInterval(900)
        // Expire presentation; never place tomorrow's result in a timeline.
        let expiry = max(Date().addingTimeInterval(1), min(refresh, current.validUntil ?? refresh))
        let stale = DailyEntry(date: expiry, number: nil, dayNumber: current.dayNumber,
                               enrolled: current.enrolled, sample: false, pending: current.enrolled)
        completion(Timeline(entries: [current, stale], policy: .after(expiry)))
    }

    private func currentEntry() -> DailyEntry {
        do {
            guard let snapshot = try SharedStorage.load() else {
                return DailyEntry(date: Date(), number: nil, dayNumber: 0, enrolled: false, sample: false)
            }
            return DailyEntry(date: Date(), number: snapshot.today, dayNumber: snapshot.journal.qualifiedDays,
                              enrolled: true, sample: false, pending: snapshot.phase != .ready,
                              validUntil: snapshot.journal.clock.nextMidnight(after: snapshot.date))
        } catch {
            return DailyEntry(date: Date(), number: nil, dayNumber: 0, enrolled: true, sample: false, pending: true)
        }
    }
}

private struct DailyWidgetView: View {
    let entry: DailyEntry
    @Environment(\.widgetFamily) private var family
    private let lime = Color(red: 0.82, green: 0.94, blue: 0.44)

    private var title: String {
        if !entry.enrolled { return "Begin your story" }
        if entry.pending { return "Open to check." }
        return entry.number == nil ? "A little possibility." : "Lucky day."
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.pending ? "Someday · Open to check" : entry.enrolled ? entry.number.map { "Someday · Lucky \($0.rawValue)" } ?? "Someday · A little possibility" : "Open Someday to begin")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    PixelArt(number: entry.number, color: .primary).padding(13)
                }
            case .accessoryRectangular:
                HStack(spacing: 10) {
                    PixelArt(number: entry.number, color: .primary).frame(width: 28, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(entry.number.map { $0.oddsLabel } ?? "someday").font(.caption)
                    }
                }
            case .systemMedium:
                HStack(spacing: 24) {
                    PixelArt(number: entry.number, color: entry.number == nil ? .white : lime)
                        .frame(width: 62, height: 81).padding(.leading, 7)
                    VStack(alignment: .leading, spacing: 8) {
                        brand
                        Text(title).font(.system(size: 22, design: .serif)).foregroundStyle(.white)
                        Text(entry.number?.oddsLabel ?? "Good things. On their own time.")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
                        if !entry.enrolled { Text("Tap to start").font(.caption2).foregroundStyle(lime) }
                    }
                    Spacer(minLength: 0)
                }
            default:
                VStack(alignment: .leading, spacing: 8) {
                    brand
                    Spacer(minLength: 0)
                    PixelArt(number: entry.number, color: entry.number == nil ? .white : lime)
                        .frame(width: 42, height: 51).frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                    Text(title).font(.system(size: 14, design: .serif)).foregroundStyle(.white)
                    Text(entry.enrolled ? "DAY \(entry.dayNumber)" : "TAP TO START")
                        .font(.system(size: 8, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .containerBackground(for: .widget) { Color(red: 0.065, green: 0.075, blue: 0.065) }
        .widgetURL(URL(string: "someday://today"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.pending ? "Someday. Open the app to check verification." : entry.enrolled ? entry.number.map { "Someday. Lucky day. Number \($0.rawValue). \($0.oddsLabel)." } ?? "Someday. No win today. Tomorrow holds another possibility." : "Open Someday to start your daily draws.")
    }

    private var brand: some View {
        HStack {
            Text("someday").font(.system(size: 14, design: .serif)).foregroundStyle(.white.opacity(0.7))
            Spacer()
            if entry.sample { Text("SAMPLE").font(.system(size: 7, design: .monospaced)).foregroundStyle(.white.opacity(0.5)) }
            else { Circle().fill(lime).frame(width: 4, height: 4) }
        }
    }
}

@main
struct SomedayWidget: Widget {
    let kind = SharedStorage.widgetKind
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyProvider()) { entry in DailyWidgetView(entry: entry) }
            .configurationDisplayName("A little possibility")
            .description("Your daily draw. Quiet until a lucky number finds you.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
