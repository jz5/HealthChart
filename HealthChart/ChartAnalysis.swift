//
//  ChartAnalysis.swift
//  HealthChart
//
//  チャートに重ねる分析値(移動平均・回帰・統計・相関)の純粋関数群。
//

import Foundation
import SwiftUI
import Charts

struct DatedValue: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// チャートのx軸単位(月ごと/年ごと)。全チャートで共有する
enum ChartUnit: String, CaseIterable, Identifiable {
    case month
    case year
    var id: Self { self }
    var title: String { self == .month ? "月" : "年" }
}

enum ChartAnalysis {

    /// 月次点列を年ごとの平均に畳む(dateは年の中央7月1日)
    static func yearlyMean(_ points: [DatedValue]) -> [DatedValue] {
        let calendar = Calendar.current
        var groups: [Int: (sum: Double, count: Int)] = [:]
        for point in points {
            let year = calendar.component(.year, from: point.date)
            var g = groups[year] ?? (0, 0)
            g.sum += point.value
            g.count += 1
            groups[year] = g
        }
        return groups.keys.sorted().compactMap { year in
            guard let g = groups[year], g.count > 0,
                  let mid = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) else { return nil }
            return DatedValue(date: mid, value: g.sum / Double(g.count))
        }
    }

    /// 末尾windowサイズの移動平均。先頭の(window-1)点は含まれない。
    static func movingAverage(_ points: [DatedValue], window: Int) -> [DatedValue] {
        guard window > 0, points.count >= window else { return [] }
        var result: [DatedValue] = []
        var sum = 0.0
        for (i, point) in points.enumerated() {
            sum += point.value
            if i >= window {
                sum -= points[i - window].value
            }
            if i >= window - 1 {
                result.append(DatedValue(date: point.date, value: sum / Double(window)))
            }
        }
        return result
    }

    /// 最小二乗法。xsは任意の単位(ここでは「月」)。
    static func linearRegression(xs: [Double], ys: [Double]) -> (slope: Double, intercept: Double)? {
        guard xs.count == ys.count, xs.count >= 2 else { return nil }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var sxx = 0.0
        var sxy = 0.0
        for i in xs.indices {
            let dx = xs[i] - meanX
            sxx += dx * dx
            sxy += dx * (ys[i] - meanY)
        }
        guard sxx > 0 else { return nil }
        let slope = sxy / sxx
        return (slope, meanY - slope * meanX)
    }

    /// 基準日からの経過月数(30.44日=平均月で換算)
    static func monthsSince(_ reference: Date, _ date: Date) -> Double {
        date.timeIntervalSince(reference) / (30.44 * 24 * 60 * 60)
    }

    /// 点列に対する回帰直線の両端点と「1ヶ月あたりの傾き」
    static func trendLine(_ points: [DatedValue]) -> (start: DatedValue, end: DatedValue, slopePerMonth: Double)? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        let xs = points.map { monthsSince(first.date, $0.date) }
        let ys = points.map { $0.value }
        guard let fit = linearRegression(xs: xs, ys: ys) else { return nil }
        let x2 = monthsSince(first.date, last.date)
        return (
            DatedValue(date: first.date, value: fit.intercept),
            DatedValue(date: last.date, value: fit.intercept + fit.slope * x2),
            fit.slope
        )
    }

    static func median(_ values: [Double]) -> Double? {
        percentile(values, 50)
    }

    /// 線形補間パーセンタイル(0〜100)
    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count == 1 { return sorted[0] }
        let rank = p / 100 * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return sorted[lower] }
        let fraction = rank - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }

    /// 標本標準偏差
    static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let n = Double(values.count)
        let mean = values.reduce(0, +) / n
        let sumSq = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sumSq / (n - 1)).squareRoot()
    }

    /// ピアソン相関係数
    static func pearsonCorrelation(xs: [Double], ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 3 else { return nil }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var sxx = 0.0
        var syy = 0.0
        var sxy = 0.0
        for i in xs.indices {
            let dx = xs[i] - meanX
            let dy = ys[i] - meanY
            sxx += dx * dx
            syy += dy * dy
            sxy += dx * dy
        }
        guard sxx > 0, syy > 0 else { return nil }
        return sxy / (sxx * syy).squareRoot()
    }

    static func correlationLabel(_ r: Double) -> String {
        let strength: String
        switch abs(r) {
        case 0.7...: strength = "強い"
        case 0.4..<0.7: strength = "中程度の"
        case 0.2..<0.4: strength = "弱い"
        default: return "ほぼ相関なし"
        }
        return strength + (r > 0 ? "正の相関" : "負の相関")
    }

    /// 前年同月の値(同じ年月の点があれば返す)
    static func valueOneYearBefore(of date: Date, in points: [DatedValue]) -> Double? {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .year, value: -1, to: date) else { return nil }
        let targetComps = calendar.dateComponents([.year, .month], from: target)
        return points.first {
            let comps = calendar.dateComponents([.year, .month], from: $0.date)
            return comps.year == targetComps.year && comps.month == targetComps.month
        }?.value
    }

    /// 前年同月比(%)。前年値が0のときはnil。
    static func yearOverYearChange(current: Double, previous: Double) -> Double? {
        guard previous != 0 else { return nil }
        return (current - previous) / abs(previous) * 100
    }
}

/// 折れ線・棒チャートに重ねる分析マーク(移動平均・トレンド・統計帯・目標)
struct AnalysisMarks: ChartContent {
    let points: [DatedValue]
    let color: Color
    let unitText: String
    let valueFormat: String
    var showMovingAverage = false
    var showTrend = false
    var showStats = false
    var goal: Double? = nil

    var body: some ChartContent {
        if showMovingAverage {
            ForEach(ChartAnalysis.movingAverage(points, window: 3)) { point in
                LineMark(
                    x: .value("日付", point.date),
                    y: .value(unitText, point.value),
                    series: .value("系列", "3区間平均")
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(color.opacity(0.8))
                .interpolationMethod(.catmullRom)
            }
            ForEach(ChartAnalysis.movingAverage(points, window: 12)) { point in
                LineMark(
                    x: .value("日付", point.date),
                    y: .value(unitText, point.value),
                    series: .value("系列", "12区間平均")
                )
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .foregroundStyle(color.opacity(0.45))
                .interpolationMethod(.catmullRom)
            }
        }
        if showTrend, let trend = ChartAnalysis.trendLine(points) {
            ForEach([trend.start, trend.end]) { point in
                LineMark(
                    x: .value("日付", point.date),
                    y: .value(unitText, point.value),
                    series: .value("系列", "トレンド")
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(.gray)
            }
        }
        if showStats {
            let values = points.map { $0.value }
            if let p25 = ChartAnalysis.percentile(values, 25),
               let p75 = ChartAnalysis.percentile(values, 75) {
                RectangleMark(
                    yStart: .value(unitText, p25),
                    yEnd: .value(unitText, p75)
                )
                .foregroundStyle(color.opacity(0.08))
            }
            if let median = ChartAnalysis.median(values) {
                RuleMark(y: .value("中央値", median))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(color.opacity(0.7))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(formatValue(median, valueFormat))
                            .font(.caption2)
                            .foregroundColor(color.opacity(0.7))
                    }
            }
        }
        if let goal {
            RuleMark(y: .value("目標", goal))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                .foregroundStyle(.teal)
                .annotation(position: .topTrailing, alignment: .trailing) {
                    Text("目標 " + formatValue(goal, valueFormat))
                        .font(.caption2)
                        .foregroundColor(.teal)
                }
        }
    }
}

/// グラフの単位(月/年)を切り替えるフッター行。年にすると点が年平均に畳まれ、
/// 長期のトレンドや移動平均が読み取りやすくなる
struct ChartUnitPicker: View {
    @Binding var chartUnitRaw: String

    var body: some View {
        HStack {
            Text("グラフの単位")
            Spacer()
            Picker("グラフの単位", selection: $chartUnitRaw) {
                ForEach(ChartUnit.allCases) { unit in
                    Text(unit.title).tag(unit.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 120)
        }
    }
}

/// 分析トグルと目標値入力をまとめたフッター部品
struct AnalysisOptionsView: View {
    @AppStorage("showMovingAverage") var showMovingAverage = false
    @AppStorage("showTrend") var showTrend = false
    @AppStorage("showStats") var showStats = false

    let goalKey: String
    @Binding var goal: Double?
    @State private var goalText = ""
    @FocusState private var goalFocused: Bool

    var body: some View {
        Toggle("移動平均(3/12区間)", isOn: $showMovingAverage)
        Toggle("トレンド", isOn: $showTrend)
        Toggle("統計(中央値・四分位)", isOn: $showStats)
        HStack {
            Text("目標")
            TextField("なし", text: $goalText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($goalFocused)
                .onChange(of: goalText) {
                    saveGoal()
                }
                .toolbar {
                    // テンキーには閉じるキーがないため「完了」を付ける
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完了") {
                            goalFocused = false
                        }
                    }
                }
            if goal != nil {
                Button {
                    goalText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            if let value = UserDefaults.standard.object(forKey: goalKey) as? Double {
                goal = value
                goalText = value == value.rounded() ?
                    String(Int(value)) : String(value)
            }
        }
    }

    private func saveGoal() {
        let normalized = goalText.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized), value > 0 {
            goal = value
            UserDefaults.standard.set(value, forKey: goalKey)
        } else {
            goal = nil
            UserDefaults.standard.removeObject(forKey: goalKey)
        }
    }
}

/// ヘッダーに出す分析サマリー(トレンド傾き・中央値・標準偏差)
struct AnalysisSummaryView: View {
    let points: [DatedValue]
    let unitText: String
    let valueFormat: String

    @AppStorage("showTrend") var showTrend = false
    @AppStorage("showStats") var showStats = false

    var body: some View {
        Group {
            if showTrend, let trend = ChartAnalysis.trendLine(points) {
                Text("トレンド: " + slopeText(trend.slopePerMonth))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            if showStats {
                let values = points.map { $0.value }
                if let median = ChartAnalysis.median(values),
                   let sd = ChartAnalysis.standardDeviation(values) {
                    Text("中央値 " + formatValue(median, valueFormat) + unitText +
                         " ・ 標準偏差 " + formatValue(sd, valueFormat))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private func slopeText(_ slope: Double) -> String {
        let sign = slope >= 0 ? "+" : ""
        return sign + formatValue(slope, valueFormat) + unitText + "/月"
    }
}
