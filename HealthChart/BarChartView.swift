//
//  BarChartView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/25.
//

import SwiftUI
import Charts
import HealthKit
import Sliders

struct BarChartView: View {
    let health: HealthItem

    @Environment(\.colorScheme) var colorScheme

    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    @State var value: Double?
    /// チャートのY軸は常に日平均スケールなので、平均線用に期間切替と独立して持つ
    @State private var dailyAverage: Double?

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
        var sum: Double
        var count: Int
    }
    @State var items: [ChartItem] = []

    let yearDateFormatter = DateFormatter()
    let monthDateFormatter = DateFormatter()
    let yearMonthDateFormatter = DateFormatter()

    @AppStorage("startYear") private var startYear = 2014
    @AppStorage("showMinMax") var showMinMax = false
    @AppStorage("showAverage") var showAverage = false
    @AppStorage("showMovingAverage") var showMovingAverage = false
    @AppStorage("showTrend") var showTrend = false
    @AppStorage("showStats") var showStats = false
    @State private var goal: Double? = nil

    @State private var selectedItem: ChartItem? = nil

    enum AveragePeriod: String, CaseIterable, Identifiable {
        case day = "日"
        case month = "月"
        case year = "年"
        var id: Self { self }

        var title: String {
            switch self {
            case .day: return "1日の平均"
            case .month: return "1ヶ月の平均"
            case .year: return "1年の平均"
            }
        }
    }
    @State private var period: AveragePeriod = .day

    @AppStorage("chartUnit") private var chartUnitRaw = ChartUnit.month.rawValue
    private var chartUnit: ChartUnit { ChartUnit(rawValue: chartUnitRaw) ?? .month }

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
                   shareTitle: health.title, shareSubtitle: shareSubtitleText, header: {
            Group {
                HStack {
                    Text(period.title)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                    Spacer()
                    Picker("期間", selection: $period) {
                        ForEach(AveragePeriod.allCases) { p in
                            Text(p.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
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
                let filteredItems = chartUnit == .year ? yearlyItems(monthlyItems) : monthlyItems

                GeometryReader { geometry in
                    Chart {
                        if !filteredItems.isEmpty {
                            let elapsed = Calendar.current.dateComponents(
                                [.month],
                                from: items[range.lowerBound].date,
                                to: items[range.upperBound].date).month ?? 0

                            let width = geometry.size.width / Double(elapsed + 12)
                            // 年単位は本数が少ないので太めの棒にする
                            let dimension = chartUnit == .year
                                ? MarkDimension(floatLiteral: Swift.min(26, Swift.max(8, geometry.size.width / Double(filteredItems.count * 2))))
                                : barWidth(width)

                            ForEach(filteredItems) {
                                BarMark (
                                    x: .value("日付", $0.date),
                                    y: .value(health.sampleUnitText, $0.value),
                                    width: dimension
                                )
                                    .accessibilityLabel("\($0.date)")
                                    .accessibilityValue("\($0.value) " + health.sampleUnitText)
                                    .foregroundStyle(health.color)
                            }
                        }
                        if showAverage,
                            let dailyAverage {
                            RuleMark(y: .value("平均", dailyAverage))
                                .lineStyle(StrokeStyle(lineWidth: 1))
                                .foregroundStyle(health.color)
                                .annotation(position: .trailing, alignment: .leading) {
                                Text(formatValue(dailyAverage, health.sampleValueFormat))
                                    .font(.caption)
                                    .foregroundColor(health.color) }

                        }
                        if showMinMax {
                            let max = filteredItems.max { a, b in
                                a.value < b.value
                            }

                            if let max {
                                RuleMark(y: .value("最大", max.value))
                                    .lineStyle(StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(health.color)
                                    .annotation(position: .trailing, alignment: .leading) {
                                    Text(formatValue(max.value, health.sampleValueFormat))
                                        .font(.caption)
                                        .foregroundColor(health.color) }
                            }

                        }
                        AnalysisMarks(points: filteredItems.map { DatedValue(date: $0.date, value: $0.value) },
                                      color: health.color,
                                      unitText: health.sampleUnitText,
                                      valueFormat: health.sampleValueFormat,
                                      showMovingAverage: showMovingAverage,
                                      showTrend: showTrend,
                                      showStats: showStats,
                                      goal: goal,
                                      clampTrendToZero: true)

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

                                        Text(formatValue(selectedItem.value, health.sampleValueFormat))
                                            .fontWeight(.medium)
                                            .font(.system(.largeTitle, design: .rounded))
                                        Text((chartUnit == .year ? yearDateFormatter : yearMonthDateFormatter).string(from: selectedItem.date))
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .fontWeight(.semibold)
                                        if let previous = ChartAnalysis.valueOneYearBefore(
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
                }

            }, footer: {
                ChartSettingsCard {
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
                    if let partialYearNote {
                        Text(partialYearNote)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Toggle("平均", isOn: $showAverage)
                    Toggle("最大", isOn: $showMinMax)
                    AnalysisOptionsView(goalKey: "goal." + health.type.rawValue, goal: $goal)

                }


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
            .onChange(of: period) {
                calculateAverage()
            }
    }

    /// 共有画像のサブタイトル（期間と単位）
    private var shareSubtitleText: String? {
        ChartLabels.shareSubtitle(period: periodText, unitText: health.sampleUnitText)
    }

    /// スライダーで選択中の期間(例「2023年11月〜2026年10月」)
    private var periodText: String? {
        guard items.indices.contains(range.lowerBound),
              items.indices.contains(range.upperBound) else { return nil }
        return ChartLabels.period(start: items[range.lowerBound].date,
                                  end: items[range.upperBound].date)
    }

    /// 年単位表示で端の年が部分集計になる場合の注記
    private var partialYearNote: String? {
        guard chartUnit == .year,
              items.indices.contains(range.lowerBound),
              items.indices.contains(range.upperBound) else { return nil }
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: items[range.lowerBound].date)
        let endMonth = calendar.component(.month, from: items[range.upperBound].date)
        guard startMonth != 1 || endMonth != 12 else { return nil }
        return ChartLabels.partialYearNote
    }

    private var rangePoints: [DatedValue] {
        guard items.indices.contains(range.lowerBound),
              items.indices.contains(range.upperBound) else { return [] }
        return items.filter {
            $0.date >= items[range.lowerBound].date &&
            $0.date <= items[range.upperBound].date
        }.map { DatedValue(date: $0.date, value: $0.value) }
    }

    private func barWidth(_ width: Double) -> MarkDimension {
        MarkDimension(floatLiteral: width < 3 ? 1 : (width < 4 ? 2 : (width < 5 ? 3 : (width < 6 ? 4 : (width < 7 ? 5 : (width < 8 ? 6 : (width < 9 ? 7 : 8)))))))
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

    /// 月次アイテムを年ごとに畳む。値は「年間合計÷データのあった日数」=1日あたりの平均
    private func yearlyItems(_ items: [ChartItem]) -> [ChartItem] {
        ChartAnalysis.groupByYear(items, date: { $0.date }) { year, group in
            let days = group.reduce(0) { $0 + $1.count }
            guard days > 0, let mid = ChartAnalysis.midOfYear(year) else { return nil }
            let sum = group.reduce(0) { $0 + $1.sum }
            return ChartItem(value: sum / Double(days), date: mid,
                             startDate: group.map(\.startDate).min() ?? mid,
                             endDate: group.map(\.endDate).max() ?? mid,
                             sum: sum, count: days)
        }
    }

    private func calculateAverage() {

        var sum: Double = 0
        var dayCount: Int = 0
        var monthCount: Int = 0

        for i in range where items.indices.contains(i) {
            sum += items[i].sum
            dayCount += items[i].count
            monthCount += 1
        }

        dailyAverage = dayCount > 0 ? sum / Double(dayCount) : nil

        switch period {
        case .day:
            value = dailyAverage
        case .month:
            value = monthCount > 0 ? sum / Double(monthCount) : nil
        case .year:
            // 端数の年をそのまま年数で割ると過小になるため、月平均×12で年換算する
            value = monthCount > 0 ? sum / Double(monthCount) * 12 : nil
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
            guard let dailyAverage = stat.dailyAverage else { return nil }
            return ChartItem(
                value: dailyAverage,
                date: stat.midDate,
                startDate: stat.startDate,
                endDate: stat.endDate,
                sum: stat.sum,
                count: stat.dayCount)
        }

        isEmpty = items.isEmpty
        isLoading = false
        isCompleted = true

        if !items.isEmpty {
            range = 0...items.count - 1
            inRange = 0...items.count - 1
            calculateAverage()
        } else {
            value = nil
        }
    }
}

struct BarChartView_Previews: PreviewProvider {
    static var previews: some View {
        BarChartView(health: Health.shared.items.first(where: { $0.type == .distanceWalkingRunning })!)
    }
}
