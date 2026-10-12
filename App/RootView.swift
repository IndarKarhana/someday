import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = 0
    @State private var settings = false

    init(initialTab: Int = 0) { _tab = State(initialValue: initialTab) }

    var body: some View {
        Group {
            if model.isLoading {
                VStack(spacing: 20) {
                    PixelArt(color: Paper.ink).frame(width: 42, height: 42)
                    Text("A little possibility.").font(Paper.serif(26))
                    ProgressView().tint(Paper.ink).accessibilityLabel("Opening your collection")
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.journal == nil {
                WelcomeView()
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 9) {
                        PixelArt(color: Paper.ink).frame(width: 20, height: 20)
                        Text("someday").font(.system(size: 23, weight: .semibold, design: .serif)).tracking(-0.8)
                        Spacer()
                        Button { settings = true } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 17)).frame(width: 44, height: 44)
                                .background(.white.opacity(0.6), in: Circle())
                        }.accessibilityLabel("Settings and collection receipts").buttonStyle(QuietButton())
                    }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)

                    Group {
                        if tab == 0 { TodayView() }
                        else { CollectionView() }
                    }
                    .frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 6) {
                        tabButton("Today", symbol: "sparkle", value: 0)
                        tabButton("Collection", symbol: "square.stack", value: 1)
                    }
                    .padding(6).background(.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(Paper.line.opacity(0.55), lineWidth: 1))
                    .padding(.horizontal, 54).padding(.top, 10).padding(.bottom, 8)
                    .frame(maxWidth: 450).frame(maxWidth: .infinity)
                    .background(Paper.background.opacity(0.97))
                }
                .sheet(isPresented: $settings) { SettingsView() }
            }
        }
        .paperScreen()
        .onOpenURL { url in if url.host == "collection" { tab = 1 } else { tab = 0 } }
        .alert("A little interruption", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func tabButton(_ title: String, symbol: String, value: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { tab = value }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 14))
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(tab == value ? Paper.ink : .clear, in: Capsule())
            .foregroundStyle(tab == value ? Paper.white : Paper.muted)
        }
        .buttonStyle(QuietButton())
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var settings = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Eyebrow(text: "A SMALL PLACE FOR POSSIBILITY", color: Paper.white.opacity(0.6))
                        Spacer()
                        Button { settings = true } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                            .accessibilityLabel("Settings and collection receipts")
                            .buttonStyle(QuietButton())
                    }
                    Spacer(minLength: 8)
                    ZStack {
                        PixelField().frame(height: 200)
                        PixelArt(color: Paper.lime).frame(width: 108, height: 108)
                    }
                    Spacer(minLength: 8)
                    Text("A little luck.\nA long story.")
                        .font(Paper.serif(51)).tracking(-2).fixedSize(horizontal: false, vertical: true)
                    Text("One quiet chance, every day.\nFive lucky numbers. A moment to keep.")
                        .font(.system(size: 17)).lineSpacing(5).foregroundStyle(Paper.white.opacity(0.68))
                    HStack(spacing: 16) {
                        ForEach(LuckyNumber.allCases.reversed()) { number in
                            PixelArt(number: number, color: Paper.white.opacity(0.75)).frame(width: 17, height: 24)
                        }
                        Spacer()
                        Text("5 → 1").font(Paper.mono(11)).foregroundStyle(Paper.lime)
                    }.padding(.vertical, 12)
                    Button(action: model.begin) {
                        HStack { Text("Let life surprise me"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 22)
                    }.buttonStyle(PrimaryButton(light: true))
                    Text("No account. No internet. Just a little possibility.")
                        .font(.system(size: 11)).foregroundStyle(Paper.white.opacity(0.55)).frame(maxWidth: .infinity)
                }
                .padding(28).frame(minHeight: geometry.size.height, alignment: .topLeading)
            }.scrollIndicators(.hidden)
        }
        .background(Paper.card.ignoresSafeArea()).foregroundStyle(Paper.white)
        .sheet(isPresented: $settings) { SettingsView() }
    }
}
