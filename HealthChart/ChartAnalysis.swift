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

    /// 年ごとにグループ化し、foldで1点に畳む(年の昇順)。
    /// 棒・折れ線・比較の年単位表示が同じグルーピングを共有するための土台。
    static func groupByYear<T>(_ items: [T], date: (T) -> Date, fold: (Int, [T]) -> T?) -> [T] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: items) { calendar.component(.year, from: date($0)) }
        return groups.keys.sorted().compactMap { year in
            groups[year].flatMap { fold(year, $0) }
        }
    }

    /// 年単位の点をプロットする位置(年の中央=7月1日)
    static func midOfYear(_ year: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: 7, day: 1))
    }

    /// 月次点列を年ごとの平均に畳む(dateは年の中央7月1日)
    static func yearlyMean(_ points: [DatedValue]) -> [DatedValue] {
        groupByYear(points, date: { $0.date }) { year, group in
            guard !group.isEmpty, let mid = midOfYear(year) else { return nil }
            let mean = group.reduce(0) { $0 + $1.value } / Double(group.count)
            return DatedValue(date: mid, value: mean)
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

    /// 線分をy≧0の範囲に切り詰める。負の部分は0との交点までで打ち切り、
    /// 全体が負なら空を返す(歩数やカロリーなど非負の棒グラフで、
    /// トレンド線が負に突き抜けて縦軸が負側へ広がるのを防ぐ)。
    static func clampSegmentToNonNegative(start: DatedValue, end: DatedValue) -> [DatedValue] {
        if start.value >= 0 && end.value >= 0 { return [start, end] }
        if start.value < 0 && end.value < 0 { return [] }

        // 0との交点を線形補間で求める
        let t = start.value / (start.value - end.value)
        let crossInterval = start.date.timeIntervalSince1970
            + t * (end.date.timeIntervalSince1970 - start.date.timeIntervalSince1970)
        let cross = DatedValue(date: Date(timeIntervalSince1970: crossInterval), value: 0)
        return start.value < 0 ? [cross, end] : [start, cross]
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
    /// 非負の値しか取らないチャート(棒グラフ)で、トレンド線を0未満に描かない
    var clampTrendToZero = false

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
            let segment = clampTrendToZero
                ? ChartAnalysis.clampSegmentToNonNegative(start: trend.start, end: trend.end)
                : [trend.start, trend.end]
            ForEach(segment) { point in
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
    @State private var goalDraft = ""
    @State private var showGoalAlert = false

    /// 目標の上限。桁違いの巨大数は軸が壊れて描画も重くなるため受け付けない
    static let maxGoal: Double = 9_999_999

    var body: some View {
        Toggle("移動平均（3/12区間）", isOn: $showMovingAverage)
        Toggle("トレンド", isOn: $showTrend)
        Toggle("統計（中央値・四分位）", isOn: $showStats)
        // 画面下端のインライン入力はキーボードと重なって窮屈になるため、
        // タップでアラートを開いて入力する(キーボードとレイアウトが干渉しない)
        Button {
            goalDraft = goalText
            showGoalAlert = true
        } label: {
            HStack {
                Text("目標")
                    .foregroundColor(.primary)
                Spacer()
                Text(goalText.isEmpty ? "なし" : goalText)
                    .foregroundColor(.gray)
            }
        }
        .alert("目標ライン", isPresented: $showGoalAlert) {
            TextField("なし", text: $goalDraft)
                .keyboardType(.decimalPad)
            Button("設定") {
                goalText = goalDraft
                saveGoal()
            }
            if goal != nil {
                Button("削除", role: .destructive) {
                    goalText = ""
                    saveGoal()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("チャートに目標の線を表示します")
        }
        .onAppear {
            if let value = UserDefaults.standard.object(forKey: goalKey) as? Double,
               value > 0, value <= Self.maxGoal {
                goal = value
                goalText = value == value.rounded() ?
                    String(Int(value)) : String(value)
            } else {
                UserDefaults.standard.removeObject(forKey: goalKey)
            }
        }
    }

    private func saveGoal() {
        let normalized = goalText.replacingOccurrences(of: ",", with: ".")
        if var value = Double(normalized), value > 0 {
            // 桁違いの巨大数は上限に丸める
            value = Swift.min(value, Self.maxGoal)
            goal = value
            goalText = value == value.rounded() ? String(Int(value)) : String(value)
            UserDefaults.standard.set(value, forKey: goalKey)
        } else {
            goal = nil
            goalText = ""
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
