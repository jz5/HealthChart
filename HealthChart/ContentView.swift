//
//  ContentView.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/17.
//

import SwiftUI
import Charts
import HealthKit

struct ContentView: View {

    let isHealthAvailable = HKHealthStore.isHealthDataAvailable()
    let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    @ObservedObject var health = Health()
    @State private var showAlert = false

    init() {
    }

    var body: some View {
        if !isHealthAvailable {
            Text("この端末はサポートしていません")

        } else {

            NavigationStack {
                List {
                    ForEach(health.items.filter{ $0.chart != .hidden && $0.isVisible }) { item in

                        NavigationLink {
                            chartView(item: item)
                            
                        } label: {
                            HStack {
                                Image(systemName: item.image)
                                    .foregroundColor(item.color)
                                Text(item.title)
                                    .foregroundColor(item.color)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
//                    Section {
//                        NavigationLink("test") {
//                            SampleView()
//                        }
//                    }
                }
                //.navigationBarTitleDisplayMode(.title)
                //.navigationTitle("ヘルスケアデータ")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            SettingsView(health: health)
                        } label: {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("設定")
                            }
                        }
                    }
                }
            }


        }
    }
    
    private func chartView(item: HealthItem) -> AnyView {
        if item.chart == .bar {
            return AnyView(BarChartView(health: item))
        } else if item.chart == .line {
            return AnyView(LineChartView(health: item))
        } else if item.chart == .bloodPress {
            return AnyView(BloodPressureChartView(health: item))
        } else {
                return AnyView(RangeChartView(health: item))
        }
    }

    private func requestAuthorization() {

        let types = health.items.map { HKObjectType.quantityType(forIdentifier: $0.type)! }
        let notDetermined = types.contains(where: {
            healthStore?.authorizationStatus(for: $0) == .notDetermined
        })
        if (notDetermined) {
            healthStore!.requestAuthorization(toShare: nil, read: Set(types)) { (success, error) in
                // Do nothing
            }
        } else {
            showAlert = true
        }

    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
