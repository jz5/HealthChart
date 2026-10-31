//
//  HealthStatsService.swift
//  HealthChart
//
//  HealthKitへの問い合わせを1項目1クエリに集約し、
//  確定した過去の月の集計値をキャッシュする。
//

import Foundation
import HealthKit

final class HealthStatsService {

    static let shared = HealthStatsService()

    let cache: StatsCache
    private let store: HKHealthStore?

    init(store: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil,
         cache: StatsCache = StatsCache()) {
        self.store = store
        self.cache = cache
    }

    /// 読み取り許可をリクエストする(未決定のタイプがある場合のみ)
    /// - Returns: リクエストを実行した場合 true
    func requestAuthorizationIfNeeded(for items: [HealthItem]) async -> Bool {
        guard let store else { return false }
        let types = items.compactMap { HKObjectType.quantityType(forIdentifier: $0.type) }
        let notDetermined = types.contains { store.authorizationStatus(for: $0) == .notDetermined }
        guard notDetermined else { return false }

        _ = try? await store.requestAuthorization(toShare: [], read: Set(types))
        return true
    }

    /// HKStatisticsクエリが使えないタイプ。サンプルを直接取得して集計する。
    /// (ワークアウトの運動量は統計クエリで例外が発生しクラッシュする)
    static func isSampleQueryOnly(_ type: HKQuantityTypeIdentifier) -> Bool {
        if #available(iOS 18.0, *) {
            return type == .workoutEffortScore || type == .estimatedWorkoutEffortScore
        }
        return false
    }

    /// startYear 1月から今月までの月次集計を返す(データのない月は含まない)。
    /// 過去の月はキャッシュを利用し、キャッシュにない月と今月だけHealthKitに問い合わせる。
    /// progress には集計の進み具合(0〜1)を複数回通知する(キャッシュ済みで今月だけの場合は通知しない)。
    func monthlyStats(for item: HealthItem, startYear: Int,
                      progress: (@Sendable (Double) -> Void)? = nil) async -> [MonthlyStat] {
        guard store != nil,
              let quantityType = HKQuantityType.quantityType(forIdentifier: item.type) else {
            return []
        }

        let now = Date()
        let required = MonthMath.requiredMonths(startYear: startYear, now: now)
        guard !required.isEmpty else { return [] }

        let unitString = item.sampleUnit.unitString
        let cached = await cache.stats(for: item.type.rawValue, unit: unitString)
        let spans = MonthMath.missingSpans(required: required, cachedKeys: Set(cached.keys), now: now)
            .flatMap { MonthMath.splitSpan($0, maxMonths: 12) }

        var result = cached

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: now)
        let currentKey = MonthlyStat.key(year: comps.year ?? 0, month: comps.month ?? 0)

        let totalMonths = spans.reduce(0) { $0 + MonthMath.monthCount($1) }
        var doneMonths = 0

        for span in spans {
            let queried: [MonthlyStat]
            if Self.isSampleQueryOnly(item.type) {
                queried = await queryDiscreteViaSamples(quantityType: quantityType, unit: item.sampleUnit, span: span, now: now)
            } else if quantityType.aggregationStyle == .cumulative {
                queried = await queryCumulative(quantityType: quantityType, unit: item.sampleUnit, span: span, now: now)
            } else {
                queried = await queryDiscrete(quantityType: quantityType, unit: item.sampleUnit, span: span, now: now)
            }
            for stat in queried {
                result[stat.key] = stat
            }
            // 今月はまだ値が変わるのでキャッシュしない
            let completed = queried.filter { $0.key != currentKey }
            await cache.store(completed, for: item.type.rawValue, unit: unitString)

            doneMonths += MonthMath.monthCount(span)
            // 今月1ヶ月だけの再集計では進捗を出さない(すぐ終わるため)
            if totalMonths > 1 {
                progress?(Double(doneMonths) / Double(totalMonths))
            }
        }

        let stats = required
            .compactMap { result[MonthlyStat.key(year: $0.year, month: $0.month)] }
            .filter { $0.hasData }
            .sorted { ($0.year, $0.month) < ($1.year, $1.month) }

        // ホーム一覧の「データなし」表示を実際の集計結果で更新する
        let hasData = !stats.isEmpty
        let typeRaw = item.type.rawValue
        Task { @MainActor in
            DataAvailability.shared.update(type: typeRaw, hasData: hasData)
        }
        return stats
    }

    /// 選択期間の正確な平均(離散型)。スライダー操作時の再計算に使う。
    func discreteAverage(for item: HealthItem, start: Date, end: Date) async -> Double? {
        guard let store,
              let quantityType = HKQuantityType.quantityType(forIdentifier: item.type) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        // 統計クエリ非対応タイプはサンプルから平均を計算する
        if Self.isSampleQueryOnly(item.type) {
            let values: [Double] = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: quantityType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil) { _, samples, _ in
                        let values = ((samples as? [HKQuantitySample]) ?? [])
                            .filter { $0.quantity.is(compatibleWith: item.sampleUnit) }
                            .map { $0.quantity.doubleValue(for: item.sampleUnit) }
                        continuation.resume(returning: values)
                    }
                store.execute(query)
            }
            return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage]) { _, statistics, _ in
                    let value = statistics?.averageQuantity()?.doubleValue(for: item.sampleUnit)
                    continuation.resume(returning: value)
                }
            store.execute(query)
        }
    }

    // MARK: - Queries

    /// 累積型: 日単位で合計を取り、月ごとに「合計」「データのあった日数」へ畳み込む
    private func queryCumulative(quantityType: HKQuantityType, unit: HKUnit, span: MonthSpan, now: Date) async -> [MonthlyStat] {
        let start = span.startDate
        let end = min(span.endDate, now)
        guard start < end else { return [] }

        guard let collection = await statisticsCollection(
            quantityType: quantityType,
            options: [.cumulativeSum],
            anchorDate: start,
            interval: DateComponents(day: 1),
            start: start, end: end) else { return [] }

        let calendar = Calendar.current
        var stats: [String: MonthlyStat] = [:]

        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            guard let value = statistics.sumQuantity()?.doubleValue(for: unit) else { return }
            let comps = calendar.dateComponents([.year, .month], from: statistics.startDate)
            guard let year = comps.year, let month = comps.month else { return }

            let key = MonthlyStat.key(year: year, month: month)
            var stat = stats[key] ?? MonthlyStat(year: year, month: month)
            stat.sum += value
            stat.dayCount += 1
            stats[key] = stat
        }

        return fillEmptyMonths(stats: stats, span: span, now: now)
    }

    /// 離散型: 月単位で平均・最小・最大を取る
    private func queryDiscrete(quantityType: HKQuantityType, unit: HKUnit, span: MonthSpan, now: Date) async -> [MonthlyStat] {
        let start = span.startDate
        let end = min(span.endDate, now)
        guard start < end else { return [] }

        guard let collection = await statisticsCollection(
            quantityType: quantityType,
            options: [.discreteAverage, .discreteMin, .discreteMax],
            anchorDate: start,
            interval: DateComponents(month: 1),
            start: start, end: end) else { return [] }

        let calendar = Calendar.current
        var stats: [String: MonthlyStat] = [:]

        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            let comps = calendar.dateComponents([.year, .month], from: statistics.startDate)
            guard let year = comps.year, let month = comps.month else { return }

            var stat = MonthlyStat(year: year, month: month)
            stat.average = statistics.averageQuantity()?.doubleValue(for: unit)
            stat.minValue = statistics.minimumQuantity()?.doubleValue(for: unit)
            stat.maxValue = statistics.maximumQuantity()?.doubleValue(for: unit)
            if stat.hasData {
                stats[stat.key] = stat
            }
        }

        return fillEmptyMonths(stats: stats, span: span, now: now)
    }

    /// 統計クエリ非対応タイプ用: サンプルを直接取得して月ごとの平均・最小・最大に畳み込む
    private func queryDiscreteViaSamples(quantityType: HKQuantityType, unit: HKUnit, span: MonthSpan, now: Date) async -> [MonthlyStat] {
        let start = span.startDate
        let end = min(span.endDate, now)
        guard start < end, let store else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil) { _, samples, _ in
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            store.execute(query)
        }

        let calendar = Calendar.current
        var stats: [String: MonthlyStat] = [:]

        for sample in samples {
            guard sample.quantity.is(compatibleWith: unit) else { continue }
            let value = sample.quantity.doubleValue(for: unit)
            let comps = calendar.dateComponents([.year, .month], from: sample.startDate)
            guard let year = comps.year, let month = comps.month else { continue }

            let key = MonthlyStat.key(year: year, month: month)
            var stat = stats[key] ?? MonthlyStat(year: year, month: month)
            // sum/dayCountを件数平均の作業領域として使い、最後にaverageへ移す
            stat.sum += value
            stat.dayCount += 1
            stat.minValue = Swift.min(stat.minValue ?? value, value)
            stat.maxValue = Swift.max(stat.maxValue ?? value, value)
            stats[key] = stat
        }

        for (key, var stat) in stats {
            stat.average = stat.dayCount > 0 ? stat.sum / Double(stat.dayCount) : nil
            stat.sum = 0
            stat.dayCount = 0
            stats[key] = stat
        }

        return fillEmptyMonths(stats: stats, span: span, now: now)
    }

    /// クエリ結果にない月も「データなし」としてキャッシュできるよう空のMonthlyStatで埋める
    private func fillEmptyMonths(stats: [String: MonthlyStat], span: MonthSpan, now: Date) -> [MonthlyStat] {
        var result: [MonthlyStat] = []
        var year = span.startYear
        var month = span.startMonth
        let calendar = Calendar.current
        let nowComps = calendar.dateComponents([.year, .month], from: now)

        while (year, month) <= (span.endYear, span.endMonth) {
            // 未来の月は対象外
            if (year, month) > (nowComps.year ?? 0, nowComps.month ?? 0) { break }
            let key = MonthlyStat.key(year: year, month: month)
            result.append(stats[key] ?? MonthlyStat(year: year, month: month))
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
        }
        return result
    }

    /// 読み取り許可ダイアログをまだ一度も表示していないか(初回起動の判定に使う)
    func isAuthorizationUnrequested(for items: [HealthItem]) async -> Bool {
        guard let store else { return true }
        let types = Set(items.compactMap { HKObjectType.quantityType(forIdentifier: $0.type) })
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: types)
        return status == .shouldRequest
    }

    /// 項目にサンプルが1件でも存在するかを調べる(limit 1の軽いクエリ)。
    /// チャートの集計と判定を揃えるため、startYear以降だけを見る。
    func hasAnySample(for item: HealthItem, startYear: Int) async -> Bool {
        guard let store,
              let type = HKQuantityType.quantityType(forIdentifier: item.type) else { return false }
        let start = Calendar.current.date(from: DateComponents(year: startYear, month: 1, day: 1))
        let predicate = start.map { HKQuery.predicateForSamples(withStart: $0, end: nil) }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: !(samples?.isEmpty ?? true))
            }
            store.execute(query)
        }
    }

    private func statisticsCollection(quantityType: HKQuantityType,
                                      options: HKStatisticsOptions,
                                      anchorDate: Date,
                                      interval: DateComponents,
                                      start: Date,
                                      end: Date) async -> HKStatisticsCollection? {
        guard let store else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval)
            query.initialResultsHandler = { _, collection, _ in
                continuation.resume(returning: collection)
            }
            store.execute(query)
        }
    }
}

/// 各項目にヘルスケアデータが存在するかを裏で調べ、ホーム一覧の薄色表示に使う。
///
/// HealthKitは読み取り拒否をアプリに教えないため、「データなし」と「読み取り不許可」は
/// 区別できず、どちらも false になる。あとから許可やデータ追加で読めるようになることが
/// あるので、起動時・フォアグラウンド復帰時・Pull to Refreshで再スキャンし、
/// チャート画面の集計結果でも随時更新する。
@MainActor
final class DataAvailability: ObservableObject {
    static let shared = DataAvailability()
    private static let key = "dataAvailability"

    /// type.rawValue → データが1件でもあるか。未調査の項目はキーなし。
    @Published private(set) var available: [String: Bool]

    private var isScanning = false
    private var lastScan: Date?
    /// 自動スキャン(起動時・フォアグラウンド復帰時)の最短間隔
    private static let autoScanInterval: TimeInterval = 5 * 60

    private init() {
        available = (UserDefaults.standard.dictionary(forKey: Self.key) as? [String: Bool]) ?? [:]
    }

    /// nil は未調査(通常表示にする)
    func hasData(_ item: HealthItem) -> Bool? {
        available[item.type.rawValue]
    }

    /// チャート画面の集計結果から即時更新する
    func update(type: String, hasData: Bool) {
        guard available[type] != hasData else { return }
        available[type] = hasData
        UserDefaults.standard.set(available, forKey: Self.key)
    }

    /// 全項目を軽いクエリ(limit 1)で順にスキャンする。判明した項目から表示に反映される。
    /// forceでなければ前回スキャンから一定時間はスキップする(フォアグラウンド復帰のたびの全走査を避ける)。
    func refresh(items: [HealthItem], force: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable(), !isScanning else { return }
        if !force, let lastScan, Date().timeIntervalSince(lastScan) < Self.autoScanInterval {
            return
        }
        // 認可ダイアログを一度も出していない初回起動では全項目が「なし」と
        // 誤判定されて一覧全体が薄色になるため、スキャンしない(未調査=通常表示)
        if await HealthStatsService.shared.isAuthorizationUnrequested(for: items) {
            return
        }
        isScanning = true
        defer { isScanning = false }

        let startYear = UserDefaults.standard.object(forKey: "startYear") as? Int ?? 2014
        for item in items {
            let hasData = await HealthStatsService.shared.hasAnySample(for: item, startYear: startYear)
            if available[item.type.rawValue] != hasData {
                available[item.type.rawValue] = hasData
            }
        }
        UserDefaults.standard.set(available, forKey: Self.key)
        lastScan = Date()
    }
}
