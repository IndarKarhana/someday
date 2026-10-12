import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedHit: LuckyHit?
    @State private var sample = false
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 43

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "THE DAYS THAT FOUND YOU")
                    Text("Your lucky days.").font(Paper.serif(headingSize)).tracking(-1.8)
                    Text("Little moments. Yours to keep.").font(.subheadline).foregroundStyle(Paper.muted)
                }.padding(.top, 12)

                if model.hits.isEmpty { emptyCollection }
                else {
                    HStack {
                        Eyebrow(text: "\(model.hits.count) MOMENT\(model.hits.count == 1 ? "" : "S") COLLECTED")
                        Spacer()
                        Eyebrow(text: "NEWEST FIRST")
                    }.padding(.top, 10)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 13)], spacing: 16) {
                        ForEach(model.hits) { hit in
                            Button { selectedHit = hit } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(spacing: 20) {
                                        HStack {
                                            Text(String(format: "NO. %02d", hit.number.rawValue)).font(Paper.mono(8)).tracking(1)
                                            Spacer()
                                            Image(systemName: "arrow.up.right").font(.system(size: 9))
                                        }.foregroundStyle(Paper.white.opacity(0.5))
                                        PixelArt(number: hit.number).frame(height: 86)
                                        Text("LUCKY DAY").font(Paper.mono(8)).tracking(2).foregroundStyle(Paper.white.opacity(0.6))
                                    }.padding(17).frame(maxWidth: .infinity)
                                        .background(Paper.card, in: RoundedRectangle(cornerRadius: 19))
                                    Text(model.journal!.clock.label(for: hit.day, style: .medium))
                                        .font(.system(.caption, weight: .medium))
                                    Text(hit.number.oddsLabel).font(Paper.mono(10)).foregroundStyle(Paper.muted)
                                }
                            }.buttonStyle(QuietButton()).accessibilityLabel("Lucky number \(hit.number.rawValue), \(model.journal!.clock.label(for: hit.day))")
                        }
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
            .sheet(item: $selectedHit) { hit in HitDetailView(hit: hit, clock: model.journal!.clock) }
            .sheet(isPresented: $sample) {
                HitDetailView(hit: LuckyHit(day: model.todayKey, number: .five, dayNumber: model.dayNumber), clock: model.journal!.clock, isSample: true)
            }
    }

    private var emptyCollection: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 21).fill(Paper.line.opacity(0.6))
                    .frame(width: 155, height: 202).rotationEffect(.degrees(-13)).offset(x: -22, y: 3)
                RoundedRectangle(cornerRadius: 21).fill(Color(red: 0.83, green: 0.86, blue: 0.77))
                    .frame(width: 155, height: 202).rotationEffect(.degrees(8)).offset(x: 17, y: 0)
                VStack {
                    Eyebrow(text: "SOMEDAY", color: Paper.white.opacity(0.45))
                    Spacer()
                    PixelArt(color: Paper.lime).frame(width: 56, height: 56)
                    Spacer()
                    Text("A MOMENT TO KEEP").font(Paper.mono(7)).tracking(1).foregroundStyle(Paper.white.opacity(0.4))
                }.padding(20).frame(width: 155, height: 202).background(Paper.card, in: RoundedRectangle(cornerRadius: 21))
            }.frame(height: 265).frame(maxWidth: .infinity).padding(.top, 23).accessibilityHidden(true)
            Text("Your story is\nstill unfolding.").font(Paper.serif(33)).tracking(-1).multilineTextAlignment(.center)
            Text("When a lucky number finds you,\nits date and its story will live here.")
                .font(.subheadline).foregroundStyle(Paper.muted).lineSpacing(5).multilineTextAlignment(.center)
            Button { sample = true } label: {
                HStack(spacing: 9) { Text("Take a peek at a sample"); Image(systemName: "arrow.up.right") }
                    .font(.system(.caption, weight: .medium)).padding(.horizontal, 19).padding(.vertical, 14)
                    .overlay(Capsule().strokeBorder(Paper.line, lineWidth: 1))
            }.buttonStyle(QuietButton()).padding(.top, 2)
            Text("SAMPLES NEVER COUNT AS WINS").font(Paper.mono(8)).tracking(1).foregroundStyle(Paper.muted)
        }.frame(maxWidth: .infinity)
    }
}
