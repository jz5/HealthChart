//
//  LineChartView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/19.
//

import SwiftUI
import Charts
import HealthKit
import Sliders

struct LineChartView: View {
    let health: HealthItem

    @Environment(\.colorScheme) var colorScheme

    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    @State var value: Double?

    @State var isLoading = true
    @State var isEmpty = false
    @State var isCompleted = false
    @State var requested = false
    @State private var loadProgress: Double?

    struct ChartItem: Identifiable {
        var id = UUID()
        var value: Double
        var date: Date
        var startDate: Date
        var endDate: Date
    }
    @State var items: [ChartItem] = []

    let yearDateFormatter = DateFormatter()
    let monthDateFormatter = DateFormatter()
    let yearMonthDateFormatter = DateFormatter()

    @AppStorage("startYear") private var startYear = 2014
    @AppStorage("showMinMax") var showMinMax = false
    @AppStorage("showAverage") var showAverage = false
    @AppStorage("showSymbols") var showSymbols = true
    @AppStorage("showMovingAverage") var showMovingAverage = false
    @AppStorage("showTrend") var showTrend = false
    @AppStorage("showStats") var showStats = false
    @State private var goal: Double? = nil

    @State private var selectedItem: ChartItem? = nil

    @AppStorage("chartUnit") private var chartUnitRaw = ChartUnit.month.rawValue
    private var chartUnit: ChartUnit { ChartUnit(rawValue: chartUnitRaw) ?? .month }

    /// 相対表示: 実数値の代わりに期間最初の値からの差分で描く(SNS共有向け)
    @AppStorage("relativeDisplay") private var relativeDisplay = false

    /// スライダーで選択中の期間(例「2023年11月〜2026年10月」)
    private var periodText: String? {
        guard items.indices.contains(range.lowerBound),
              items.indices.contains(range.upperBound) else { return nil }
        let start = items[range.lowerBound].date
        let end = items[range.upperBound].date
        if range.lowerBound == range.upperBound {
            return yearMonthDateFormatter.string(from: start)
        }
        return yearMonthDateFormatter.string(from: start) + "〜" + yearMonthDateFormatter.string(from: end)
    }

    /// 月次アイテムを年ごとの平均に畳む
    private func yearlyItems(_ items: [ChartItem]) -> [ChartItem] {
        let calendar = Calendar.current
        var groups: [Int: (sum: Double, count: Int, start: Date, end: Date)] = [:]
        for item in items {
            let year = calendar.component(.year, from: item.date)
            var g = groups[year] ?? (0, 0, item.startDate, item.endDate)
            g.sum += item.value
            g.count += 1
            g.start = Swift.min(g.start, item.startDate)
            g.end = Swift.max(g.end, item.endDate)
            groups[year] = g
        }
        return groups.keys.sorted().compactMap { year in
            guard let g = groups[year], g.count > 0,
                  let mid = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) else { return nil }
            return ChartItem(value: g.sum / Double(g.count), date: mid,
                             startDate: g.start, endDate: g.end)
        }
    }

    init(health: HealthItem) {
        self.health = health

        _range = State(initialValue: 0...0)
        _inRange = State(initialValue: 0...0)

        yearMonthDateFormatter.locale = Locale(identifier: "ja_JP")
        yearMonthDateFormatter.setLocalizedDateFormatFromTemplate("yMMM")

        monthDateFormatter.locale = Locale(identifier: "ja_JP")
        monthDateFormatter.setLocalizedDateFormatFromTemplate("MMM")

        yearDateFormatter.locale = Locale(identifier: "ja_JP")
        yearDateFormatter.setLocalizedDateFormatFromTemplate("y")
    }

    var body: some View {
        LayoutView(isLoading: $isLoading, isEmpty: $isEmpty, requested: $requested, progress: $loadProgress,
                   shareTitle: health.title, shareSubtitle: periodText, header: {
            Group {
                Text(health.sampleValueTitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                    .padding(.top)

                HStack(alignment: .bottom) {
                    if value == nil {
                        Text("データなし")
                            .fontWeight(.medium)
                            .font(.system(.largeTitle, design: .rounded))

                    } else {
                        Text(formatValue(value ?? 0, health.sampleValueFormat))
                            .fontWeight(.medium)
                            .font(.system(.largeTitle, design: .rounded))
                        +
                        Text(health.sampleUnitText)
                            .foregroundColor(.gray)
                            .fontWeight(.semibold)
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
                if !items.isEmpty {
                    if range.lowerBound == range.upperBound {
                        Text(yearMonthDateFormatter.string(from: items[range.lowerBound].date))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .fontWeight(.semibold)
                    } else {
                        Text(
                            yearMonthDateFormatter.string(from: items[range.lowerBound].date) + "〜" +
                            yearMonthDateFormatter.string(from: items[range.upperBound].date))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                    }
                }
                AnalysisSummaryView(points: rangePoints,
                                    unitText: health.sampleUnitText,
                                    valueFormat: health.sampleValueFormat)
            }


        }, chart: {
            let monthlyItems = items.filter {
                $0.date >= items[range.lowerBound].date &&
                $0.date <= items[range.upperBound].date
            }
            let unitItems = chartUnit == .year ? yearlyItems(monthlyItems) : monthlyItems
            // 相対表示: 期間最初の値を基準(0)にした差分へ変換する(共有時に実数値を出さないため)
            let base = relativeDisplay ? (unitItems.first?.value ?? 0) : 0
            let filteredItems = relativeDisplay ? unitItems.map {
                ChartItem(value: $0.value - base, date: $0.date, startDate: $0.startDate, endDate: $0.endDate)
            } : unitItems

            Chart {
                if relativeDisplay {
                    RuleMark(y: .value("基準", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(.green.opacity(0.7))
                        .annotation(position: .topLeading, alignment: .leading) {
                            Text("基準")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                }
                ForEach(filteredItems) {
                    LineMark (
                        x: .value("日付", $0.date),
                        y: .value(health.sampleUnitText, $0.value)
                    )
                    .interpolationMethod(.linear)
                    .symbol(.circle)
                    .symbolSize(showSymbols ? 60 : 0)
                    .accessibilityLabel("\($0.date)")
                    .accessibilityValue("\($0.value) " + health.sampleUnitText)
                    .foregroundStyle(health.color)
                }

                if showAverage,
                   let rawValue = value {
                    let value = rawValue - base
                    RuleMark(y: .value("平均", value))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(health.color)
                        .annotation(position: .trailing, alignment: .leading) {
                                            Text(formatValue(value, health.sampleValueFormat))
                                            .font(.caption)
                                            .foregroundColor(health.color)}

                }
                if showMinMax {
                    let min = filteredItems.min { a, b in
                        a.value < b.value
                    }
                    let max = filteredItems.max { a, b in
                        a.value < b.value
                    }

                    if let min {
                        RuleMark(y: .value("最小", min.value))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(health.color)
                            .annotation(position: .trailing, alignment: .leading) {
                                                Text(formatValue(min.value, health.sampleValueFormat))
                                                .font(.caption)
                                                .foregroundColor(health.color)}
                    }
                    if let max {
                        RuleMark(y: .value("最大", max.value))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(health.color)
                            .annotation(position: .trailing, alignment: .leading) {
                                                Text(formatValue(max.value, health.sampleValueFormat))
                                                .font(.caption)
                                                .foregroundColor(health.color)}
                    }

                }
                AnalysisMarks(points: filteredItems.map { DatedValue(date: $0.date, value: $0.value) },
                              color: health.color,
                              unitText: health.sampleUnitText,
                              valueFormat: health.sampleValueFormat,
                              showMovingAverage: showMovingAverage,
                              showTrend: showTrend,
                              showStats: showStats,
                              goal: goal.map { $0 - base })
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { value in
                    if let date = value.as(Date.self) {

                        let elapsed = Calendar.current.dateComponents(
                            [.year],
                            from: items[range.lowerBound].date,
                            to: items[range.upperBound].date).year ?? 0

                        if elapsed < 1 {
                            AxisGridLine(stroke: .init(lineWidth: 0.5))
                            AxisTick(stroke: .init(lineWidth: 0.5))
                            AxisValueLabel() {
                                Text(monthDateFormatter.string(from: date))
                            }
                        } else {
                            let month = Calendar.current.component(.month, from: date)
                            if month == 1 {
                                AxisGridLine(stroke: .init(lineWidth: 0.5))
                                AxisTick(stroke: .init(lineWidth: 0.5))
                                AxisValueLabel() {
                                    Text(yearDateFormatter.string(from: date))
                                }
                            } else {
                                if month == 7 || elapsed < 6 {
                                    AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2]))
                                }
                            }
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    let element = findElement(location: value.location, proxy: proxy, geometry: geo, in: filteredItems)
                                    if selectedItem?.date == element?.date {
                                        // If tapping the same element, clear the selection.
                                        selectedItem = nil
                                    } else {
                                        selectedItem = element
                                    }
                                }
                                .exclusively(
                                    before: DragGesture()
                                        .onChanged { value in
                                            selectedItem = findElement(location: value.location, proxy: proxy, geometry: geo, in: filteredItems)
                                        }
                                )
                        )
                }
            }
            .chartBackground { proxy in
                ZStack(alignment: .topLeading) {
                    GeometryReader { geo in
                        if let selectedItem,
                           let plotFrame = proxy.plotFrame {
                            let dateInterval = Calendar.current.dateInterval(of: .day, for: selectedItem.date)!
                            let startPositionX1 = proxy.position(forX: dateInterval.start) ?? 0

                            let lineX = startPositionX1 + geo[plotFrame].origin.x
                            let lineHeight = geo[plotFrame].maxY
                            let boxWidth: CGFloat = 140
                            let boxOffset = max(0, min(geo.size.width - boxWidth, lineX - boxWidth / 2))

                            Rectangle()
                                .fill(Color.lolipopBarColor)
                                .frame(width: 2, height: lineHeight)
                                .position(x: lineX, y: lineHeight / 2)

                            VStack(alignment: .center) {

                                Text((relativeDisplay && selectedItem.value > 0 ? "+" : "") +
                                     formatValue(selectedItem.value, health.sampleValueFormat))
                                    .fontWeight(.medium)
                                    .font(.system(.largeTitle, design: .rounded))
                                Text((chartUnit == .year ? yearDateFormatter : yearMonthDateFormatter).string(from: selectedItem.date))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .fontWeight(.semibold)
                                if !relativeDisplay,
                                   let previous = ChartAnalysis.valueOneYearBefore(
                                        of: selectedItem.date,
                                        in: (chartUnit == .year ? yearlyItems(items) : items).map { DatedValue(date: $0.date, value: $0.value) }),
                                   let change = ChartAnalysis.yearOverYearChange(
                                        current: selectedItem.value, previous: previous) {
                                    Text(String(format: "前年比 %+.1f%%", change))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: boxWidth, alignment: .center)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.lolipopBackgroundColor)

                                }
                                .padding(.horizontal, -8)
                                .padding(.vertical, -4)
                            }
                            .offset(x: boxOffset)
                        }
                    }
                }
            }

        }, footer: {
            Form {
                MonthRangeSlider(range: $range, inRange: inRange,
                                 disabled: !isCompleted || isEmpty,
                                 periodText: periodText,
                                 onEditingChanged: { editing in
                    if editing {
                            selectedItem = nil
                    } else {
                        calculateAverage()
                    }
                })

                ChartUnitPicker(chartUnitRaw: $chartUnitRaw)
                Toggle("相対表示(期間最初の値を基準)", isOn: $relativeDisplay)
                Toggle("平均", isOn: $showAverage)
                Toggle("最小・最大", isOn: $showMinMax)
                Toggle("シンボル", isOn: $showSymbols)
                AnalysisOptionsView(goalKey: "goal." + health.type.rawValue, goal: $goal)

            }
            .frame(height: 480)
            .scrollContentBackground(.hidden)


        })
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(health.title)
        .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
        .task {
            await load()
        }
        .onChange(of: requested) {
            Task {
                await load()
            }
        }
    }

    private var rangePoints: [DatedValue] {
        guard items.indices.contains(range.lowerBound),
              items.indices.contains(range.upperBound) else { return [] }
        return items.filter {
            $0.date >= items[range.lowerBound].date &&
            $0.date <= items[range.upperBound].date
        }.map { DatedValue(date: $0.date, value: $0.value) }
    }

    private func findElement(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy, in candidates: [ChartItem]) -> ChartItem? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let relativeXPosition = location.x - geometry[plotFrame].origin.x
        if let date = proxy.value(atX: relativeXPosition) as Date? {
            // Find the closest date element.
            var minDistance: TimeInterval = .infinity
            var nearestItem: ChartItem? = nil
            for item in candidates {
                let distance = abs(item.date.distance(to: date))
                if distance < minDistance {
                    minDistance = distance
                    nearestItem = item
                }
            }
            return nearestItem
        }
        return nil
    }

    private func calculateAverage() {
        guard items.indices.contains(range.lowerBound),
              items.indices.contains(range.upperBound) else {
            value = nil
            return
        }

        if range.lowerBound == range.upperBound {
            value = items[range.lowerBound].value
            return
        }

        // 選択期間の正確な平均はHealthKitに問い合わせる(単一の集計クエリなので軽い)
        let start = items[range.lowerBound].startDate
        let end = items[range.upperBound].endDate

        Task {
            let average = await HealthStatsService.shared.discreteAverage(for: health, start: start, end: end)
            value = average.map { $0 * health.displayMultiplier }
        }
    }

    private func load() async {
        isLoading = true
        isCompleted = false
        selectedItem = nil
        loadProgress = nil

        let stats = await HealthStatsService.shared.monthlyStats(for: health, startYear: startYear) { p in
            Task { @MainActor in loadProgress = p }
        }

        items = stats.compactMap { stat in
            guard let average = stat.average else { return nil }
            return ChartItem(
                value: average * health.displayMultiplier,
                date: stat.midDate,
                startDate: stat.startDate,
                endDate: stat.endDate)
        }

        isEmpty = items.isEmpty
        isLoading = false
        isCompleted = true

        if !items.isEmpty {
            let max = items.count - 1
            range = 0...max
            inRange = 0...max
            calculateAverage()
        } else {
            value = nil
        }
    }
}

struct LineChartView_Previews: PreviewProvider {
    static var previews: some View {
        LineChartView(health: Health.shared.items.first(where: { $0.type == .bodyMass })!)
    }
}
