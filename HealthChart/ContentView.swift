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

    @ObservedObject var health = Health.shared

    var body: some View {
        if !isHealthAvailable {
            Text("この端末はサポートしていません")

        } else {

            NavigationStack {
                List {
                    Section("分析") {
                        NavigationLink {
                            ComparisonChartView()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundColor(.teal)
                                Text("2項目の比較")
                                    .foregroundColor(.teal)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    ForEach(HealthCategory.allCases) { category in
                        let items = health.items.filter { $0.category == category && $0.chart != .hidden }
                        if !items.isEmpty {
                            Section(category.title) {
                                ForEach(items) { item in
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
                            }
                        }
                    }
                }
                .navigationTitle("ヘルスチャート")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            SettingsView()
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

    @ViewBuilder
    private func chartView(item: HealthItem) -> some View {
        switch item.chart {
        case .bar:
            BarChartView(health: item)
        case .line:
            LineChartView(health: item)
        case .bloodPress:
            BloodPressureChartView(health: item)
        default:
            RangeChartView(health: item)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
