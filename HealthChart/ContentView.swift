import Charts//
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


    let items: [HealthItem] = [
        HealthItem(type: .distanceWalkingRunning,
             image: "flame.fill",
             title: "ウォーキング+ランニングの距離",
             color: .red,
             sampleValueTitle: "1日の平均",
             sampleUnitText: "km",
             sampleValueFormat: "%.1f",
             sampleUnit: HKUnit.meterUnit(with: .kilo)),

        // 心臓
        HealthItem(type: .restingHeartRate,
             image: "heart.fill",
             title: "安静時心拍数",
             color: .pink,
             sampleValueTitle: "平均",
             sampleUnitText: "拍/分",
             sampleValueFormat: "%.0f",
             sampleUnit: HKUnit.init(from: "count/min")),
        HealthItem(type: .heartRateVariabilitySDNN,
             image: "heart.fill",
             title: "心拍変動",
             color: .pink,
             sampleValueTitle: "平均",
             sampleUnitText: "ミリ秒",
             sampleValueFormat: "%.0f",
                   sampleUnit: HKUnit.secondUnit(with: .milli)),
        HealthItem(type: .heartRateRecoveryOneMinute,
             image: "heart.fill",
             title: "心拍数回復",
             color: .pink,
             sampleValueTitle: "平均",
             sampleUnitText: "拍/分",
             sampleValueFormat: "%.0f",
             sampleUnit: HKUnit.init(from: "count/min")),
        HealthItem(type: .walkingHeartRateAverage,
             image: "heart.fill",
             title: "歩行時平均心拍数",
             color: .pink,
             sampleValueTitle: "平均",
             sampleUnitText: "拍/分",
             sampleValueFormat: "%.0f",
             sampleUnit: HKUnit.init(from: "count/min")),
        // 歩行
        HealthItem(type: .sixMinuteWalkTestDistance,
             image: "figure.walk",
             title: "6分間歩行",
             color: .orange,
             sampleValueTitle: "平均",
             sampleUnitText: "m",
             sampleValueFormat: "%.0f",
             sampleUnit: HKUnit.meter()),
        /*
        HealthItem(type: .runningSpeed,
             image: "figure.walk",
             title: "ランニング速度",
             color: .orange,
             sampleValueTitle: "平均",
             sampleUnitText: "km/h",
             sampleValueFormat: "%.1f",
             sampleUnit: HKUnit.meter()),
        */
        HealthItem(type: .walkingAsymmetryPercentage,
             image: "figure.walk",
             title: "歩行非対称性",
             color: .orange,
             sampleValueTitle: "平均",
             sampleUnitText: "%",
             sampleValueFormat: "%.2f",
             sampleUnit: HKUnit.percent()),
        // 身体測定値
        HealthItem(type: .bodyMassIndex,
             image: "figure.arms.open",
             title: "ボディマス指数（BMI）",
             color: .purple,
             sampleValueTitle: "平均",
             sampleUnitText: "BMI",
             sampleValueFormat: "%.2f",
             sampleUnit: HKUnit.count()),
        HealthItem(type: .bodyFatPercentage,
             image: "figure.arms.open",
             title: "体脂肪率",
             color: .purple,
             sampleValueTitle: "平均",
             sampleUnitText: "%",
             sampleValueFormat: "%.2f",
             sampleUnit: HKUnit.percent()),
        HealthItem(type: .bodyMass,
             image: "figure.arms.open",
             title: "体重",
             color: .purple,
             sampleValueTitle: "平均",
             sampleUnitText: "kg",
             sampleValueFormat: "%.2f",
             sampleUnit: HKUnit.gramUnit(with: .kilo)),
        HealthItem(type: .waistCircumference,
             image: "figure.arms.open",
             title: "胸囲",
             color: .purple,
             sampleValueTitle: "平均",
             sampleUnitText: "kg",
             sampleValueFormat: "%.2f",
             sampleUnit: HKUnit.meterUnit(with: .centi)),
        HealthItem(type: .height,
             image: "figure.arms.open",
             title: "身長",
             color: .purple,
             sampleValueTitle: "平均",
             sampleUnitText: "cm",
             sampleValueFormat: "%.1f",
             sampleUnit: HKUnit.meterUnit(with: .centi)),
        HealthItem(type: .leanBodyMass,
             image: "figure.arms.open",
             title: "除脂肪体重（LBM）",
             color: .purple,
             sampleValueTitle: "平均",
             sampleUnitText: "kg",
             sampleValueFormat: "%.2f",
             sampleUnit: HKUnit.gramUnit(with: .kilo))
    ]
    
    @State private var showAlert = false
    
    init() {
    }
    
    var body: some View {
        if !isHealthAvailable {
            Text("この端末はサポートしていません")

        } else {

            NavigationStack {
                List {
                    ForEach(items) { item in
                        
                        NavigationLink {
                            //LineChartView(health: item)
                            
                            if item.type == .distanceWalkingRunning {
                                DistanceWalkingRunningChartView()
                                
                            } else
                            {

                                LineChartView(health: item)

                            }
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
                    
                    Section {
                        Button {
                            requestAuthorization()
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("ヘルスケアデータの読み取り許可")
                            }
                        }
                        .alert("ヘルスケアデータの読み取り許可", isPresented: $showAlert) {
                        } message: {
                            Text("ヘルスケアデータを読み取ってグラフを作成し表示します。アクセス許可を行ってください。許可・拒否は、「ヘルスケア」アプリの画面下にある「共有」から共有画面を開き、「App」の「ヘルスチャート」から行えます。")
                        }
                    }
                    
                    Section {
                        NavigationLink("test") {
                            SampleView()
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("ヘルスチャート")
            }
            
             
        }
    }
    
    private func requestAuthorization() {
        
        let types = items.map { HKObjectType.quantityType(forIdentifier: $0.type)! }
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
