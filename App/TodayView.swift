import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var odds = false
    @State private var widgetHelp = false
    @State private var selectedHit: LuckyHit?
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 43

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(Paper.muted).frame(width: 4, height: 4)
                        Eyebrow(text: "YOUR DAILY LITTLE POSSIBILITY")
                    }
                    Text(model.today == nil ? "Good things.\nOn their own time." : "Oh, hello.\nIt’s your lucky day.")
                        .font(Paper.serif(headingSize)).tracking(-1.8)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.top, 12)

                Button {
                    if let number = model.today {
                        selectedHit = LuckyHit(day: model.todayKey, number: number, dayNumber: model.dayNumber)
                    } else { odds = true }
                } label: { dailyCard }
                    .buttonStyle(QuietButton())
                    .accessibilityLabel(model.pauseMessage ?? model.today.map { "Lucky number \($0.rawValue). Open today’s keepsake." } ?? "Today’s draw: no win. Learn about the odds.")

                if let message = model.pauseMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A small pause. Your story stays.").font(Paper.serif(23))
                        Text(message).font(.caption).foregroundStyle(Paper.muted)
                        if let until = verificationDeadline {
                            Text("Earliest next check: \(until.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(Paper.muted)
                        }
                    }.padding(18).background(Paper.lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
                }

                HStack(alignment: .top, spacing: 0) {
                    statistic(model.qualifiedDays.formatted(), label: "DAYS OF POSSIBILITY")
                    Rectangle().fill(Paper.line).frame(width: 1, height: 37).padding(.horizontal, 22)
                    statistic(model.hits.count.formatted(), label: "LUCKY MOMENTS")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 17, weight: .light)).foregroundStyle(Paper.muted)
                        .accessibilityHidden(true)
                }.padding(.vertical, 2)

                Rectangle().fill(Paper.line).frame(height: 1)

                Button { odds = true } label: {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack {
                            Eyebrow(text: "FIVE NUMBERS. FIVE KINDS OF LUCK.")
                            Spacer(minLength: 6)
                            Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Paper.muted)
                        }
                        HStack(spacing: 9) {
                            ForEach(LuckyNumber.allCases.reversed()) { number in
                                VStack(spacing: 10) {
                                    PixelArt(number: number, color: Paper.ink).frame(width: 18, height: 26)
                                    Text(number == .one ? "RAREST" : number == .five ? "RARE" : "·")
                                        .font(Paper.mono(8)).tracking(0.7).foregroundStyle(Paper.muted)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(number == .one ? Paper.lime.opacity(0.55) : .white.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
                            }
                        }
                    }
                }.buttonStyle(QuietButton()).accessibilityLabel("Explore the five lucky numbers and their exact daily odds")

                Button { widgetHelp = true } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "lock.rectangle").font(.system(size: 23, weight: .light))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("A little luck on your Lock Screen").font(.system(.subheadline, weight: .medium))
                            Text("Add your Someday widget").font(.caption).foregroundStyle(Paper.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(17).background(Paper.line.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(QuietButton())

                Text("No streak to keep. No reason to rush.")
                    .font(Paper.serif(16)).italic().foregroundStyle(Paper.muted).frame(maxWidth: .infinity).padding(.bottom, 10)
            }.padding(.horizontal, 24).padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $odds) { OddsView() }
        .sheet(isPresented: $widgetHelp) { WidgetGuideView() }
        .sheet(item: $selectedHit) { hit in HitDetailView(hit: hit, clock: model.journal!.clock) }
    }

    private var verificationDeadline: Date? {
        switch model.phase {
        case .verifying(let until), .rateLimited(let until): return until
        default: return nil
        }
    }

    private var dailyCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Paper.lime).frame(width: 5, height: 5)
                    Eyebrow(text: "TODAY’S DRAW", color: Paper.white.opacity(0.65))
                }
                Spacer()
                Text(String(format: "DAY %03d", model.dayNumber)).font(Paper.mono(10)).foregroundStyle(Paper.white.opacity(0.5))
            }
            ZStack {
                PixelField().padding(.horizontal, 6)
                PixelArt(number: model.today, color: model.today == nil ? Paper.white.opacity(0.86) : Paper.lime)
                    .frame(width: model.today == nil ? 91 : 94, height: model.today == nil ? 91 : 128)
                    .rotationEffect(.degrees(model.today == nil ? -8 : 0))
            }.frame(height: 167).padding(.top, 15)
            Text(model.pauseMessage != nil ? "A little verification pause." : model.today == nil ? "Not today. And that’s okay." : "Lucky number \(model.today!.rawValue).")
                .font(Paper.serif(25)).tracking(-0.5).multilineTextAlignment(.center).foregroundStyle(Paper.white)
            Text(model.pauseMessage != nil ? "Your saved moments are safe." : model.today == nil ? "Tomorrow holds another possibility." : "\(model.today!.oddsLabel). And it found you.")
                .font(.system(size: 12)).foregroundStyle(Paper.white.opacity(0.57)).padding(.top, 9)
            HStack {
                Text(model.journal?.clock.label(for: model.todayKey, style: .medium).uppercased() ?? "")
                    .font(Paper.mono(9)).tracking(1)
                Spacer()
                Image(systemName: model.pauseMessage != nil ? "clock" : model.today == nil ? "checkmark" : "arrow.up.right").font(.system(size: 11))
            }.foregroundStyle(Paper.white.opacity(0.4)).padding(.top, 31)
        }
        .padding(23).background(Paper.card, in: RoundedRectangle(cornerRadius: 25))
    }

    private func statistic(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value).font(.system(size: 27, weight: .regular, design: .serif)).monospacedDigit()
            Text(label).font(Paper.mono(8)).tracking(0.8).foregroundStyle(Paper.muted)
        }
    }
}

struct OddsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Eyebrow(text: "A FIELD GUIDE TO LUCK"); Spacer(); DismissButton() }
                Text("Some days are\na little rarer.").font(Paper.serif(41)).tracking(-1.6)
                Text("One fixed result each day. Five possibilities worth keeping.")
                    .font(.subheadline).foregroundStyle(Paper.muted).lineSpacing(4)
                VStack(spacing: 0) {
                    ForEach(LuckyNumber.allCases.reversed()) { number in
                        HStack(spacing: 17) {
                            PixelArt(number: number, color: number == .one ? Paper.lime : Paper.white)
                                .frame(width: 24, height: 33).frame(width: 61, height: 72)
                                .background(Paper.card, in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(number.name).font(.system(.subheadline, weight: .medium))
                                Text("\(number.oddsLabel) each day").font(.caption).foregroundStyle(Paper.muted)
                                Text("~\(number.averageInterval) between hits, on average")
                                    .font(.system(size: 10)).foregroundStyle(Paper.muted)
                            }
                            Spacer(minLength: 0)
                        }.padding(.vertical, 14)
                        if number != .one { Divider().overlay(Paper.line) }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rare. Never overdue.").font(Paper.serif(24))
                    Text("Averages aren’t appointments. You might hit tomorrow, or wait much longer. Every day has the same odds; opening the app again won’t change them.")
                    Text("Your daily chance of any win is about 2%. Missed days count when continuous elapsed time can be verified. An unverified restart or clock change pauses draws for 24 hours; days in that gap are skipped.")
                }.font(.subheadline).foregroundStyle(Paper.muted).lineSpacing(4)
                    .padding(20).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
            }.padding(24)
        }.paperScreen()
    }
}

struct WidgetGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack { Eyebrow(text: "A QUIET COMPANION"); Spacer(); DismissButton() }
                Text("Let luck\nfind you here.").font(Paper.serif(43)).tracking(-1.6)
                VStack(spacing: 17) {
                    Text("9:41").font(.system(size: 62, weight: .thin, design: .rounded))
                    HStack(spacing: 11) {
                        PixelArt().frame(width: 27, height: 27)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("someday").font(.system(.subheadline, design: .serif))
                            Text("A little possibility.").font(.caption2).opacity(0.7)
                        }
                    }.padding(12).overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.3)))
                }.frame(maxWidth: .infinity).padding(27).foregroundStyle(Paper.white)
                    .background(Paper.card, in: RoundedRectangle(cornerRadius: 25))
                    .accessibilityLabel("Example Lock Screen with the Someday widget")
                instruction("01", title: "Touch and hold your Lock Screen", detail: "Unlock your iPhone, then hold an empty area of the Lock Screen.")
                instruction("02", title: "Choose Customize → Lock Screen", detail: "Tap the widget area below the clock.")
                instruction("03", title: "Find Someday and add a widget", detail: "Choose the small symbol or the wider daily message, then tap Done.")
                Text("Prefer your Home Screen? Hold an empty area, choose Edit → Add Widget, and search for Someday.")
                    .font(.subheadline).foregroundStyle(Paper.muted).lineSpacing(4)
                Text("iOS controls when widgets refresh, so a change may appear after midnight. Open Someday for the current result. Your collection keeps every verified hit. After an unverified restart or clock change, draws pause for 24 hours.")
                    .font(.caption).foregroundStyle(Paper.muted).lineSpacing(3)
            }.padding(24)
        }.paperScreen()
    }

    private func instruction(_ index: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(index).font(Paper.mono(12)).padding(12).background(Paper.lime, in: Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(.subheadline, weight: .semibold))
                Text(detail).font(.subheadline).foregroundStyle(Paper.muted).lineSpacing(3)
            }
        }
    }
}
