//
//  BloodPressureChartView.swift
//  HealthChart
//
//  Created by jz5 on 2023/03/11.
//

import SwiftUI
import Charts
import HealthKit
import Sliders

struct BloodPressureChartView: View {
    let health: HealthItem

    @Environment(\.colorScheme) var colorScheme

    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>

    @State var systolicMin: Double?
    @State var systolicMax: Double?
    @State var diastolicMin: Double?
    @State var diastolicMax: Double?

    @State var isLoading = true
    @State var isEmpty = false
    @State var isCompleted = false
    @State var requested = false
    @State private var loadProgress: Double?

    struct ChartItem: Identifiable {
        var id = UUID()
        //var value: Double
        var date: Date
        var startDate: Date
        var endDate: Date
        //var sum: Double
        //var count: Int

        var min: Double
        var max: Double
    }
    @State var SystolicItems: [ChartItem] = [] // 最高血圧
    @State var DiastolicItems: [ChartItem] = [] // 最低血圧

    let yearDateFormatter = DateFormatter()
    let monthDateFormatter = DateFormatter()
    let yearMonthDateFormatter = DateFormatter()

    @AppStorage("startYear") private var startYear = 2014
    @AppStorage("showMinMax") var showMinMax = false
    @AppStorage("showBPGuide") var showBPGuide = true

    @State private var selectedSystolicItem: ChartItem? = nil
    @State private var selectedDiastolicItem: ChartItem? = nil

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

                valuesContent(systolicMin: systolicMin, systolicMax: systolicMax, diastolicMin: diastolicMin, diastolicMax: diastolicMax)

                if !SystolicItems.isEmpty {
                    if range.lowerBound == range.upperBound {
                        Text(yearMonthDateFormatter.string(from: SystolicItems[range.lowerBound].date))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .fontWeight(.semibold)
                    } else {
                        Text(
                            yearMonthDateFormatter.string(from: SystolicItems[range.lowerBound].date) + "〜" +
                                yearMonthDateFormatter.string(from: SystolicItems[range.upperBound].date))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .fontWeight(.semibold)
                    }
                }
            }


        }, chart: {

                GeometryReader { geometry in
                    chartContent(geometry: geometry)
                }


            }, footer: {
                Form {
                    MonthRangeSlider(range: $range, inRange: inRange,
                        disabled: !isCompleted || isEmpty,
                        periodText: periodText,
                        onEditingChanged: { editing in
                            if editing {

                            } else {
                                calculateMinMax()
                            }
                        })

                    Toggle("家庭血圧の基準値(135/85)", isOn: $showBPGuide)

                }
                    .frame(height: 200)
                    .scrollContentBackground(.hidden)


            })
        //.toolbar {
        //    ToolbarItem(placement: .principal) { Text(health.title).fontWeight(.semibold) }
        //}
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

    private func valuesContent(systolicMin: Double?, systolicMax: Double?, diastolicMin: Double?, diastolicMax: Double?) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                HStack(alignment: .center, spacing: 2) {
                    Text("●")
                        .font(.caption2)
                        .foregroundColor(.pink)
                    Text("最高")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                }
                    .padding(.top)
                Text(
                    (systolicMin == systolicMax) ?
                    formatValue(systolicMin ?? 0, health.sampleValueFormat):
                        formatValue(systolicMin ?? 0, health.sampleValueFormat) + "–" + formatValue(systolicMax ?? 0, health.sampleValueFormat)
                )
                    .fontWeight(.medium)
                    .font(.system(.largeTitle, design: .rounded))
            }
            Spacer()
                .frame(minWidth: 10, maxWidth: 30)
            VStack(alignment: .leading) {
                HStack(alignment: .center, spacing: 2) {
                    Text("◆")
                        .font(.caption2)
                        .foregroundColor(.black)
                    Text("最低")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                }
                    .padding(.top)
                Text(
                    (diastolicMin == diastolicMax) ?
                    formatValue(diastolicMin ?? 0, health.sampleValueFormat):
                        formatValue(diastolicMin ?? 0, health.sampleValueFormat) + "–" + formatValue(diastolicMax ?? 0, health.sampleValueFormat)
                )
                    .fontWeight(.medium)
                    .font(.system(.largeTitle, design: .rounded))
                    +
                    Text(" " + health.sampleUnitText)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                    .font(.system(.subheadline, design: .rounded))
            }
        }
    }

    private func chartContent(geometry: GeometryProxy) -> some View {


        Chart {
            let filteredSystolicItems = SystolicItems.filter {
                $0.date >= SystolicItems[range.lowerBound].date &&
                    $0.date <= SystolicItems[range.upperBound].date
            }
            let filteredDiastolicItems = DiastolicItems.filter {
                $0.date >= DiastolicItems[range.lowerBound].date &&
                    $0.date <= DiastolicItems[range.upperBound].date
            }

            if !filteredSystolicItems.isEmpty && !filteredDiastolicItems.isEmpty {

                let elapsed = Calendar.current.dateComponents(
                    [.month],
                    from: SystolicItems[range.lowerBound].date,
                    to: SystolicItems[range.upperBound].date).month!

                let width = geometry.size.width / Double(elapsed + 12)
                let barWidth = calculateBarWidth(width: geometry.size.width / Double(elapsed + 12))
                let symbolSize = calculateSymbolSize(width: width)

                ForEach(filteredSystolicItems) {
                    barMarkContent(item: $0, width: barWidth)
                        .foregroundStyle(health.color.opacity(0.33))

                    PointMark(
                        x: .value("日付", $0.date),
                        y: .value(health.sampleUnitText, $0.min)
                    )
                        .symbol(.circle)
                        .foregroundStyle(health.color)
                        .symbolSize(symbolSize)


                    PointMark(
                        x: .value("日付", $0.date),
                        y: .value(health.sampleUnitText, $0.max)
                    )
                        .symbol(.circle)
                        .foregroundStyle(health.color)
                        .symbolSize(symbolSize)
                }

                ForEach(filteredDiastolicItems) {
                    barMarkContent(item: $0, width: barWidth)
                        .foregroundStyle(.black.opacity(0.33))

                    PointMark(
                        x: .value("日付", $0.date),
                        y: .value(health.sampleUnitText, $0.min)
                    )
                        .symbol(.diamond)
                        .foregroundStyle(.black)
                        .symbolSize(symbolSize)


                    PointMark(
                        x: .value("日付", $0.date),
                        y: .value(health.sampleUnitText, $0.max)
                    )
                        .symbol(.diamond)
                        .foregroundStyle(.black)
                        .symbolSize(symbolSize)
                }
            }
            // 家庭血圧の高血圧基準(日本高血圧学会: 135/85 mmHg)
            if showBPGuide {
                RuleMark(y: .value("mmHg", 135))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.red.opacity(0.6))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("135")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.8))
                    }
                RuleMark(y: .value("mmHg", 85))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.red.opacity(0.6))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("85")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.8))
                    }
            }

        }
            .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                if let date = value.as(Date.self) {

                    let elapsed = Calendar.current.dateComponents(
                        [.year],
                        from: SystolicItems[range.lowerBound].date,
                        to: SystolicItems[range.upperBound].date).year!

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
                        let index = findElement(location: value.location, proxy: proxy, geometry: geo)
                        if index == nil {
                            selectedSystolicItem = nil
                            selectedDiastolicItem = nil
                        } else {
                            let systolicItem = SystolicItems[index!]
                            let diastolicItem = DiastolicItems[index!]

                            if selectedSystolicItem?.date == systolicItem.date {
                                selectedSystolicItem = nil
                                selectedDiastolicItem = nil
                            } else {
                                selectedSystolicItem = systolicItem
                                selectedDiastolicItem = diastolicItem
                            }
                        }
                    }
                        .exclusively(
                        before: DragGesture()
                            .onChanged { value in
                            let index = findElement(location: value.location, proxy: proxy, geometry: geo)
                            if index != nil {
                                selectedSystolicItem = SystolicItems[index!]
                                selectedDiastolicItem = DiastolicItems[index!]

                            }
                        }
                    )
                )
            }
        }
            .chartBackground { proxy in
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    if let selectedSystolicItem,
                        let selectedDiastolicItem,
                        let plotFrame = proxy.plotFrame {

                        let dateInterval = Calendar.current.dateInterval(of: .day, for: selectedSystolicItem.date)!
                        let startPositionX1 = proxy.position(forX: dateInterval.start) ?? 0

                        let lineX = startPositionX1 + geo[plotFrame].origin.x
                        let lineHeight = geo[plotFrame].maxY
                        let boxWidth: CGFloat = calculateBoxWidth(systolicItem: selectedSystolicItem, diastolicItem: selectedDiastolicItem)
                        let boxOffset = max(0, min(geo.size.width - boxWidth, lineX - boxWidth / 2))

                        Rectangle()
                            .fill(Color.lolipopBarColor)
                            .frame(width: 2, height: lineHeight)
                            .position(x: lineX, y: lineHeight / 2)

                        VStack(alignment: .leading) {

                            valuesContent(systolicMin: selectedSystolicItem.min,
                                systolicMax: selectedSystolicItem.max,
                                diastolicMin: selectedDiastolicItem.min,
                                diastolicMax: selectedDiastolicItem.max)

                            Text(yearMonthDateFormatter.string(from: selectedSystolicItem.date))
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

    private func calculateBoxWidth(systolicItem: ChartItem, diastolicItem: ChartItem) -> Double {
        var width = 60.0;

        if systolicItem.min == systolicItem.max {
            width += 70
            if systolicItem.min < 100 { width -= 10 }
        } else {
            width += 140
            if systolicItem.min < 100 { width -= 10 }
            if systolicItem.max < 100 { width -= 10 }
        }
        if diastolicItem.min == diastolicItem.max {
            width += 70
            if diastolicItem.min < 100 { width -= 10 }
        } else {
            width += 140
            if diastolicItem.min < 100 { width -= 10 }
            if diastolicItem.max < 100 { width -= 10 }
        }

        return width
    }

    private func calculateBarWidth(width: Double) -> MarkDimension {
        return MarkDimension(floatLiteral: width < 3 ? 1 : (width < 4 ? 2 : (width < 5 ? 3 : (width < 6 ? 4 : (width < 7 ? 5 : (width < 8 ? 6 : (width < 9 ? 7 : 8)))))))
    }

    private func calculateSymbolSize(width: Double) -> CGSize {
        let w = width < 3 ? 1 : (width < 4 ? 2 : (width < 5 ? 3 : (width < 6 ? 4 : (width < 7 ? 5 : (width < 8 ? 6 : (width < 9 ? 7 : 8))))))
        return CGSize(width: w, height: w)
    }

    private func barMarkContent(item: ChartItem, width: MarkDimension) -> some ChartContent {
        BarMark (
            x: .value("日付", item.date),
            yStart: .value(health.sampleUnitText, item.min),
            yEnd: .value(health.sampleUnitText, item.max),
            width: width
        )
            .accessibilityLabel("\(item.date)")
            .accessibilityValue("\(item.max)-\(item.min)" + health.sampleUnitText)
    }

    private func findElement(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> Int? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let relativeXPosition = location.x - geometry[plotFrame].origin.x
        if let date = proxy.value(atX: relativeXPosition) as Date? {
            // Find the closest date element.
            var minDistance: TimeInterval = .infinity
            var nearestIndex: Int? = nil

            for (index, item) in SystolicItems.enumerated() {
                let nthSalesDataDistance = item.date.distance(to: date)
                if abs(nthSalesDataDistance) < minDistance {
                    minDistance = abs(nthSalesDataDistance)
                    nearestIndex = index
                }
            }
            return nearestIndex
        }
        return nil
    }

    /// スライダーで選択中の期間(例「2023年11月〜2026年10月」)
    private var periodText: String? {
        guard SystolicItems.indices.contains(range.lowerBound),
              SystolicItems.indices.contains(range.upperBound) else { return nil }
        let start = SystolicItems[range.lowerBound].date
        let end = SystolicItems[range.upperBound].date
        if range.lowerBound == range.upperBound {
            return yearMonthDateFormatter.string(from: start)
        }
        return yearMonthDateFormatter.string(from: start) + "〜" + yearMonthDateFormatter.string(from: end)
    }

    private func calculateMinMax() {
        let filteredSystolicItems = SystolicItems.filter {
            $0.date >= SystolicItems[range.lowerBound].date &&
                $0.date <= SystolicItems[range.upperBound].date
        }
        let filteredDiastolicItems = DiastolicItems.filter {
            $0.date >= DiastolicItems[range.lowerBound].date &&
                $0.date <= DiastolicItems[range.upperBound].date
        }

        systolicMin = filteredSystolicItems.min { a, b in
            a.min < b.min
        }?.min
        systolicMax = filteredSystolicItems.max { a, b in
            a.max < b.max
        }?.max
        diastolicMin = filteredDiastolicItems.min { a, b in
            a.min < b.min
        }?.min
        diastolicMax = filteredDiastolicItems.max { a, b in
            a.max < b.max
        }?.max

    }

    // 最高血圧・最低血圧を取得し、両方のデータがある月だけをペアにする
    private func load() async {
        isLoading = true
        isCompleted = false
        selectedSystolicItem = nil
        selectedDiastolicItem = nil
        loadProgress = nil

        let service = HealthStatsService.shared
        let systolicItem = Health.shared.items.first { $0.type == .bloodPressureSystolic } ?? health
        let diastolicItem = Health.shared.items.first { $0.type == .bloodPressureDiastolic } ?? health

        // 最高血圧で前半、最低血圧で後半の進捗にする
        let systolicStats = await service.monthlyStats(for: systolicItem, startYear: startYear) { p in
            Task { @MainActor in loadProgress = p * 0.5 }
        }
        let diastolicStats = await service.monthlyStats(for: diastolicItem, startYear: startYear) { p in
            Task { @MainActor in loadProgress = 0.5 + p * 0.5 }
        }

        let diastolicByKey = Dictionary(uniqueKeysWithValues: diastolicStats.map { ($0.key, $0) })

        var systolicItems: [ChartItem] = []
        var diastolicItems: [ChartItem] = []

        for stat in systolicStats {
            guard let sMin = stat.minValue, let sMax = stat.maxValue,
                  let dStat = diastolicByKey[stat.key],
                  let dMin = dStat.minValue, let dMax = dStat.maxValue else { continue }

            systolicItems.append(ChartItem(
                date: stat.midDate, startDate: stat.startDate, endDate: stat.endDate,
                min: sMin, max: sMax))
            diastolicItems.append(ChartItem(
                date: dStat.midDate, startDate: dStat.startDate, endDate: dStat.endDate,
                min: dMin, max: dMax))
        }

        SystolicItems = systolicItems
        DiastolicItems = diastolicItems

        isEmpty = systolicItems.isEmpty
        isLoading = false
        isCompleted = true

        if !systolicItems.isEmpty {
            range = 0...systolicItems.count - 1
            inRange = 0...systolicItems.count - 1
            calculateMinMax()
        } else {
            systolicMin = nil
            systolicMax = nil
            diastolicMin = nil
            diastolicMax = nil
        }
    }

}

