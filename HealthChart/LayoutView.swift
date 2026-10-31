//
//  LayoutView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/23.
//

import SwiftUI
import HealthKit
import Sliders

/// 月範囲選択スライダーの共通ラッパー。
/// データが1ヶ月しかないと範囲が0...0になり、Sliders内部の割り算が
/// NaNを生む(iOS 27はNaN座標のCALayerで例外になりクラッシュする)ため、
/// その場合はダミー範囲のスライダーを無効状態で表示する。
struct MonthRangeSlider: View {
    @Binding var range: ClosedRange<Int>
    let inRange: ClosedRange<Int>
    let disabled: Bool
    /// スライダーの下に出す選択期間(例「2023年11月〜2026年10月」)
    var periodText: String? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if inRange.lowerBound < inRange.upperBound {
                RangeSlider(range: $range, in: inRange, step: 1, onEditingChanged: onEditingChanged)
                    .disabled(disabled)
            } else {
                RangeSlider(range: .constant(0...1), in: 0...1, step: 1)
                    .disabled(true)
            }
            if let periodText {
                Text(periodText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

/// チャート画面で共通に使う表示文言(期間ラベル・共有サブタイトルなど)
enum ChartLabels {

    static let yearMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter
    }()

    /// 選択期間のラベル(例「2023年11月〜2026年10月」。1ヶ月なら単月表記)
    static func period(start: Date, end: Date) -> String {
        let startText = yearMonthFormatter.string(from: start)
        let endText = yearMonthFormatter.string(from: end)
        return startText == endText ? startText : startText + "〜" + endText
    }

    /// 共有画像のサブタイトル(期間と単位)
    static func shareSubtitle(period: String?, unitText: String) -> String? {
        var parts: [String] = []
        if let period {
            parts.append(period)
        }
        if !unitText.isEmpty {
            parts.append("単位: " + unitText)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ・ ")
    }

    /// 年単位表示で端の年が部分集計のときの注記
    static let partialYearNote = "端の年は期間内の月だけの平均です"
}

/// チャート下の設定リスト。Form(内部スクロール)だと画面の中に
/// もう1つスクロールができて操作しづらいため、高さ可変のカードにして
/// 画面全体のスクロールに乗せる
struct ChartSettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .padding()
    }
}

/// UIActivityViewControllerのSwiftUIラッパー(グラフ画像の共有に使う)
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 共有シートに渡すレンダリング済みのグラフ画像
struct ChartShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct LayoutView<Header: View, Chart: View, Footer: View>: View {
    @Binding var isLoading: Bool
    @Binding var isEmpty: Bool
    @Binding var requested: Bool
    /// 全期間集計の進み具合(0〜1)。nilなら不確定インジケータを出す
    @Binding var progress: Double?
    /// 共有画像に入れるタイトル(項目名)。nilなら共有ボタンを出さない
    var shareTitle: String?
    /// 共有画像に入れるサブタイトル(期間・単位など)
    var shareSubtitle: String?
    /// 指定があれば共有ボタンがメニューになり、実数値(false)と相対値(true)の
    /// どちらで画像を作るかを選べる(折れ線チャート用)
    var shareChartBuilder: ((_ relative: Bool) -> AnyView)?

    @State private var shareImage: ChartShareImage?

    var header: Header
    var chart: Chart
    var footer: Footer

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State var showActivityIndicator: Bool = false

    let isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
    
    init(isLoading: Binding<Bool>,
         isEmpty: Binding<Bool>,
         requested: Binding<Bool>,
         progress: Binding<Double?> = .constant(nil),
         shareTitle: String? = nil,
         shareSubtitle: String? = nil,
         shareChartBuilder: ((_ relative: Bool) -> AnyView)? = nil,
         @ViewBuilder header: () -> Header,
         @ViewBuilder chart: () -> Chart,
         @ViewBuilder footer: () -> Footer) {

        self.header = header()
        self.chart = chart()
        self.footer = footer()

        self._isLoading = isLoading
        self._isEmpty = isEmpty
        self._requested = requested
        self._progress = progress
        self.shareTitle = shareTitle
        self.shareSubtitle = shareSubtitle
        self.shareChartBuilder = shareChartBuilder
    }
    
    var body: some View {
        if !isHealthDataAvailable {
            Text("この端末はサポートしていません。標準アプリ「ヘルスケア」のあるiPhoneで動作します。")
                .padding([.bottom, .horizontal])
                .background(.background)

        } else if isLoading {
            VStack(spacing: 12) {
                if let progress {
                    ProgressView(value: progress)
                        .frame(width: 200)
                    Text("全期間のデータを集計中… \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ProgressView()
                }
            }
            .background(.background)

        } else if isEmpty {
            VStack {
                Text("記録がありません。または、ヘルスケアデータの読み取り許可がありません。")
                
                AuthorizationView(requested: $requested)
                .padding(.top)
            }
            .padding([.bottom, .horizontal])
            .background(.background)


        } else if verticalSizeClass != .compact {
            // iPhone縦・iPad(縦横とも): ヘッダー+チャート+設定のスクロールレイアウト
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            header
                        }
                        .padding(.horizontal)
                        chart
                            .frame(height: 350)
                            .padding()
                    }
                    .background(.background)
                    footer
                        .id("chartFooter")
                }
                .scrollDismissesKeyboard(.immediately)
                .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
                .toolbar { shareToolbarItem }
                .sheet(item: $shareImage) { item in
                    ActivityShareSheet(items: [item.image])
                }
                // 目標の入力欄はフッター最下部にあり、キーボード表示時の
                // 自動スクロールだけでは「完了」バーに隠れることがある(特にiPad)。
                // キーボードが出たらフッター末尾まで明示的にスクロールする
                .onReceive(NotificationCenter.default.publisher(
                    for: UIResponder.keyboardDidShowNotification)) { _ in
                    withAnimation {
                        proxy.scrollTo("chartFooter", anchor: .bottom)
                    }
                }
            }

        } else {
            // iPhone横向き: チャートのみ全画面表示
            ZStack {
                chart
                    .padding()
            }
            .background(.background)
            .toolbar { shareToolbarItem }
            .sheet(item: $shareImage) { item in
                ActivityShareSheet(items: [item.image])
            }
        }
    }

    @ToolbarContentBuilder
    private var shareToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if shareTitle != nil {
                if let shareChartBuilder {
                    Menu {
                        Button {
                            renderShareImage(chartView: shareChartBuilder(false))
                        } label: {
                            Label("実数値のまま共有", systemImage: "number")
                        }
                        Button {
                            renderShareImage(chartView: shareChartBuilder(true),
                                             note: "期間最初の値を基準にした相対表示")
                        } label: {
                            Label("相対値で共有（実数値を出さない）", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        renderShareImage(chartView: AnyView(chart))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    /// チャートを画像にして共有シートを開く。
    /// ヘッダーの数値は含めず、タイトル・期間・単位とグラフだけを描く
    @MainActor
    private func renderShareImage(chartView: AnyView, note: String? = nil) {
        let content = VStack(alignment: .leading, spacing: 8) {
            if let shareTitle {
                Text(shareTitle)
                    .font(.headline)
            }
            if let shareSubtitle {
                Text(shareSubtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            chartView
                .frame(width: 760, height: 400)
        }
        .padding(24)
        // レンダリング環境とUIKit側の色解決がズレるとダークモードで読めない
        // 画像になるため、共有画像は常にライト配色・白背景で固定する
        .background(Color.white)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        if let image = renderer.uiImage {
            shareImage = ChartShareImage(image: image)
        }
    }
}

