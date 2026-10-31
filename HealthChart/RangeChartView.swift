//
//  RangeChartView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/25.
//

import SwiftUI
import Charts
import HealthKit
import Sliders

struct RangeChartView: View {
    let health: HealthItem

    @Environment(\.colorScheme) var colorScheme

    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    @State var minValue: Double?
    @State var maxValue: Double?

    @State var isLoading = true
    @State var isEmpty = false
    @State var isCompleted = false
    @State var requested = false
    @State private var loadProgress: Double?

    struct ChartItem: Identifiable {
        var id = UUID()
        var date: Date
        var startDate: Date
        var endDate: Date
        var min: Double
        var max: Double
    }
    @State var items: [ChartItem] = []

    let yearDateFormatter = DateFormatter()
    let monthDateFormatter = DateFormatter()
    let yearMonthDateFormatter = DateFormatter()

    @AppStorage("startYear") private var startYear = 2014

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
        LayoutView(isLoading: $isLoading, isEmpty: $isEmpty, requested: $requested, progress: $loadProgress,
                   shareTitle: health.title, shareSubtitle: periodText, header: {
            Group {
                Text(health.sampleValueTitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                    .padding(.top)

                HStack(alignment: .bottom) {
                    if minValue == nil || maxValue == nil {
                        Text("データなし")
                            .fontWeight(.medium)
                            .font(.system(.largeTitle, design: .rounded))

                    } else {
                        Text(rangeText(min: minValue ?? 0, max: maxValue ?? 0))
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
            }

        }, chart: {
                let filteredItems = items.filter {
                    $0.date >= items[range.lowerBound].date &&
                        $0.date <= items[range.upperBound].date
                }

                GeometryReader { geometry in
                    Chart {
                        if !filteredItems.isEmpty {
                            let elapsed = Calendar.current.dateComponents(
                                [.month],
                                from: items[range.lowerBound].date,
                                to: items[range.upperBound].date).month ?? 0

                            let width = geometry.size.width / Double(elapsed + 12)

                            ForEach(filteredItems) {
                                BarMark (
                                    x: .value("日付", $0.date),
                                    yStart: .value(health.sampleUnitText, $0.min),
                                    yEnd: .value(health.sampleUnitText, $0.max),
                                    width: barWidth(width)
                                )
                                .clipShape(Capsule())
                                .foregroundStyle(health.color.gradient)
                                .accessibilityLabel("\($0.date)")
                                .accessibilityValue("\($0.min)-\($0.max) " + health.sampleUnitText)
                            }
                        }
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
                                    let boxWidth: CGFloat = 160
                                    let boxOffset = max(0, min(geo.size.width - boxWidth, lineX - boxWidth / 2))

                                    Rectangle()
                                        .fill(Color.lolipopBarColor)
                                        .frame(width: 2, height: lineHeight)
                                        .position(x: lineX, y: lineHeight / 2)

                                    VStack(alignment: .center) {

                                        Text(rangeText(min: selectedItem.min, max: selectedItem.max))
                                            .fontWeight(.medium)
                                            .font(.system(.largeTitle, design: .rounded))
                                        Text(yearMonthDateFormatter.string(from: selectedItem.date))
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .fontWeight(.semibold)
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
                Form {
                    MonthRangeSlider(range: $range, inRange: inRange,
                        disabled: !isCompleted || isEmpty,
                        periodText: periodText,
                        onEditingChanged: { editing in
                            if editing {
                                selectedItem = nil
                            } else {
                                calculateMinMax()
                            }
                        })

                }
                    .frame(height: 150)
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

    private func rangeText(min: Double, max: Double) -> String {
        if min == max {
            return formatValue(min, health.sampleValueFormat)
        }
        return formatValue(min, health.sampleValueFormat) + "–" + formatValue(max, health.sampleValueFormat)
    }

    private func barWidth(_ width: Double) -> MarkDimension {
        MarkDimension(floatLiteral: width < 3 ? 1 : (width < 4 ? 2 : (width < 5 ? 3 : (width < 6 ? 4 : (width < 7 ? 5 : (width < 8 ? 6 : (width < 9 ? 7 : 8)))))))
    }

    private func findElement(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy, in candidates: [ChartItem]) -> ChartItem? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let relativeXPosition = location.x - geometry[plotFrame].origin.x
        if let date = proxy.value(atX: relativeXPosition) as Date? {
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

    private func calculateMinMax() {
        guard items.indices.contains(range.lowerBound),
              items.indices.contains(range.upperBound) else {
            minValue = nil
            maxValue = nil
            return
        }

        let filteredItems = items.filter {
            $0.date >= items[range.lowerBound].date &&
                $0.date <= items[range.upperBound].date
        }
        minValue = filteredItems.min { $0.min < $1.min }?.min
        maxValue = filteredItems.max { $0.max < $1.max }?.max
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
            guard let min = stat.minValue, let max = stat.maxValue else { return nil }
            return ChartItem(
                date: stat.midDate,
                startDate: stat.startDate,
                endDate: stat.endDate,
                min: min * health.displayMultiplier,
                max: max * health.displayMultiplier)
        }

        isEmpty = items.isEmpty
        isLoading = false
        isCompleted = true

        if !items.isEmpty {
            range = 0...items.count - 1
            inRange = 0...items.count - 1
            calculateMinMax()
        } else {
            minValue = nil
            maxValue = nil
        }
    }
}

struct RangeChartView_Previews: PreviewProvider {
    static var previews: some View {
        RangeChartView(health: Health.shared.items.first(where: { $0.type == .heartRate })!)
    }
}
