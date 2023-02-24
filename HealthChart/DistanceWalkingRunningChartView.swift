//
//  DistanceWalkingRunningChartView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/22.
//

import SwiftUI
import Charts
import HealthKit
import Sliders

struct DistanceWalkingRunningChartView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var orientation: UIDeviceOrientation
    @State var range: ClosedRange<Int>
    @State var inRange: ClosedRange<Int>
    
    @State var isLoading = true
    @State var isEmpty = false
    
    enum Period {
        case whole
        case custom
    }
    
    struct DoubleItem: Identifiable {
        var id = UUID()
        var value: Double
        var date: Date
        var startDate: Date
        var endDate: Date
        var sum: Double
        var count: Int
    }
    @State var items: [DoubleItem] = []
    
    struct DailyItem {
        var value: Double
        var startDate: Date
        var endDate: Date
    }
    
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
        LayoutView(isLoading: $isLoading, isEmpty: $isEmpty) {
            Group {
                Text("1日の平均")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                HStack(alignment: .bottom) {
                    Text(String(format: "%.1f", value ?? 0))
                        .fontWeight(.medium)
                        .font(.system(.largeTitle, design: .rounded))
                    +
                    Text("km")
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
            
        } chart: {
            Chart {
                ForEach(items.filter {
                    $0.date >= items[range.lowerBound].date &&
                    $0.date <= items[range.upperBound].date
                }) {
                    BarMark (
                        x: .value("日付", $0.date),
                        y: .value("km", $0.value),
                        width: 2
                    )
                    //.interpolationMethod(.linear)
                    //.symbol(.circle)
                    .accessibilityLabel("\($0.date)")
                    .accessibilityValue("\($0.value) kg")
                    .foregroundStyle(.red)
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
            
        } footer: {
            Form {
                RangeSlider(range: $range, in: inRange, step: 1, onEditingChanged: { editing in
                    if editing {
                        
                    } else {
                        get2()
                    }
                })
                
            }
            
            .frame(height: 721)
            .scrollContentBackground(.hidden)
        }
        .toolbar {
            ToolbarItem(placement: .principal) { Text("ウォーキング+ランニングの距離").fontWeight(.semibold) }
        }
        .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
        .onAppear() {
            get()
        }
        
        
    }
    
    private func get2() {
        
        var sum: Double = 0
        var count: Int = 0
        
        for i in range {
            sum += items[i].sum
            count += items[i].count
        }
        value = sum / Double(count)

        //print("\(sum)")
        //print("\(range.count)")
        //print("\(value!)")
        value = round((value ?? 0) * 10) / 10
        //print("\(value!)")

        /*
        let predicate = HKQuery.predicateForSamples(
            withStart: items[range.lowerBound].startDate,
            end: items[range.upperBound].endDate
        )
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        
        let query = HKStatisticsQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum]) { query, statistics, error in

                if statistics != nil {

                    print(statistics!.startDate)
                    print(statistics!.endDate)
                    
                    let q = statistics!.sumQuantity()
                    value = q?.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                    
                    //let days = calendar.range(of: .day, in: .month, for: date)!.count
                    print("\(value!)")
                    
                    let span = round(statistics!.endDate.timeIntervalSince(statistics!.startDate) / (60 * 60 * 24))
                    print("\(span)")
                    print(value! / span)
                    
                    value = round((value ?? 0) * 10 / span) / 10
                    print("\(value!)")

                }

            }
        healthStore!.execute(query)
         */
    }
    
    private func get() {
        let calendar = Calendar.current
        let startDate = DateComponents(year: 1900, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        let endDate = Calendar.current.dateComponents(in: TimeZone.current, from: Date())
        
        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.date(from: startDate),
            end: calendar.date(from: endDate)
        )
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        
        let query = HKStatisticsCollectionQuery(
            quantityType: sampleType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum],
            anchorDate: Calendar.current.date(from: startDate)!,
            intervalComponents: DateComponents(day: 1))
        
        query.initialResultsHandler = {
            query, collection, error in
            
            items.removeAll()
            
            
            /*
            collection?.enumerateStatistics(
                from: calendar.date(from: startDate)!,
                to: calendar.date(from: endDate)!
            ) { statistics, stop in
                
                let q = statistics.sumQuantity()
                let value = q?.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                
                if let value {
                    
                    let span = statistics.endDate.timeIntervalSince(statistics.startDate)
                    let date = statistics.startDate.addingTimeInterval(span / 2)
                    let days = calendar.range(of: .day, in: .month, for: date)!.count
                    
                    items.append(DoubleItem(
                        value: round(value / Double(days) * 10) / 10,
                        date: date,
                        startDate: statistics.startDate,
                        endDate: statistics.endDate
                        ))
                }
            }
            */
            
            var dailyItems: [DailyItem] = []

            collection?.enumerateStatistics(
                from: calendar.date(from: startDate)!,
                to: calendar.date(from: endDate)!
            ) { statistics, stop in
                
                let q = statistics.sumQuantity()
                let value = q?.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                
                if let value {
                    
                    let span = statistics.endDate.timeIntervalSince(statistics.startDate)
                    let date = statistics.startDate.addingTimeInterval(span / 2)
                    let days = calendar.range(of: .day, in: .month, for: date)!.count
                    
                    dailyItems.append(DailyItem(
                        value: value,
                        startDate: statistics.startDate,
                        endDate: statistics.endDate))
                    
                    /*
                    items.append(DoubleItem(
                        value: round(value / Double(days) * 10) / 10,
                        date: date,
                        startDate: statistics.startDate,
                        endDate: statistics.endDate
                        ))
                    */
                }
            }
            
            if !dailyItems.isEmpty {
                
                let min = dailyItems.min { a, b in
                    a.startDate < b.startDate
                }
                let max = dailyItems.max { a, b in
                    a.endDate < b.endDate
                }

                var dateComponent = DateComponents()
                dateComponent.month = 1

                var s = calendar.date(from: startDate)!
                var s2 = Calendar.current.date(byAdding: dateComponent, to: s)!
                
                while s < calendar.date(from: endDate)! {
                    
                    var a = dailyItems.filter { item in
                        item.startDate >= s &&
                        item.endDate <= s2
                    }
                    
                    //print(s)
                    //print(s2)
                    //print(a.count)
                    
                    let v = a.reduce(0, { $0 + $1.value })
                    
                    print(v)

                    if !a.isEmpty {
                        
                        let span = s2.timeIntervalSince(s)
                        let date = s.addingTimeInterval(span / 2)
                        
                        items.append(DoubleItem(
                            value: round(v / Double(a.count) * 10) / 10,
                             date: date,
                             startDate: s,
                             endDate: s2,
                            sum: v,
                            count: a.count))
                    }
                    
                    s = Calendar.current.date(byAdding: dateComponent, to: s)!
                    s2 = Calendar.current.date(byAdding: dateComponent, to: s2)!
                }
                

                //print(min?.startDate)
                //print(min?.value)
                //print(max?.endDate)
                //print(max?.value)

            }
            
            isEmpty = items.isEmpty
            isLoading = false
            
            if (!isEmpty) {
                range = 0...items.count-1
                inRange = 0...items.count-1
                
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
    
    
    
    private func isPortrait() -> Bool {
        
        var isLandscape = orientation.isLandscape
        var isPortrait = orientation.isPortrait
        
        if !isLandscape && !isPortrait {
            isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height
            isLandscape = !isPortrait
        }
        
        return isPortrait
    }
}

struct DistanceWalkingRunningChartView_Previews: PreviewProvider {
    static var previews: some View {
        DistanceWalkingRunningChartView()
    }
}
