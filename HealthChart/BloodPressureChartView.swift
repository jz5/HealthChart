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
    @State public var health: HealthItem

    @Environment(\.colorScheme) var colorScheme

    @State var orientation: UIDeviceOrientation
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

    @State var disappeared = false

    @State private var selectedSystolicItem: ChartItem? = nil
    @State private var selectedDiastolicItem: ChartItem? = nil

    let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    init(health: HealthItem) {
        _health = State(initialValue: health)

        _orientation = State(initialValue: UIDevice.current.orientation)
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

                valuesContent(systolicMin: systolicMin, systolicMax: systolicMax, diastolicMin: diastolicMin, diastolicMax: diastolicMax)
                    .padding(.top)

                if SystolicItems.count == 1 {
                    Text(yearMonthDateFormatter.string(from: SystolicItems[range.lowerBound].date))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                }
                if !SystolicItems.isEmpty {
                    Text(
                        yearMonthDateFormatter.string(from: SystolicItems[range.lowerBound].date) + "〜" +
                            yearMonthDateFormatter.string(from: SystolicItems[range.upperBound].date))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                }
            }


        }, chart: {

                GeometryReader { geometry in
                    chartContent(geometry: geometry)
                }


            }, footer: {
                Form {
                    RangeSlider(range: $range, in: inRange, step: 1,
                        onEditingChanged: { editing in
                            if editing {

                            } else {
                                calculateMinMax()
                            }
                        }).disabled(isEmpty)

//                    Toggle("平均", isOn: $showAverage)

                }
                    .frame(height: 150)
                    .scrollContentBackground(.hidden)


            })
        //.toolbar {
        //    ToolbarItem(placement: .principal) { Text(health.title).fontWeight(.semibold) }
        //}
        .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(health.title)
            .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
            .onAppear() {
            executeQueries()
        }
            .onChange(of: requested) { newValue in
            executeQueries()
        }
            .onDisappear() {
            disappeared = true
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

                Text(
                    (systolicMin == systolicMax) ?
                    String(format: health.sampleValueFormat, systolicMin ?? 0):
                        String(format: health.sampleValueFormat, systolicMin ?? 0) + "–" + String(format: health.sampleValueFormat, systolicMax ?? 0)
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

                Text(
                    (diastolicMin == diastolicMax) ?
                    String(format: health.sampleValueFormat, diastolicMin ?? 0):
                        String(format: health.sampleValueFormat, diastolicMin ?? 0) + "–" + String(format: health.sampleValueFormat, diastolicMax ?? 0)
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
            /*
                if showAverage,
                    let value {
                    RuleMark(y: .value("平均", value))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(health.color)
                        .annotation(position: .trailing, alignment: .leading) {
                        Text(String(format: health.sampleValueFormat, value))
                            .font(.caption)
                            .foregroundColor(health.color) }

                }
            */

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
                        let selectedDiastolicItem {

                        let dateInterval = Calendar.current.dateInterval(of: .day, for: selectedSystolicItem.date)!
                        let startPositionX1 = proxy.position(forX: dateInterval.start) ?? 0

                        let lineX = startPositionX1 + geo[proxy.plotAreaFrame].origin.x
                        let lineHeight = geo[proxy.plotAreaFrame].maxY
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
        var width = 70.0;

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
        let relativeXPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
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

    // 最高血圧・最低血圧を順に取得
    private func executeQueries() {
        executeQuery(type: .bloodPressureSystolic) { systolicItems in

            if systolicItems.isEmpty {
                isEmpty = true
                isLoading = false
                return
            }


            executeQuery(type: .bloodPressureDiastolic) { diastolicItems in

                if diastolicItems.isEmpty {
                    isEmpty = true
                    isLoading = false
                    return
                }

                // 同数の最高・最低血圧のデータがなければデータなし扱い
                if systolicItems.count != diastolicItems.count {
                    isLoading = false
                    return
                }

                SystolicItems = systolicItems
                DiastolicItems = diastolicItems

                range = 0...systolicItems.count - 1
                inRange = 0...systolicItems.count - 1

                calculateMinMax()

                isEmpty = false
                isLoading = false

            }
        }
    }

    private func executeQuery(type: HKQuantityTypeIdentifier, completionHandler: @escaping ([ChartItem]) -> Void) {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: startYear, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
        let endDate = calendar.date(from: calendar.dateComponents(in: TimeZone.current, from: Date()))!

        var dateComponent = DateComponents()
        dateComponent.month = 1

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate
        )

        let sampleType = HKQuantityType.quantityType(forIdentifier: type)!

        let query = HKStatisticsCollectionQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.discreteMin, .discreteMax],
            anchorDate: startDate,
            intervalComponents: DateComponents(month: 1))

        query.initialResultsHandler = {
            query, collection, error in

            var newItems: [ChartItem] = []

            collection?.enumerateStatistics(
                from: startDate,
                to: endDate
            ) { statistics, stop in
                let minQ = statistics.minimumQuantity()
                let maxQ = statistics.maximumQuantity()

                let min = minQ?.doubleValue(for: health.sampleUnit)
                let max = maxQ?.doubleValue(for: health.sampleUnit)

                let span = statistics.endDate.timeIntervalSince(statistics.startDate)
                let date = statistics.startDate.addingTimeInterval(span / 2)

                if let min, let max {
                    newItems.append(ChartItem(
                        date: date,
                        startDate: statistics.startDate,
                        endDate: statistics.endDate,
                        min: min,
                        max: max))
                }
            }

            completionHandler(newItems)
        }

        healthStore!.execute(query)
    }

}

