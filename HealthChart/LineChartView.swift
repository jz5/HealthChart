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
    
    @AppStorage("showMinMax") var showMinMax = false
    @AppStorage("showAverage") var showAverage = false
    @AppStorage("showSymbol") var showSymbol = true

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
        LayoutView(isLoading: $isLoading, isEmpty: $isEmpty, header: {
            Group {
                Text(health.sampleValueTitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                HStack(alignment: .bottom) {
                    Text(String(format: health.sampleValueFormat, value ?? 0))
                        .fontWeight(.medium)
                        .font(.system(.largeTitle, design: .rounded))
                    +
                    Text(health.sampleUnitText)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                        .font(.system(.subheadline, design: .rounded))
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
                    .accessibilityLabel("\($0.date)")
                    .accessibilityValue("\($0.value) " + health.sampleUnitText)
                    .foregroundStyle(health.color)
                }
                
                if showAverage,
                   let value {
                    RuleMark(y: .value("平均", value))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(health.color)
                        .annotation(position: .top, alignment: .trailing) {
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
                            .annotation(position: .bottom, alignment: .trailing) {
                                                Text(String(format: health.sampleValueFormat, min.value))
                                                .font(.caption)
                                                .foregroundColor(health.color)}
                    }
                    if let max {
                        RuleMark(y: .value("最大", max.value))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(health.color)
                            .annotation(position: .top, alignment: .trailing) {
                                                Text(String(format: health.sampleValueFormat, max.value))
                                                .font(.caption)
                                                .foregroundColor(health.color)}
                    }

                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { value in
                    if let date = value.as(Date.self),
                       let month = Calendar.current.component(.month, from: date) {
                        if range.count <= 12 {
                            AxisGridLine(stroke: .init(lineWidth: 0.5))
                            AxisTick(stroke: .init(lineWidth: 0.5))
                            AxisValueLabel() {
                                Text(monthDateFormatter.string(from: date))
                            }
                        } else {
                            if month == 1 {
                                AxisGridLine(stroke: .init(lineWidth: 0.5))
                                AxisTick(stroke: .init(lineWidth: 0.5))
                                AxisValueLabel() {
                                    Text(yearDateFormatter.string(from: date))
                                }
                            } else {
                                AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2]))
                            }
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            
        }, footer: {
            Form {
                RangeSlider(range: $range, in: inRange, step: 1, onEditingChanged: { editing in
                    if editing {
                        
                    } else {
                        get2()
                    }
                })
                
                Toggle("平均", isOn: $showAverage)
                Toggle("最小・最大", isOn: $showMinMax)
                //Toggle("シンボル", isOn: $showSymbol)

            }
            .frame(height: 500)
            .scrollContentBackground(.hidden)
            

        })
        //.toolbar {
        //    ToolbarItem(placement: .principal) { Text(health.title).fontWeight(.semibold) }
        //}
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(health.title)
        .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
        .onAppear() {
            get()
        }
    }
    
    private func get2() {
        let predicate = HKQuery.predicateForSamples(
            withStart: items[range.lowerBound].date,
            end: items[range.upperBound].date
        )
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: health.type)!
        let query = HKStatisticsQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage]) { query, statistics, error in
                
                let q = statistics!.averageQuantity()
                value = q?.doubleValue(for: health.sampleUnit)
                value = health.sampleUnit == HKUnit.percent() ? value! * 100 : value!
            }
        healthStore!.execute(query)
    }
    
    private func get() {
        let calendar = Calendar.current
        let startDate = DateComponents(year: 1900, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        let endDate = Calendar.current.dateComponents(in: TimeZone.current, from: Date())
        
        
        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.date(from: startDate),
            end: calendar.date(from: endDate)
        )
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: health.type)!
        let query = HKStatisticsCollectionQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage],
            anchorDate: Calendar.current.date(from: startDate)!,
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
                    
                    print(statistics.startDate)
                    print(statistics.endDate)
                    print(q!)
                    print(value)
                    
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
                get2()
            }
            
        }
        healthStore!.execute(query)
    }
}

struct LineChartView_Previews: PreviewProvider {
    static var previews: some View {
        LineChartView(health: HealthItem(type: .bodyMass,
                                         image: "figure.arms.open",
                                         title: "体重",
                                         color: .purple,
                                         sampleValueTitle: "平均",
                                         sampleUnitText: "kg",
                                         sampleValueFormat: "%.2f",
                                         sampleUnit: HKUnit.gramUnit(with: .kilo)))
    }
}
