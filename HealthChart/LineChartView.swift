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
        LayoutView(isLoading: $isLoading, isEmpty: $isEmpty, requested: $requested, header: {
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
                        Text(String(format: health.sampleValueFormat, value ?? 0))
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
            let filteredItems = items.filter {
                $0.date >= items[range.lowerBound].date &&
                $0.date <= items[range.upperBound].date
            }

            Chart {
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
                   let value {
                    RuleMark(y: .value("平均", value))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(health.color)
                        .annotation(position: .trailing, alignment: .leading) {
                                            Text(String(format: health.sampleValueFormat, value))
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
                                                Text(String(format: health.sampleValueFormat, min.value))
                                                .font(.caption)
                                                .foregroundColor(health.color)}
                    }
                    if let max {
                        RuleMark(y: .value("最大", max.value))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(health.color)
                            .annotation(position: .trailing, alignment: .leading) {
                                                Text(String(format: health.sampleValueFormat, max.value))
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
                              goal: goal)
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

                                Text(String(format: health.sampleValueFormat, selectedItem.value))
                                    .fontWeight(.medium)
                                    .font(.system(.largeTitle, design: .rounded))
                                Text(yearMonthDateFormatter.string(from: selectedItem.date))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .fontWeight(.semibold)
                                if let previous = ChartAnalysis.valueOneYearBefore(
                                        of: selectedItem.date,
                                        in: items.map { DatedValue(date: $0.date, value: $0.value) }),
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
                RangeSlider(range: $range, in: inRange, step: 1,
                            onEditingChanged: { editing in
                    if editing {
                            selectedItem = nil
                    } else {
                        calculateAverage()
                    }
                }).disabled(!isCompleted || isEmpty)

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

        let stats = await HealthStatsService.shared.monthlyStats(for: health, startYear: startYear)

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
