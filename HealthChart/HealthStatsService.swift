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

    /// startYear 1月から今月までの月次集計を返す(データのない月は含まない)。
    /// 過去の月はキャッシュを利用し、キャッシュにない月と今月だけHealthKitに問い合わせる。
    func monthlyStats(for item: HealthItem, startYear: Int) async -> [MonthlyStat] {
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

        var result = cached

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: now)
        let currentKey = MonthlyStat.key(year: comps.year ?? 0, month: comps.month ?? 0)

        for span in spans {
            let queried: [MonthlyStat]
            if quantityType.aggregationStyle == .cumulative {
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
        }

        return required
            .compactMap { result[MonthlyStat.key(year: $0.year, month: $0.month)] }
            .filter { $0.hasData }
            .sorted { ($0.year, $0.month) < ($1.year, $1.month) }
    }

    /// 選択期間の正確な平均(離散型)。スライダー操作時の再計算に使う。
    func discreteAverage(for item: HealthItem, start: Date, end: Date) async -> Double? {
        guard let store,
              let quantityType = HKQuantityType.quantityType(forIdentifier: item.type) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

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
