//
//  Health.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/23.
//

import SwiftUI
import Charts
import HealthKit
import Foundation

enum ChartType {
    case bar
    case line
    case range
    case bloodPress
    case hidden
}

struct HealthItem: Identifiable {
    let id = UUID()
    let type: HKQuantityTypeIdentifier
    let chart: ChartType
    let image: String
    let title: String
    let color: Color
    let sampleValueTitle: String
    let sampleUnitText: String
    let sampleValueFormat: String
    let sampleUnit: HKUnit

    var isVisible: Bool

    init(type: HKQuantityTypeIdentifier,
        chart: ChartType,
        image: String,
        title: String,
        color: Color,
        sampleValueTitle: String,
        sampleUnitText: String,
        sampleValueFormat: String,
        sampleUnit: HKUnit,
        isVisible: Bool = true) {

        self.type = type
        self.chart = chart
        self.image = image
        self.title = title
        self.color = color
        self.sampleValueTitle = sampleValueTitle
        self.sampleUnitText = sampleUnitText
        self.sampleValueFormat = sampleValueFormat
        self.sampleUnit = sampleUnit
        self.isVisible = isVisible
    }
}

class Health: ObservableObject {

    init() {
        for (index, item) in items.enumerated() {
            items[index].isVisible = UserDefaults.standard.isVisible(for: item.type)
        }
    }

    func updateVisibility(for item: HealthItem, to isVisible: Bool) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isVisible = isVisible
            UserDefaults.standard.setVisibility(isVisible, for: item.type)

            // Update the entire items array to notify the change
            items = items
        }
    }


    @Published var items: [HealthItem] = [
        HealthItem(type: .activeEnergyBurned,
            chart: .bar,
            image: "flame.fill",
            title: "アクティブエネルギー",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "kcal",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.largeCalorie()),
        HealthItem(type: .distanceWalkingRunning,
            chart: .bar,
            image: "flame.fill",
            title: "ウォーキング+ランニングの距離",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "km",
            sampleValueFormat: "%.1f",
            sampleUnit: HKUnit.meterUnit(with: .kilo)),
        HealthItem(type: .appleExerciseTime,
            chart: .bar,
            image: "flame.fill",
            title: "エクササイズ時間",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "分",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.minute()),
        HealthItem(type: .appleStandTime,
            chart: .bar,
            image: "flame.fill",
            title: "スタンド時間（分）",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "分",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.minute()),
        HealthItem(type: .appleStandTime,
            chart: .bar,
            image: "flame.fill",
            title: "ワークアウト",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "分",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.minute()),
        HealthItem(type: .flightsClimbed,
            chart: .bar,
            image: "flame.fill",
            title: "上った階数",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "階",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.count()),
        HealthItem(type: .stepCount,
            chart: .bar,
            image: "flame.fill",
            title: "歩数",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "歩",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.count()),
        HealthItem(type: .distanceSwimming,
            chart: .bar,
            image: "flame.fill",
            title: "泳いだ距離",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "m",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.meter()),
        HealthItem(type: .distanceCycling,
            chart: .bar,
            image: "flame.fill",
            title: "自転車の走行距離",
            color: .fitnessColor,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "km",
            sampleValueFormat: "%.1f",
            sampleUnit: HKUnit.meterUnit(with: .kilo)),
        // 心臓
        HealthItem(type: .restingHeartRate,
            chart: .line,
            image: "heart.fill",
            title: "安静時心拍数",
            color: .pink,
            sampleValueTitle: "平均",
            sampleUnitText: "拍/分",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.init(from: "count/min")),
        HealthItem(type: .heartRateVariabilitySDNN,
            chart: .line,
            image: "heart.fill",
            title: "心拍変動",
            color: .pink,
            sampleValueTitle: "平均",
            sampleUnitText: "ミリ秒",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.secondUnit(with: .milli)),
//        HealthItem(type: .heartRate,
//            chart: .range,
//            image: "heart.fill",
//            title: "心拍数",
//            color: .pink,
//            sampleValueTitle: "範囲",
//            sampleUnitText: "拍/分",
//            sampleValueFormat: "%.0f",
//            sampleUnit: HKUnit.init(from: "count/min")),
        HealthItem(type: .heartRateRecoveryOneMinute,
            chart: .line,
            image: "heart.fill",
            title: "心拍数回復",
            color: .pink,
            sampleValueTitle: "平均",
            sampleUnitText: "拍/分",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.init(from: "count/min")),
        HealthItem(type: .walkingHeartRateAverage,
            chart: .line,
            image: "heart.fill",
            title: "歩行時平均心拍数",
            color: .pink,
            sampleValueTitle: "平均",
            sampleUnitText: "拍/分",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.init(from: "count/min")),
        HealthItem(type: .bloodPressureSystolic,
            chart: .bloodPress,
            image: "heart.fill",
            title: "血圧",
            color: .pink,
            sampleValueTitle: "",
            sampleUnitText: "mmHg",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.millimeterOfMercury()),
        HealthItem(type: .bloodPressureDiastolic,
            chart: .hidden,
            image: "heart.fill",
            title: "血圧",
            color: .pink,
            sampleValueTitle: "",
            sampleUnitText: "mmHg",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.millimeterOfMercury()),
        // 栄養
        HealthItem(type: .dietaryEnergyConsumed,
            chart: .bar,
            image: "carrot",
            title: "摂取エネルギー",
            color: .green,
            sampleValueTitle: "1日の平均",
            sampleUnitText: "kcal",
            sampleValueFormat: "%.0f",
            sampleUnit: HKUnit.largeCalorie()),

        // 歩行
        HealthItem(type: .sixMinuteWalkTestDistance,
            chart: .line,
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
            chart: .line,
            image: "figure.walk",
            title: "歩行非対称性",
            color: .orange,
            sampleValueTitle: "平均",
            sampleUnitText: "%",
            sampleValueFormat: "%.2f",
            sampleUnit: HKUnit.percent()),
        // 身体測定値
        HealthItem(type: .bodyMassIndex,
            chart: .line,
            image: "figure.arms.open",
            title: "ボディマス指数（BMI）",
            color: .purple,
            sampleValueTitle: "平均",
            sampleUnitText: "BMI",
            sampleValueFormat: "%.2f",
            sampleUnit: HKUnit.count()),
        HealthItem(type: .bodyFatPercentage,
            chart: .line,
            image: "figure.arms.open",
            title: "体脂肪率",
            color: .purple,
            sampleValueTitle: "平均",
            sampleUnitText: "%",
            sampleValueFormat: "%.2f",
            sampleUnit: HKUnit.percent()),
        HealthItem(type: .bodyMass,
            chart: .line,
            image: "figure.arms.open",
            title: "体重",
            color: .purple,
            sampleValueTitle: "平均",
            sampleUnitText: "kg",
            sampleValueFormat: "%.2f",
            sampleUnit: HKUnit.gramUnit(with: .kilo)),
        HealthItem(type: .waistCircumference,
            chart: .line,
            image: "figure.arms.open",
            title: "胸囲",
            color: .purple,
            sampleValueTitle: "平均",
            sampleUnitText: "kg",
            sampleValueFormat: "%.2f",
            sampleUnit: HKUnit.meterUnit(with: .centi)),
        HealthItem(type: .height,
            chart: .line,
            image: "figure.arms.open",
            title: "身長",
            color: .purple,
            sampleValueTitle: "平均",
            sampleUnitText: "cm",
            sampleValueFormat: "%.1f",
            sampleUnit: HKUnit.meterUnit(with: .centi)),
        HealthItem(type: .leanBodyMass,
            chart: .line,
            image: "figure.arms.open",
            title: "除脂肪体重（LBM）",
            color: .purple,
            sampleValueTitle: "平均",
            sampleUnitText: "kg",
            sampleValueFormat: "%.2f",
            sampleUnit: HKUnit.gramUnit(with: .kilo))
    ]

}
