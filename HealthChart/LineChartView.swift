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
    @State public var health: HealthItem
    
    @Environment(\.colorScheme) var colorScheme
    
    @State var orientation: UIDeviceOrientation
    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    @State var value: Double?
    
    @State var isLoading = true
    @State var isEmpty = false
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
                if items.count == 1 {
                    Text(yearMonthDateFormatter.string(from: items[range.lowerBound].date))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                }
                if !items.isEmpty {
                    Text(
                        yearMonthDateFormatter.string(from: items[range.lowerBound].date) + "〜" +
                        yearMonthDateFormatter.string(from: items[range.upperBound].date))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                }
            }
            
            
        }, chart: {
            let filterdItems = items.filter {
                $0.date >= items[range.lowerBound].date &&
                $0.date <= items[range.upperBound].date
            }
            
            Chart {
                ForEach(filterdItems) {
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
                    let min = filterdItems.min { a, b in
                        a.value < b.value
                    }
                    let max = filterdItems.max { a, b in
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
                /*if let selectedItem {
                    RuleMark(x: .value("", selectedItem.date))
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
            .chartYScale(domain: .automatic(includesZero: false))
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    let element = findElement(location: value.location, proxy: proxy, geometry: geo)
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
                                            selectedItem = findElement(location: value.location, proxy: proxy, geometry: geo)
                                        }
                                )
                        )
                }
            }
            .chartBackground { proxy in
                ZStack(alignment: .topLeading) {
                    GeometryReader { geo in
                        if true,
                           let selectedItem {
                            let dateInterval = Calendar.current.dateInterval(of: .day, for: selectedItem.date)!
                            let startPositionX1 = proxy.position(forX: dateInterval.start) ?? 0
                            
                            let lineX = startPositionX1 + geo[proxy.plotAreaFrame].origin.x
                            let lineHeight = geo[proxy.plotAreaFrame].maxY
                            let boxWidth: CGFloat = 120
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
                })
                
                Toggle("平均", isOn: $showAverage)
                Toggle("最小・最大", isOn: $showMinMax)
                Toggle("シンボル", isOn: $showSymbols)

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
            executeQuery()
        }
        .onChange(of: requested) { newValue in
            executeQuery()
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
        if range.lowerBound == range.upperBound {
            value = items[range.lowerBound].value
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: items[range.lowerBound].date,
            end: items[range.upperBound].date
        )
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: health.type)!
        let query = HKStatisticsQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage]) { query, statistics, error in
                
                if let s = statistics {
                    let q = s.averageQuantity()
                    value = q?.doubleValue(for: health.sampleUnit)
                    if value != nil &&
                        health.sampleUnit == HKUnit.percent() {
                        value = value! * 100
                    }
                } else {
                    value = nil
                }
            }
        healthStore!.execute(query)
    }
    
    private func executeQuery() {
        let calendar = Calendar.current
        let startDate = DateComponents(year: startYear, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        let endDate = calendar.dateComponents(in: TimeZone.current, from: Date())
       
        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.date(from: startDate),
            end: calendar.date(from: endDate)
        )
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: health.type)!
        let query = HKStatisticsCollectionQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage],
            anchorDate: calendar.date(from: startDate)!,
            intervalComponents: DateComponents(month: 1))
        
        query.initialResultsHandler = {
            query, collection, error in
            
            items.removeAll()
            
            collection?.enumerateStatistics(
                from: calendar.date(from: startDate)!,
                to: calendar.date(from: endDate)!
            ) { statistics, stop in
                
                let q = statistics.averageQuantity()
                let value = q?.doubleValue(for: health.sampleUnit)
                
                if let value {
                    
                    let span = statistics.endDate.timeIntervalSince(statistics.startDate)
                    let date = statistics.startDate.addingTimeInterval(span / 2)
                    
                    items.append(ChartItem(
                        value: health.sampleUnit == HKUnit.percent() ? value * 100 : value,
                        date: date,
                        startDate: statistics.startDate,
                        endDate: statistics.endDate
                    ))
                }
            }
            
            isEmpty = items.isEmpty
            isLoading = false
            
            if (!isEmpty) {
                let max = items.count-1
                range = 0...max
                inRange = 0...max
                calculateAverage()
            }
            
        }
        healthStore!.execute(query)
    }
}

struct LineChartView_Previews: PreviewProvider {
    static var previews: some View {
        LineChartView(health: HealthItem(type: .bodyMass,
                                         chart: .line,
                                         image: "figure.arms.open",
                                         title: "体重",
                                         color: .purple,
                                         sampleValueTitle: "平均",
                                         sampleUnitText: "kg",
                                         sampleValueFormat: "%.2f",
                                         sampleUnit: HKUnit.gramUnit(with: .kilo)))
    }
}
