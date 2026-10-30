//
//  ComparisonChartView.swift
//  HealthChart
//
//  2項目の月次推移を上下に並べ、相関係数を表示する。
//

import SwiftUI
import Charts
import HealthKit

struct ComparisonChartView: View {

    @Environment(\.colorScheme) var colorScheme
    @AppStorage("startYear") private var startYear = 2014
    @AppStorage("compare.itemA") private var typeA = HKQuantityTypeIdentifier.stepCount.rawValue
    @AppStorage("compare.itemB") private var typeB = HKQuantityTypeIdentifier.bodyMass.rawValue

    @State private var pointsA: [DatedValue] = []
    @State private var pointsB: [DatedValue] = []
    @State private var isLoading = true

    /// ホームのお気に入りの組み合わせから開くときは、最初のクエリが走る前に
    /// 保存値を書き換えておく(onAppearだと旧ペアのロードと競合する)
    init(presetA: String? = nil, presetB: String? = nil) {
        if let presetA { UserDefaults.standard.set(presetA, forKey: "compare.itemA") }
        if let presetB { UserDefaults.standard.set(presetB, forKey: "compare.itemB") }
    }

    /// 血圧(特別チャート)以外の表示可能な項目
    private var selectableItems: [HealthItem] {
        Health.shared.items.filter { $0.chart == .bar || $0.chart == .line || $0.chart == .range }
    }

    private var itemA: HealthItem? { selectableItems.first { $0.type.rawValue == typeA } }
    private var itemB: HealthItem? { selectableItems.first { $0.type.rawValue == typeB } }

    var body: some View {
        Form {
            Section {
                Picker("項目1", selection: $typeA) {
                    ForEach(selectableItems) { item in
                        Text(item.title).tag(item.type.rawValue)
                    }
                }
                Picker("項目2", selection: $typeB) {
                    ForEach(selectableItems) { item in
                        Text(item.title).tag(item.type.rawValue)
                    }
                }
            }

            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if pointsA.isEmpty || pointsB.isEmpty {
                    Text("比較できるデータがありません")
                        .foregroundColor(.gray)
                } else {
                    let pairs = matchedPairs()
                    correlationContent(pairs: pairs)
                    scatterContent(pairs: pairs)
                    if let itemA {
                        chartContent(item: itemA, points: pointsA)
                    }
                    if let itemB {
                        chartContent(item: itemB, points: pointsB)
                    }
                }
            } footer: {
                Text("月ごとの値(累積項目は1日の平均)を比較します。相関は関連の強さを示すもので、因果関係を意味しません。")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("2項目の比較")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ComparisonFavoriteButton(typeA: typeA, typeB: typeB)
            }
        }
        .task(id: typeA + "|" + typeB) {
            await load()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func correlationContent(pairs: [(Double, Double)]) -> some View {
        if pairs.count >= 3,
           let r = ChartAnalysis.pearsonCorrelation(xs: pairs.map { $0.0 }, ys: pairs.map { $0.1 }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("相関係数")
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "r = %.2f", r))
                        .fontWeight(.medium)
                        .font(.system(.title2, design: .rounded))
                    Text(ChartAnalysis.correlationLabel(r))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(pairs.count)ヶ月分")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } else {
            Text("重なる月が3ヶ月未満のため相関を計算できません")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    /// 同じ月の2項目の値を散布図で描き、回帰直線を重ねる
    @ViewBuilder
    private func scatterContent(pairs: [(Double, Double)]) -> some View {
        if pairs.count >= 3, let itemA, let itemB {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.dots.scatter")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("横: \(itemA.title)(\(itemA.sampleUnitText)) ・ 縦: \(itemB.title)(\(itemB.sampleUnitText))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Chart {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                        PointMark(
                            x: .value(itemA.title, pair.0),
                            y: .value(itemB.title, pair.1)
                        )
                        .foregroundStyle(itemB.color.opacity(0.55))
                        .symbolSize(30)
                    }
                    if let fit = ChartAnalysis.linearRegression(xs: pairs.map { $0.0 }, ys: pairs.map { $0.1 }),
                       let minX = pairs.map({ $0.0 }).min(),
                       let maxX = pairs.map({ $0.0 }).max(),
                       minX < maxX {
                        LineMark(x: .value("x", minX), y: .value("y", fit.slope * minX + fit.intercept))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.gray)
                        LineMark(x: .value("x", maxX), y: .value("y", fit.slope * maxX + fit.intercept))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.gray)
                    }
                }
                .chartXScale(domain: .automatic(includesZero: false))
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
            }
            .padding(.vertical, 4)
        }
    }

    private func chartContent(item: HealthItem, points: [DatedValue]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: item.image)
                    .font(.caption)
                    .foregroundColor(item.color)
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(item.color)
                Text(item.sampleUnitText)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Chart(points) { point in
                LineMark(
                    x: .value("日付", point.date),
                    y: .value(item.sampleUnitText, point.value)
                )
                .foregroundStyle(item.color)
                .interpolationMethod(.linear)
                .symbol(.circle)
                .symbolSize(20)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXScale(domain: xDomain)
            .frame(height: 170)
        }
        .padding(.vertical, 4)
    }

    private var xDomain: ClosedRange<Date> {
        let dates = (pointsA + pointsB).map { $0.date }
        guard let min = dates.min(), let max = dates.max() else {
            let now = Date()
            return now.addingTimeInterval(-1)...now
        }
        if min == max {
            // 1ヶ月分しかない場合は前後に15日広げて点が見えるようにする
            let margin: TimeInterval = 15 * 24 * 60 * 60
            return min.addingTimeInterval(-margin)...max.addingTimeInterval(margin)
        }
        return min...max
    }

    // MARK: - Data

    /// 同じ年月の値のペア
    private func matchedPairs() -> [(Double, Double)] {
        let calendar = Calendar.current
        func key(_ date: Date) -> String {
            let comps = calendar.dateComponents([.year, .month], from: date)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)"
        }
        let mapB = Dictionary(pointsB.map { (key($0.date), $0.value) },
                              uniquingKeysWith: { first, _ in first })
        return pointsA.compactMap { a in
            mapB[key(a.date)].map { (a.value, $0) }
        }
    }

    private func load() async {
        guard let itemA, let itemB else { return }
        isLoading = true

        pointsA = await loadPoints(for: itemA)
        pointsB = await loadPoints(for: itemB)

        isLoading = false
    }

    private func loadPoints(for item: HealthItem) async -> [DatedValue] {
        let stats = await HealthStatsService.shared.monthlyStats(for: item, startYear: startYear)
        return stats.compactMap { stat in
            let value: Double?
            if item.chart == .bar {
                value = stat.dailyAverage
            } else if let average = stat.average {
                value = average * item.displayMultiplier
            } else {
                value = nil
            }
            return value.map { DatedValue(date: stat.midDate, value: $0) }
        }
    }
}

/// 現在の組み合わせをお気に入りに登録・解除するボタン
struct ComparisonFavoriteButton: View {
    @ObservedObject var store = ComparisonPairs.shared
    let typeA: String
    let typeB: String

    var body: some View {
        Button {
            store.toggle(typeA, typeB)
        } label: {
            Image(systemName: store.contains(typeA, typeB) ? "star.fill" : "star")
                .foregroundColor(.yellow)
        }
        .disabled(typeA == typeB) // 同一項目同士は登録しない
    }
}

struct ComparisonChartView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ComparisonChartView()
        }
    }
}
