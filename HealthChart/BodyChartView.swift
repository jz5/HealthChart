//
//  BodyChartView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/19.
//

import SwiftUI
import Charts
import HealthKit
import Sliders

struct BodyChartView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var orientation: UIDeviceOrientation
    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    
    @State var isLoading = true
    @State var isEmpty = false
    @State var requested = false
    
    struct DoubleItem: Identifiable {
        var id = UUID()
        var value: Double
        var date: Date
        var startDate: Date
        var endDate: Date
    }
    @State var items: [DoubleItem] = []
    
    let dateFormatter = DateFormatter()
    let yearMonthDateFormatter = DateFormatter()
    
    let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    
    @State var isWholePeriod: Int = 1
    @State var isGroupedByYear: Bool = false

    @State var flag: Bool  = false
    @State var flag1: Bool  = false
    @State var flag2: Bool  = false

    @State private var currentValue: Double = 5
    @State var value: Double?

    
    init() {
        _orientation = State(initialValue: UIDevice.current.orientation)

        _range = State(initialValue: 0...0)
        _inRange = State(initialValue: 0...0)
        
        yearMonthDateFormatter.locale = Locale(identifier: "ja_JP")
        yearMonthDateFormatter.setLocalizedDateFormatFromTemplate("yMMM")
        
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.setLocalizedDateFormatFromTemplate("y")

        
    }
    
    var body: some View {
        LayoutView(isLoading: $isLoading, isEmpty: $isEmpty, requested: $requested, header: {
            Group {
                Text("平均")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                HStack(alignment: .bottom) {
                    Text(String(format: "%.2f", value ?? 0))
                        .fontWeight(.medium)
                        .font(.system(.largeTitle, design: .rounded))
                    +
                    Text("kg")
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

            Chart {
                ForEach(items.filter {
                    $0.date >= items[range.lowerBound].date &&
                    $0.date <= items[range.upperBound].date
                }) {
                    LineMark (
                        x: .value("日付", $0.date),
                        y: .value("kg", $0.value)
                    )
                    .interpolationMethod(.linear)
                    .symbol(.circle)
                    .accessibilityLabel("\($0.date)")
                    .accessibilityValue("\($0.value) kg")
                    .foregroundStyle(.purple)
                    //.foregroundStyle(by: .value("year", $0.year))
                }
                
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { value in
                    if let date = value.as(Date.self),
                       let month = Calendar.current.component(.month, from: date) {
                        
                        if month == 1 {
                            AxisGridLine(stroke: .init(lineWidth: 0.5))
                            AxisTick(stroke: .init(lineWidth: 0.5))
                            AxisValueLabel() {
                                Text(dateFormatter.string(from: date))
                            }
                        } else {
                            AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2]))
                        }
                    }
                }
            }
            
            .chartYScale(domain: .automatic(includesZero: false)/*,
                         range: .plotDimension(padding: 5)*/)
            
            
        }, footer: {
            Form {
                RangeSlider(range: $range, in: inRange, step: 1, onEditingChanged: { editing in
                    if editing {
                        //let startYear = range.lowerBound
                        //let endYear = range.upperBound
                        //updateYearString(start: startYear, end: endYear)
                        
                    } else {
                        get2()
                    }
                })
                
                Toggle("最小・最大", isOn: $flag)
                    .background(GeometryReader{ geometry -> Text in
                                    print("******", geometry.size)
                                    return Text("")
                                })
                Toggle("平均", isOn: $flag1)
                //Toggle("シンボル", isOn: $flag2)

                Text("aaa")
                    .background(GeometryReader{ geometry -> Text in
                                    print("******", geometry.size)
                                    return Text("")
                                })
                Text("aaa1")
                Text("aaa2")
                Text("aaa3")
                Text("aaa4")
                Text("aaa5")
                Text("aaa6")
            }
            .frame(height: 721)
            .scrollContentBackground(.hidden)
        })
        .toolbar {
            ToolbarItem(placement: .principal) { Text("体重").fontWeight(.semibold) }
        }
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
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        
        let query = HKStatisticsQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage]) { query, statistics, error in

                let q = statistics!.averageQuantity()
                value = q?.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                value = round(value! * 100) / 100
                    
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
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        
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
                let value = q?.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                
                if let value {
                    
                    //print(statistics.startDate)
                    //print(statistics.endDate)
                    //print(round(value * 100)/100)
                    
                    let span = statistics.endDate.timeIntervalSince(statistics.startDate)
                    let date = statistics.startDate.addingTimeInterval(span / 2)
                    
                    items.append(DoubleItem(
                        value: value,
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
    
    private func from(_ year: Int, _ month: Int, _ day: Int) -> Date?
    {
        let gregorianCalendar = Calendar(identifier: .gregorian)
        let dateComponents = DateComponents(calendar: gregorianCalendar, year: year, month: month, day: day)
        return gregorianCalendar.date(from: dateComponents)
    }
    
    private func getDaysInMonth(_ year: Int, _ month: Int) -> Int {
        let dateComponents = DateComponents(year: year, month: month)
        let calendar = Calendar.current
        let date = calendar.date(from: dateComponents)!

        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.count
    }
    
}

struct BodyChartView_Previews: PreviewProvider {
    static var previews: some View {
        BodyChartView()
    }
}
