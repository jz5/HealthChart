//
//  SettingsView.swift
//  HealthChart
//
//  Created by jz5 on 2023/03/04.
//

import SwiftUI
import HealthKit

struct SettingsView: View {
    @AppStorage("startYear") private var startYear = 2014
    let year = Calendar.current.component(.year, from: Date())

    @State private var cacheMonthCount = 0
    @State private var cacheByteCount = 0
    @State private var showClearConfirm = false
    @State private var didClear = false

    #if targetEnvironment(simulator)
    @State private var isSeeding = false
    @State private var seedResult: String?
    #endif

    var body: some View {
        Form {
            Section(header: Text("ヘルスケアデータ取得開始年")) {
                Stepper(value: $startYear, in: 1900...year) {
                    Text(verbatim: "\(startYear) 年")
                }
            }
            Section {
                LabeledContent("キャッシュ済み", value: cacheDescription)
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Text("キャッシュをクリア")
                }
                .disabled(cacheMonthCount == 0 && !didClear)
            } header: {
                Text("キャッシュ")
            } footer: {
                Text("過去の月の集計値を端末に保存して表示を高速化しています。「ヘルスケア」アプリで過去のデータを追加・編集・削除した場合は、キャッシュをクリアすると再集計されます。")
            }
            Section("開発支援") {
                Link("Amazonでお買物", destination: URL(string: "https://amzn.to/3pu7I6e")!)
                Link("開発者を太らせる", destination: URL(string: "https://www.amazon.co.jp/registry/wishlist/37IN0UYJ6N1JP/?_encoding=UTF8&camp=247&creative=1211&linkCode=ur2&tag=ks04-22")!)
            }
            Section {
                NavigationLink("法的表示") {
                    LicensesView()
                }
            }
            #if targetEnvironment(simulator)
            Section {
                Button {
                    Task { await seedDummyData() }
                } label: {
                    if isSeeding {
                        HStack {
                            ProgressView()
                            Text("生成中…")
                        }
                    } else {
                        Text("ダミーデータを生成(3年分)")
                    }
                }
                .disabled(isSeeding)
                if let seedResult {
                    Text(seedResult)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } header: {
                Text("開発用(シミュレータのみ)")
            } footer: {
                Text("歩数・体重・心拍数・血圧などのダミーデータを3年分書き込み、キャッシュをクリアします。")
            }
            #endif
        }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("設定")
            .task {
                await refreshCacheSummary()
            }
            .confirmationDialog("キャッシュをクリアしますか?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("クリア", role: .destructive) {
                    Task {
                        await HealthStatsService.shared.cache.clear()
                        didClear = true
                        await refreshCacheSummary()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("次回表示時にヘルスケアデータを再集計します。")
            }
    }

    private var cacheDescription: String {
        if cacheMonthCount == 0 {
            return "なし"
        }
        let size = ByteCountFormatter.string(fromByteCount: Int64(cacheByteCount), countStyle: .file)
        return "\(cacheMonthCount)ヶ月分(\(size))"
    }

    private func refreshCacheSummary() async {
        let summary = await HealthStatsService.shared.cache.summary()
        cacheMonthCount = summary.monthCount
        cacheByteCount = summary.byteCount
    }

    #if targetEnvironment(simulator)
    private func seedDummyData() async {
        isSeeding = true
        seedResult = nil
        do {
            let count = try await DummyDataSeeder.seed()
            await HealthStatsService.shared.cache.clear()
            await refreshCacheSummary()
            seedResult = "\(count)件書き込みました"
        } catch {
            seedResult = "失敗: \(error.localizedDescription)"
        }
        isSeeding = false
    }
    #endif
}

#if targetEnvironment(simulator)
/// シミュレータの動作確認用に、主要な項目のダミーデータを書き込む。
/// 歩数は増加・体重は減少トレンドにして、2項目比較で負の相関が見えるようにしている。
enum DummyDataSeeder {

    static func seed() async throws -> Int {
        let store = HKHealthStore()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount, .distanceWalkingRunning, .activeEnergyBurned,
            .bodyMass, .bodyFatPercentage,
            .heartRate, .restingHeartRate,
            .bloodPressureSystolic, .bloodPressureDiastolic,
        ]
        let types = Set(identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
        try await store.requestAuthorization(toShare: types, read: [])

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = 365 * 3
        let bpm = HKUnit.count().unitDivided(by: .minute())

        var samples: [HKQuantitySample] = []
        func add(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double, _ date: Date) {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: date, end: date))
        }

        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let noon = calendar.date(byAdding: .hour, value: 12, to: day),
                  let evening = calendar.date(byAdding: .hour, value: 18, to: day) else { continue }

            let past = Double(dayOffset) / Double(days) // 0=今日、1=3年前

            // 歩数は3年かけて増加、体重・体脂肪・血圧・安静時心拍は減少トレンド
            let steps = max(500, 6000 + 3500 * (1 - past) + .random(in: -2500...2500))
            add(.stepCount, .count(), steps.rounded(), noon)
            add(.distanceWalkingRunning, .meterUnit(with: .kilo), steps * 0.00065, noon)
            add(.activeEnergyBurned, .kilocalorie(), max(50, steps * 0.045 + .random(in: -40...40)), noon)
            add(.bodyMass, .gramUnit(with: .kilo), 59 + 5 * past + .random(in: -0.6...0.6), noon)
            add(.bodyFatPercentage, .percent(), 0.21 + 0.04 * past + .random(in: -0.008...0.008), noon)
            add(.restingHeartRate, bpm, 57 + 6 * past + .random(in: -3...3), noon)
            // 心拍数は安静時と運動時の2件(範囲チャート用)
            add(.heartRate, bpm, 52 + .random(in: 0...8), noon)
            add(.heartRate, bpm, 120 + .random(in: -15...25), evening)
            add(.bloodPressureSystolic, .millimeterOfMercury(), (118 + 12 * past + .random(in: -8...8)).rounded(), noon)
            add(.bloodPressureDiastolic, .millimeterOfMercury(), (76 + 7 * past + .random(in: -6...6)).rounded(), noon)
        }

        try await store.save(samples)

        var count = samples.count
        if #available(iOS 18.0, *) {
            count += try await seedWorkoutEffort(store: store, calendar: calendar, today: today)
        }
        return count
    }

    /// ワークアウトの運動量はワークアウトに関連付けないと保存できないため、
    /// ワークアウト本体を作って relateWorkoutEffortSample で書き込む。
    @available(iOS 18.0, *)
    private static func seedWorkoutEffort(store: HKHealthStore, calendar: Calendar, today: Date) async throws -> Int {
        guard let effortType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore) else { return 0 }
        try await store.requestAuthorization(toShare: [HKObjectType.workoutType(), effortType], read: [])

        var count = 0
        for dayOffset in stride(from: 0, to: 365, by: 3) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let start = calendar.date(byAdding: .hour, value: 19, to: day),
                  let end = calendar.date(byAdding: .minute, value: 30, to: start) else { continue }

            let workout = HKWorkout(activityType: .running, start: start, end: end)
            try await store.save(workout)

            let effort = HKQuantitySample(
                type: effortType,
                quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double.random(in: 1...10).rounded()),
                start: start, end: end)
            _ = try await store.relateWorkoutEffortSample(effort, with: workout, activity: nil)
            count += 2
        }
        return count
    }
}
#endif

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
