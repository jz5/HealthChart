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

enum HealthCategory: String, CaseIterable, Identifiable {
    case activity
    case heart
    case respiratory
    case body
    case nutrition
    case mobility
    case hearing
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activity: return "アクティビティ"
        case .heart: return "心臓"
        case .respiratory: return "呼吸"
        case .body: return "身体測定値"
        case .nutrition: return "栄養"
        case .mobility: return "歩行"
        case .hearing: return "聴覚"
        case .other: return "その他"
        }
    }

    var image: String {
        switch self {
        case .activity: return "flame.fill"
        case .heart: return "heart.fill"
        case .respiratory: return "lungs.fill"
        case .body: return "figure.arms.open"
        case .nutrition: return "carrot"
        case .mobility: return "figure.walk"
        case .hearing: return "ear.fill"
        case .other: return "cross.case.fill"
        }
    }

    var color: Color {
        switch self {
        case .activity: return .fitnessColor
        case .heart: return .pink
        case .respiratory: return .cyan
        case .body: return .purple
        case .nutrition: return .green
        case .mobility: return .orange
        case .hearing: return .blue
        case .other: return .indigo
        }
    }
}

struct HealthItem: Identifiable {
    let id = UUID()
    let type: HKQuantityTypeIdentifier
    let chart: ChartType
    let category: HealthCategory
    let image: String
    let title: String
    let color: Color
    let sampleValueTitle: String
    let sampleUnitText: String
    let sampleValueFormat: String
    let sampleUnit: HKUnit

    /// percent単位は0〜1で返るため表示時に100倍する
    var displayMultiplier: Double {
        sampleUnit == HKUnit.percent() ? 100 : 1
    }
}

class Health: ObservableObject {

    @Published var items: [HealthItem] = Health.buildItems()

    static let shared = Health()

    // MARK: - カタログ

    /// チャート種別はHealthKitの集計スタイルから自動判定する
    /// (累積=棒グラフ、離散=折れ線)。指定があればそれを優先。
    private static func make(_ type: HKQuantityTypeIdentifier,
                             _ title: String,
                             _ category: HealthCategory,
                             _ unit: HKUnit,
                             _ unitText: String,
                             _ format: String,
                             chart: ChartType? = nil) -> HealthItem {
        let resolvedChart: ChartType
        if let chart {
            resolvedChart = chart
        } else if let quantityType = HKQuantityType.quantityType(forIdentifier: type),
                  quantityType.aggregationStyle == .cumulative {
            resolvedChart = .bar
        } else {
            resolvedChart = .line
        }

        let valueTitle: String
        switch resolvedChart {
        case .bar: valueTitle = "1日の平均"
        case .bloodPress, .hidden: valueTitle = ""
        case .range: valueTitle = "範囲"
        default: valueTitle = "平均"
        }

        return HealthItem(
            type: type,
            chart: resolvedChart,
            category: category,
            image: category.image,
            title: title,
            color: category.color,
            sampleValueTitle: valueTitle,
            sampleUnitText: unitText,
            sampleValueFormat: format,
            sampleUnit: unit)
    }

    // MARK: 単位

    private static let kcal = HKUnit.largeCalorie()
    private static let km = HKUnit.meterUnit(with: .kilo)
    private static let meter = HKUnit.meter()
    private static let cm = HKUnit.meterUnit(with: .centi)
    private static let count = HKUnit.count()
    private static let minute = HKUnit.minute()
    private static let bpm = HKUnit.count().unitDivided(by: .minute())
    private static let ms = HKUnit.secondUnit(with: .milli)
    private static let percent = HKUnit.percent()
    private static let celsius = HKUnit.degreeCelsius()
    private static let watt = HKUnit.watt()
    private static let liter = HKUnit.liter()
    private static let literPerMinute = HKUnit.liter().unitDivided(by: .minute())
    private static let mL = HKUnit.literUnit(with: .milli)
    private static let gram = HKUnit.gram()
    private static let mg = HKUnit.gramUnit(with: .milli)
    private static let mcg = HKUnit.gramUnit(with: .micro)
    private static let kg = HKUnit.gramUnit(with: .kilo)
    private static let kmPerHour = HKUnit.meterUnit(with: .kilo).unitDivided(by: .hour())
    private static let meterPerSecond = HKUnit.meter().unitDivided(by: .second())
    private static let dBA = HKUnit.decibelAWeightedSoundPressureLevel()
    private static let mgPerDL = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    private static let vo2MaxUnit = HKUnit.literUnit(with: .milli)
        .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
    private static let metUnit = HKUnit.largeCalorie()
        .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .hour()))

    static func buildItems() -> [HealthItem] {
        var items: [HealthItem] = []

        // MARK: アクティビティ
        items += [
            make(.activeEnergyBurned, "アクティブエネルギー", .activity, kcal, "kcal", "%.0f"),
            make(.basalEnergyBurned, "安静時消費エネルギー", .activity, kcal, "kcal", "%.0f"),
            make(.stepCount, "歩数", .activity, count, "歩", "%.0f"),
            make(.distanceWalkingRunning, "ウォーキング+ランニングの距離", .activity, km, "km", "%.1f"),
            make(.appleExerciseTime, "エクササイズ時間", .activity, minute, "分", "%.0f"),
            make(.appleStandTime, "スタンド時間", .activity, minute, "分", "%.0f"),
            make(.appleMoveTime, "ムーブ時間", .activity, minute, "分", "%.0f"),
            make(.flightsClimbed, "上った階数", .activity, count, "階", "%.0f"),
            make(.distanceCycling, "自転車の走行距離", .activity, km, "km", "%.1f"),
            make(.distanceSwimming, "泳いだ距離", .activity, meter, "m", "%.0f"),
            make(.swimmingStrokeCount, "泳いだストローク数", .activity, count, "回", "%.0f"),
            make(.distanceWheelchair, "車椅子の走行距離", .activity, km, "km", "%.1f"),
            make(.pushCount, "プッシュ数", .activity, count, "回", "%.0f"),
            make(.distanceDownhillSnowSports, "ダウンヒルスノースポーツの距離", .activity, km, "km", "%.1f"),
            make(.runningSpeed, "ランニング速度", .activity, kmPerHour, "km/h", "%.1f"),
            make(.runningPower, "ランニングパワー", .activity, watt, "W", "%.0f"),
            make(.runningStrideLength, "ランニングの歩幅", .activity, meter, "m", "%.2f"),
            make(.runningVerticalOscillation, "上下動", .activity, cm, "cm", "%.1f"),
            make(.runningGroundContactTime, "接地時間", .activity, ms, "ミリ秒", "%.0f"),
            make(.underwaterDepth, "水深", .activity, meter, "m", "%.1f"),
        ]
        if #available(iOS 17.0, *) {
            items += [
                make(.physicalEffort, "身体的な運動量", .activity, metUnit, "MET", "%.1f"),
                make(.timeInDaylight, "日光下の時間", .activity, minute, "分", "%.0f"),
                make(.cyclingSpeed, "自転車走行速度", .activity, kmPerHour, "km/h", "%.1f"),
                make(.cyclingPower, "自転車走行パワー", .activity, watt, "W", "%.0f"),
                make(.cyclingCadence, "自転車走行ケイデンス", .activity, bpm, "rpm", "%.0f"),
                make(.cyclingFunctionalThresholdPower, "自転車走行FTP", .activity, watt, "W", "%.0f"),
            ]
        }
        if #available(iOS 18.0, *) {
            items += [
                make(.workoutEffortScore, "ワークアウトの運動量", .activity, HKUnit.appleEffortScore(), "", "%.0f"),
                make(.estimatedWorkoutEffortScore, "推定ワークアウト運動量", .activity, HKUnit.appleEffortScore(), "", "%.0f"),
                make(.distanceRowing, "ローイングの距離", .activity, km, "km", "%.1f"),
                make(.rowingSpeed, "ローイング速度", .activity, kmPerHour, "km/h", "%.1f"),
                make(.distancePaddleSports, "パドルスポーツの距離", .activity, km, "km", "%.1f"),
                make(.paddleSportsSpeed, "パドルスポーツ速度", .activity, kmPerHour, "km/h", "%.1f"),
                make(.distanceSkatingSports, "スケートスポーツの距離", .activity, km, "km", "%.1f"),
                make(.distanceCrossCountrySkiing, "クロスカントリースキーの距離", .activity, km, "km", "%.1f"),
                make(.crossCountrySkiingSpeed, "クロスカントリースキー速度", .activity, kmPerHour, "km/h", "%.1f"),
            ]
        }

        // MARK: 心臓
        items += [
            make(.heartRate, "心拍数", .heart, bpm, "拍/分", "%.0f", chart: .range),
            make(.restingHeartRate, "安静時心拍数", .heart, bpm, "拍/分", "%.0f"),
            make(.walkingHeartRateAverage, "歩行時平均心拍数", .heart, bpm, "拍/分", "%.0f"),
            make(.heartRateVariabilitySDNN, "心拍変動", .heart, ms, "ミリ秒", "%.0f"),
            make(.heartRateRecoveryOneMinute, "心拍数回復", .heart, bpm, "拍/分", "%.0f"),
            make(.vo2Max, "最大酸素摂取量(VO₂max)", .heart, vo2MaxUnit, "mL/kg・分", "%.1f"),
            make(.peripheralPerfusionIndex, "末梢血流量指標", .heart, percent, "%", "%.1f"),
            make(.atrialFibrillationBurden, "心房細動の履歴", .heart, percent, "%", "%.1f"),
            make(.bloodPressureSystolic, "血圧", .heart, HKUnit.millimeterOfMercury(), "mmHg", "%.0f", chart: .bloodPress),
            make(.bloodPressureDiastolic, "血圧", .heart, HKUnit.millimeterOfMercury(), "mmHg", "%.0f", chart: .hidden),
        ]

        // MARK: 呼吸
        items += [
            make(.respiratoryRate, "呼吸数", .respiratory, bpm, "回/分", "%.1f"),
            make(.oxygenSaturation, "取り込まれた酸素のレベル", .respiratory, percent, "%", "%.1f"),
            make(.forcedVitalCapacity, "努力肺活量", .respiratory, liter, "L", "%.2f"),
            make(.forcedExpiratoryVolume1, "1秒量(FEV1)", .respiratory, liter, "L", "%.2f"),
            make(.peakExpiratoryFlowRate, "最大呼気流量", .respiratory, literPerMinute, "L/分", "%.0f"),
            make(.inhalerUsage, "吸入器の使用状況", .respiratory, count, "回", "%.0f"),
        ]

        // MARK: 身体測定値
        items += [
            make(.height, "身長", .body, cm, "cm", "%.1f"),
            make(.bodyMass, "体重", .body, kg, "kg", "%.2f"),
            make(.bodyMassIndex, "ボディマス指数(BMI)", .body, count, "BMI", "%.2f"),
            make(.bodyFatPercentage, "体脂肪率", .body, percent, "%", "%.2f"),
            make(.leanBodyMass, "除脂肪体重(LBM)", .body, kg, "kg", "%.2f"),
            make(.waistCircumference, "胴囲", .body, cm, "cm", "%.1f"),
            make(.bodyTemperature, "体温", .body, celsius, "℃", "%.2f"),
            make(.basalBodyTemperature, "基礎体温", .body, celsius, "℃", "%.2f"),
            make(.appleSleepingWristTemperature, "睡眠時の手首皮膚温", .body, celsius, "℃", "%.2f"),
        ]
        if #available(iOS 18.0, *) {
            items += [
                make(.appleSleepingBreathingDisturbances, "睡眠時呼吸乱れ", .body, count, "回", "%.1f"),
            ]
        }

        // MARK: 栄養
        items += [
            make(.dietaryEnergyConsumed, "摂取エネルギー", .nutrition, kcal, "kcal", "%.0f"),
            make(.dietaryProtein, "タンパク質", .nutrition, gram, "g", "%.1f"),
            make(.dietaryCarbohydrates, "炭水化物", .nutrition, gram, "g", "%.1f"),
            make(.dietaryFiber, "食物繊維", .nutrition, gram, "g", "%.1f"),
            make(.dietarySugar, "糖質", .nutrition, gram, "g", "%.1f"),
            make(.dietaryFatTotal, "総脂肪", .nutrition, gram, "g", "%.1f"),
            make(.dietaryFatSaturated, "飽和脂肪酸", .nutrition, gram, "g", "%.1f"),
            make(.dietaryFatMonounsaturated, "一価不飽和脂肪酸", .nutrition, gram, "g", "%.1f"),
            make(.dietaryFatPolyunsaturated, "多価不飽和脂肪酸", .nutrition, gram, "g", "%.1f"),
            make(.dietaryCholesterol, "コレステロール", .nutrition, mg, "mg", "%.0f"),
            make(.dietarySodium, "ナトリウム", .nutrition, mg, "mg", "%.0f"),
            make(.dietaryPotassium, "カリウム", .nutrition, mg, "mg", "%.0f"),
            make(.dietaryCalcium, "カルシウム", .nutrition, mg, "mg", "%.0f"),
            make(.dietaryIron, "鉄", .nutrition, mg, "mg", "%.1f"),
            make(.dietaryMagnesium, "マグネシウム", .nutrition, mg, "mg", "%.0f"),
            make(.dietaryPhosphorus, "リン", .nutrition, mg, "mg", "%.0f"),
            make(.dietaryZinc, "亜鉛", .nutrition, mg, "mg", "%.1f"),
            make(.dietaryCopper, "銅", .nutrition, mg, "mg", "%.2f"),
            make(.dietaryManganese, "マンガン", .nutrition, mg, "mg", "%.2f"),
            make(.dietaryChromium, "クロム", .nutrition, mcg, "µg", "%.0f"),
            make(.dietaryMolybdenum, "モリブデン", .nutrition, mcg, "µg", "%.0f"),
            make(.dietarySelenium, "セレン", .nutrition, mcg, "µg", "%.0f"),
            make(.dietaryIodine, "ヨウ素", .nutrition, mcg, "µg", "%.0f"),
            make(.dietaryChloride, "塩化物", .nutrition, mg, "mg", "%.0f"),
            make(.dietaryVitaminA, "ビタミンA", .nutrition, mcg, "µg", "%.0f"),
            make(.dietaryThiamin, "ビタミンB1(チアミン)", .nutrition, mg, "mg", "%.2f"),
            make(.dietaryRiboflavin, "ビタミンB2(リボフラビン)", .nutrition, mg, "mg", "%.2f"),
            make(.dietaryNiacin, "ナイアシン", .nutrition, mg, "mg", "%.1f"),
            make(.dietaryPantothenicAcid, "パントテン酸", .nutrition, mg, "mg", "%.1f"),
            make(.dietaryVitaminB6, "ビタミンB6", .nutrition, mg, "mg", "%.2f"),
            make(.dietaryBiotin, "ビオチン", .nutrition, mcg, "µg", "%.0f"),
            make(.dietaryVitaminB12, "ビタミンB12", .nutrition, mcg, "µg", "%.2f"),
            make(.dietaryVitaminC, "ビタミンC", .nutrition, mg, "mg", "%.0f"),
            make(.dietaryVitaminD, "ビタミンD", .nutrition, mcg, "µg", "%.1f"),
            make(.dietaryVitaminE, "ビタミンE", .nutrition, mg, "mg", "%.1f"),
            make(.dietaryVitaminK, "ビタミンK", .nutrition, mcg, "µg", "%.0f"),
            make(.dietaryFolate, "葉酸", .nutrition, mcg, "µg", "%.0f"),
            make(.dietaryWater, "水分", .nutrition, mL, "mL", "%.0f"),
            make(.dietaryCaffeine, "カフェイン", .nutrition, mg, "mg", "%.0f"),
        ]

        // MARK: 歩行
        items += [
            make(.walkingSpeed, "歩行速度", .mobility, kmPerHour, "km/h", "%.1f"),
            make(.walkingStepLength, "歩幅", .mobility, cm, "cm", "%.1f"),
            make(.walkingDoubleSupportPercentage, "両脚支持時間", .mobility, percent, "%", "%.1f"),
            make(.walkingAsymmetryPercentage, "歩行非対称性", .mobility, percent, "%", "%.2f"),
            make(.appleWalkingSteadiness, "歩行安定性", .mobility, percent, "%", "%.0f"),
            make(.sixMinuteWalkTestDistance, "6分間歩行", .mobility, meter, "m", "%.0f"),
            make(.stairAscentSpeed, "階段を上る速度", .mobility, meterPerSecond, "m/秒", "%.2f"),
            make(.stairDescentSpeed, "階段を下りる速度", .mobility, meterPerSecond, "m/秒", "%.2f"),
        ]

        // MARK: 聴覚
        items += [
            make(.environmentalAudioExposure, "環境音レベル", .hearing, dBA, "dB", "%.0f"),
            make(.headphoneAudioExposure, "ヘッドフォン音量", .hearing, dBA, "dB", "%.0f"),
            make(.environmentalSoundReduction, "環境音の低減", .hearing, dBA, "dB", "%.0f"),
        ]

        // MARK: その他
        items += [
            make(.bloodGlucose, "血糖値", .other, mgPerDL, "mg/dL", "%.0f"),
            make(.bloodAlcoholContent, "血中アルコール濃度", .other, percent, "%", "%.2f"),
            make(.insulinDelivery, "インスリン放出", .other, HKUnit.internationalUnit(), "単位", "%.1f"),
            make(.numberOfAlcoholicBeverages, "アルコール飲料の数", .other, count, "杯", "%.0f"),
            make(.numberOfTimesFallen, "転倒回数", .other, count, "回", "%.0f"),
            make(.uvExposure, "紫外線指数", .other, count, "", "%.0f"),
        ]

        // 現在のOSで利用できないタイプを除外する
        return items.filter { HKQuantityType.quantityType(forIdentifier: $0.type) != nil }
    }
}

/// お気に入り項目(追加順)をUserDefaultsに保持する
final class Favorites: ObservableObject {
    static let shared = Favorites()
    private static let key = "favoriteTypes"

    @Published private(set) var types: [String]

    private init() {
        types = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func contains(_ item: HealthItem) -> Bool {
        types.contains(item.type.rawValue)
    }

    func toggle(_ item: HealthItem) {
        if let index = types.firstIndex(of: item.type.rawValue) {
            types.remove(at: index)
        } else {
            types.append(item.type.rawValue)
        }
        UserDefaults.standard.set(types, forKey: Self.key)
    }
}

/// printfフォーマットの小数桁数を保ちつつ、3桁区切りで数値を整形する
func formatValue(_ value: Double, _ format: String, locale: Locale = .current) -> String {
    let digits: Int
    if let match = format.range(of: #"%[+]?\.(\d+)f"#, options: .regularExpression) {
        let digitsText = format[match].drop { $0 != "." }.dropFirst().dropLast()
        digits = Int(digitsText) ?? 0
    } else {
        digits = 0
    }
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.roundingMode = .halfUp
    formatter.minimumFractionDigits = digits
    formatter.maximumFractionDigits = digits
    return formatter.string(from: NSNumber(value: value)) ?? String(format: format, value)
}

/// 2項目比較のお気に入りの組み合わせ("typeA|typeB" 形式、追加順)をUserDefaultsに保持する
final class ComparisonPairs: ObservableObject {
    static let shared = ComparisonPairs()
    private static let key = "comparisonPairs"

    @Published private(set) var pairs: [String]

    private init() {
        pairs = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    static func pairKey(_ a: String, _ b: String) -> String { a + "|" + b }

    /// 順序によらず同じ組み合わせとみなす
    func contains(_ a: String, _ b: String) -> Bool {
        pairs.contains(Self.pairKey(a, b)) || pairs.contains(Self.pairKey(b, a))
    }

    func toggle(_ a: String, _ b: String) {
        if let index = pairs.firstIndex(where: { $0 == Self.pairKey(a, b) || $0 == Self.pairKey(b, a) }) {
            pairs.remove(at: index)
        } else {
            pairs.append(Self.pairKey(a, b))
        }
        UserDefaults.standard.set(pairs, forKey: Self.key)
    }

    func remove(_ key: String) {
        pairs.removeAll { $0 == key }
        UserDefaults.standard.set(pairs, forKey: Self.key)
    }
}
