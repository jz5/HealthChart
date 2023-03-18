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

struct RangeChartView: View {
    @State public var health: HealthItem

    @Environment(\.colorScheme) var colorScheme

    @State var orientation: UIDeviceOrientation
    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    @State var value: Double?

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
    @State var items: [ChartItem] = []

    struct DailyItem: Identifiable {
        var id = UUID()
        //var value: Double
        var date: Date
        var startDate: Date
        var endDate: Date
        var min: Double
        var max: Double
    }
    @State var dailyItems: [DailyItem] = []

    let yearDateFormatter = DateFormatter()
    let monthDateFormatter = DateFormatter()
    let yearMonthDateFormatter = DateFormatter()

    @AppStorage("startYear") private var startYear = 2014
    @AppStorage("showMinMax") var showMinMax = false
    @AppStorage("showAverage") var showAverage = false

    @State var disappeared = false

    @State private var selectedItem: ChartItem? = nil

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
//                Text(health.sampleValueTitle)
//                    .font(.subheadline)
//                    .foregroundColor(.gray)
//                    .fontWeight(.semibold)
//                    .padding(.top)
//
//                HStack(alignment: .bottom) {
//                    if value == nil {
//                        Text("データなし")
//                            .fontWeight(.medium)
//                            .font(.system(.largeTitle, design: .rounded))
//
//                    } else {
//                        Text(String(format: health.sampleValueFormat, value ?? 0))
//                            .fontWeight(.medium)
//                            .font(.system(.largeTitle, design: .rounded))
//                            +
//                            Text(health.sampleUnitText)
//                            .foregroundColor(.gray)
//                            .fontWeight(.semibold)
//                            .font(.system(.subheadline, design: .rounded))
//                    }
//                }
//                if items.count == 1 {
//                    Text(yearMonthDateFormatter.string(from: items[range.lowerBound].date))
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                        .fontWeight(.semibold)
//                }
//                if !items.isEmpty {
//                    Text(
//                        yearMonthDateFormatter.string(from: items[range.lowerBound].date) + "〜" +
//                            yearMonthDateFormatter.string(from: items[range.upperBound].date))
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                        .fontWeight(.semibold)
//                }
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
                                to: items[range.upperBound].date).month!

                            let width = geometry.size.width / Double(elapsed + 12)

                            Plot {
                                ForEach(dailyItems.filter {
                                    $0.date >= items[range.lowerBound].date &&
                                    $0.date <= items[range.upperBound].date
                                }) {
                                    BarMark (
                                        x: .value("日付", $0.date),
                                        yStart: .value(health.sampleUnitText, $0.min),
                                        yEnd: .value(health.sampleUnitText, $0.max),
                                        width: width < 3 ? 1 : (width < 4 ? 2 : (width < 5 ? 3 : (width < 6 ? 4 : (width < 7 ? 5 : (width < 8 ? 6 : (width < 9 ? 7 : 8))))))
                                    )
                                    .clipShape(Capsule())
                                    .foregroundStyle(health.color.gradient)
                                    .accessibilityLabel("\($0.date)")
                                    //.accessibilityValue("\($0.value) " + health.sampleUnitText)
                                    .foregroundStyle(health.color)
                                }
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
                        if showMinMax {
                            let max = filteredItems.max { a, b in
                                a.value < b.value
                            }

                            if let max {
                                RuleMark(y: .value("最大", max.value))
                                    .lineStyle(StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(health.color)
                                    .annotation(position: .trailing, alignment: .leading) {
                                    Text(String(format: health.sampleValueFormat, max.value))
                                        .font(.caption)
                                        .foregroundColor(health.color) }
                            }

                        }*/

                    }
                        .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: 1)) { value in
                            if let date = value.as(Date.self) {

                                let elapsed = Calendar.current.dateComponents(
                                    [.year],
                                    from: items[range.lowerBound].date,
                                    to: items[range.upperBound].date).year!

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
                    //.chartYScale(domain: .automatic(includesZero: false))
//                    .chartOverlay { proxy in
//                        GeometryReader { geo in
//                            Rectangle().fill(.clear).contentShape(Rectangle())
//                                .gesture(
//                                SpatialTapGesture()
//                                    .onEnded { value in
//                                    let element = findElement(location: value.location, proxy: proxy, geometry: geo)
//                                    if selectedItem?.date == element?.date {
//                                        // If tapping the same element, clear the selection.
//                                        selectedItem = nil
//                                    } else {
//                                        selectedItem = element
//                                    }
//                                }
//                                    .exclusively(
//                                    before: DragGesture()
//                                        .onChanged { value in
//                                        selectedItem = findElement(location: value.location, proxy: proxy, geometry: geo)
//                                    }
//                                )
//                            )
//                        }
//                    }
//                        .chartBackground { proxy in
//                        ZStack(alignment: .topLeading) {
//                            GeometryReader { geo in
//                                if true,
//                                    let selectedItem {
//                                    let dateInterval = Calendar.current.dateInterval(of: .day, for: selectedItem.date)!
//                                    let startPositionX1 = proxy.position(forX: dateInterval.start) ?? 0
//
//                                    let lineX = startPositionX1 + geo[proxy.plotAreaFrame].origin.x
//                                    let lineHeight = geo[proxy.plotAreaFrame].maxY
//                                    let boxWidth: CGFloat = 120
//                                    let boxOffset = max(0, min(geo.size.width - boxWidth, lineX - boxWidth / 2))
//
//                                    Rectangle()
//                                        .fill(Color.lolipopBarColor)
//                                        .frame(width: 2, height: lineHeight)
//                                        .position(x: lineX, y: lineHeight / 2)
//
//                                    VStack(alignment: .center) {
//
//                                        Text(String(format: health.sampleValueFormat, selectedItem.value))
//                                            .fontWeight(.medium)
//                                            .font(.system(.largeTitle, design: .rounded))
//                                        Text(yearMonthDateFormatter.string(from: selectedItem.date))
//                                            .font(.subheadline)
//                                            .foregroundColor(.gray)
//                                            .fontWeight(.semibold)
//                                    }
//                                        .frame(width: boxWidth, alignment: .center)
//                                        .background {
//                                        ZStack {
//                                            RoundedRectangle(cornerRadius: 8)
//                                                .fill(Color.lolipopBackgroundColor)
//
//                                        }
//                                            .padding(.horizontal, -8)
//                                            .padding(.vertical, -4)
//                                    }
//                                        .offset(x: boxOffset)
//                                }
//                            }
//                        }
//                    }
                }

            }, footer: {
                Form {
                    RangeSlider(range: $range, in: inRange, step: 1,
                        onEditingChanged: { editing in
                            if editing {

                            } else {
                                //calculateAverage()
                            }
                        }).disabled(!isCompleted || isEmpty)

                    Toggle("平均", isOn: $showAverage)
                    Toggle("最大", isOn: $showMinMax)

                }
                    .frame(height: 300)
                    .scrollContentBackground(.hidden)


            })
        //.toolbar {
        //    ToolbarItem(placement: .principal) { Text(health.title).fontWeight(.semibold) }
        //}
        .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(health.title)
            .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
            .onAppear() {
            let startDate = Calendar.current.date(from: DateComponents(year: startYear, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
            executeQuery(startDate: startDate)
        }
            .onChange(of: requested) { newValue in
            let startDate = Calendar.current.date(from: DateComponents(year: startYear, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
            executeQuery(startDate: startDate)
        }
            .onDisappear() {
            disappeared = true
        }
    }

    private func findElement(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> ChartItem? {
        let relativeXPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
        if let date = proxy.value(atX: relativeXPosition) as Date? {
            // Find the closest date element.
            var minDistance: TimeInterval = .infinity
            var nearestItem: ChartItem? = nil
            for item in items {
                let nthSalesDataDistance = item.date.distance(to: date)
                if abs(nthSalesDataDistance) < minDistance {
                    minDistance = abs(nthSalesDataDistance)
                    nearestItem = item
                }
            }
            if let nearestItem {
                return nearestItem
            }
        }
        return nil
    }

    private func calculateAverage() {

//        var sum: Double = 0
//        var count: Int = 0
//
//        for i in range {
//            sum += items[i].sum
//            count += items[i].count
//        }
//        value = sum / Double(count)
    }

    private func executeQuery(startDate: Date) {
        let calendar = Calendar.current
        //var startDate = calendar.date(from: DateComponents(year: 2022, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
        let endDate = calendar.date(from: calendar.dateComponents(in: TimeZone.current, from: Date()))!

        if startDate > endDate || disappeared {
            isLoading = false
            isEmpty = items.isEmpty
            isCompleted = true
            return
        }


        var dateComponent = DateComponents()
        dateComponent.month = 1

        var date1 = startDate
        let date2 = calendar.date(byAdding: dateComponent, to: date1)!

        let predicate = HKQuery.predicateForSamples(
            withStart: date1,
            end: date2
        )

        let sampleType = HKQuantityType.quantityType(forIdentifier: health.type)!

        let query = HKStatisticsCollectionQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.discreteMin, .discreteMax],
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1))

        query.initialResultsHandler = {
            query, collection, error in


            //var dailyItems: [DailyItem] = []

            let span = date2.timeIntervalSince(date1)
            let date = date1.addingTimeInterval(span / 2)

            collection?.enumerateStatistics(
                from: date1,
                to: date2
            ) { statistics, stop in

                let minQ = statistics.minimumQuantity()
                let maxQ = statistics.maximumQuantity()

                print(statistics)
                print(minQ)
                print(maxQ)

                let min = minQ?.doubleValue(for: health.sampleUnit)
                let max = maxQ?.doubleValue(for: health.sampleUnit)
                
                if let min, let max {
                    dailyItems.append(DailyItem(
                        date: date,
                        startDate: statistics.startDate,
                        endDate: statistics.endDate,
                        min: min,
                        max: max))
                }
            }

            if !dailyItems.isEmpty {
                let min = dailyItems.min { a, b in
                    a.min < b.min
                }?.min
                let max = dailyItems.max { a, b in
                    a.max < b.max
                }?.max
                
                items.append(ChartItem(
                    date: date,
                    startDate: date1,
                    endDate: date2,
                    min: min!,
                    max: max!
                ))

                isEmpty = false
                isLoading = false

                range = 0...items.count - 1
                inRange = 0...items.count - 1

                //calculateAverage()
            }

            date1 = calendar.date(byAdding: dateComponent, to: date1)!
            executeQuery(startDate: date1)
        }
        healthStore!.execute(query)
    }
}

struct RangeChartView_Previews: PreviewProvider {
    static var previews: some View {
        BarChartView(health: HealthItem(type: .distanceWalkingRunning,
            chart: .bar,
            image: "flame.fill",
            title: "ウォーキング+ランニングの距離",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "km",
            sampleValueFormat: "%.1f",
            sampleUnit: HKUnit.meterUnit(with: .kilo)))
    }
}
