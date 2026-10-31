//
//  HealthChartTests.swift
//  HealthChartTests
//

import Testing
import Foundation
import HealthKit
@testable import HealthChart

// MARK: - MonthMath

struct MonthMathTests {

    private func date(_ year: Int, _ month: Int, _ day: Int = 15) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func requiredMonthsは開始年1月から今月まで() {
        let months = MonthMath.requiredMonths(startYear: 2024, now: date(2025, 3))
        #expect(months.count == 15) // 2024年の12ヶ月 + 2025年1〜3月
        #expect(months.first! == (2024, 1))
        #expect(months.last! == (2025, 3))
    }

    @Test func requiredMonthsは未来の開始年なら空() {
        let months = MonthMath.requiredMonths(startYear: 2030, now: date(2025, 3))
        #expect(months.isEmpty)
    }

    @Test func キャッシュが空なら全期間が1つの区間になる() {
        let required = MonthMath.requiredMonths(startYear: 2024, now: date(2024, 6))
        let spans = MonthMath.missingSpans(required: required, cachedKeys: [], now: date(2024, 6))
        #expect(spans == [MonthSpan(startYear: 2024, startMonth: 1, endYear: 2024, endMonth: 6)])
    }

    @Test func 全てキャッシュ済みなら今月だけクエリする() {
        let required = MonthMath.requiredMonths(startYear: 2024, now: date(2024, 6))
        let cached = Set(required.map { MonthlyStat.key(year: $0.year, month: $0.month) })
        let spans = MonthMath.missingSpans(required: required, cachedKeys: cached, now: date(2024, 6))
        #expect(spans == [MonthSpan(startYear: 2024, startMonth: 6, endYear: 2024, endMonth: 6)])
    }

    @Test func キャッシュにない月がまとまった区間になる() {
        let required = MonthMath.requiredMonths(startYear: 2024, now: date(2024, 6))
        // 3月と4月だけキャッシュ済み
        let cached: Set<String> = ["2024-03", "2024-04"]
        let spans = MonthMath.missingSpans(required: required, cachedKeys: cached, now: date(2024, 6))
        #expect(spans == [
            MonthSpan(startYear: 2024, startMonth: 1, endYear: 2024, endMonth: 2),
            MonthSpan(startYear: 2024, startMonth: 5, endYear: 2024, endMonth: 6),
        ])
    }
}

// MARK: - MonthlyStat

struct MonthlyStatTests {

    @Test func keyはゼロ埋めされる() {
        #expect(MonthlyStat.key(year: 2024, month: 3) == "2024-03")
        #expect(MonthlyStat(year: 2024, month: 12).key == "2024-12")
    }

    @Test func dailyAverageは日数で割る() {
        var stat = MonthlyStat(year: 2024, month: 1)
        #expect(stat.dailyAverage == nil)
        stat.sum = 300
        stat.dayCount = 30
        #expect(stat.dailyAverage == 10)
    }

    @Test func hasDataの判定() {
        var stat = MonthlyStat(year: 2024, month: 1)
        #expect(!stat.hasData)
        stat.average = 1
        #expect(stat.hasData)
    }

    @Test func 月の開始と終了() {
        let stat = MonthlyStat(year: 2024, month: 2)
        let calendar = Calendar.current
        #expect(calendar.component(.month, from: stat.startDate) == 2)
        #expect(calendar.component(.month, from: stat.endDate) == 3)
        #expect(stat.midDate > stat.startDate && stat.midDate < stat.endDate)
    }

    @Test func MonthSpanのendDateは終端月の翌月1日() {
        let span = MonthSpan(startYear: 2024, startMonth: 11, endYear: 2024, endMonth: 12)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: span.endDate)
        #expect(comps.year == 2025 && comps.month == 1 && comps.day == 1)
    }
}

// MARK: - StatsCache

struct StatsCacheTests {

    private func makeCache() -> (StatsCache, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("statsCache.json")
        return (StatsCache(fileURL: url), url)
    }

    @Test func 保存して読み出せる() async {
        let (cache, url) = makeCache()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var stat = MonthlyStat(year: 2024, month: 1)
        stat.sum = 100
        stat.dayCount = 10

        await cache.store([stat], for: "type", unit: "count")
        let loaded = await cache.stats(for: "type", unit: "count")
        #expect(loaded["2024-01"] == stat)

        // 別インスタンスでもファイルから読める
        let cache2 = StatsCache(fileURL: url)
        let loaded2 = await cache2.stats(for: "type", unit: "count")
        #expect(loaded2["2024-01"] == stat)
    }

    @Test func 単位が違えばキャッシュは使われない() async {
        let (cache, url) = makeCache()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var stat = MonthlyStat(year: 2024, month: 1)
        stat.average = 60
        await cache.store([stat], for: "type", unit: "count/min")

        let loaded = await cache.stats(for: "type", unit: "ms")
        #expect(loaded.isEmpty)
    }

    @Test func クリアで空になる() async {
        let (cache, url) = makeCache()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var stat = MonthlyStat(year: 2024, month: 1)
        stat.average = 1
        await cache.store([stat], for: "type", unit: "count")
        await cache.clear()

        let loaded = await cache.stats(for: "type", unit: "count")
        #expect(loaded.isEmpty)
        let summary = await cache.summary()
        #expect(summary.monthCount == 0)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}

// MARK: - ChartAnalysis

struct ChartAnalysisTests {

    private func points(_ values: [Double]) -> [DatedValue] {
        let calendar = Calendar.current
        let base = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        return values.enumerated().map { i, value in
            DatedValue(date: calendar.date(byAdding: .month, value: i, to: base)!, value: value)
        }
    }

    @Test func 移動平均は末尾ウィンドウで計算される() {
        let ma = ChartAnalysis.movingAverage(points([1, 2, 3, 4, 5]), window: 3)
        #expect(ma.map { $0.value } == [2, 3, 4])
    }

    @Test func 移動平均は点数不足なら空() {
        #expect(ChartAnalysis.movingAverage(points([1, 2]), window: 3).isEmpty)
    }

    @Test func 回帰直線の傾き() {
        let fit = ChartAnalysis.linearRegression(xs: [0, 1, 2, 3], ys: [10, 12, 14, 16])
        #expect(fit != nil)
        #expect(abs((fit?.slope ?? 0) - 2) < 1e-9)
        #expect(abs((fit?.intercept ?? 0) - 10) < 1e-9)
    }

    @Test func トレンドは月あたりの傾きを返す() {
        // 毎月+2ずつ増える系列
        let trend = ChartAnalysis.trendLine(points([10, 12, 14, 16]))
        #expect(trend != nil)
        if let trend {
            #expect(abs(trend.slopePerMonth - 2) < 0.1)
            #expect(trend.start.value < trend.end.value)
        }
    }

    @Test func 中央値とパーセンタイル() {
        #expect(ChartAnalysis.median([1, 2, 3, 4, 5]) == 3)
        #expect(ChartAnalysis.median([1, 2, 3, 4]) == 2.5)
        #expect(ChartAnalysis.percentile([1, 2, 3, 4, 5], 0) == 1)
        #expect(ChartAnalysis.percentile([1, 2, 3, 4, 5], 100) == 5)
        #expect(ChartAnalysis.percentile([], 50) == nil)
    }

    @Test func 標準偏差() {
        let sd = ChartAnalysis.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9])
        #expect(sd != nil)
        #expect(abs((sd ?? 0) - 2.138) < 0.01) // 標本標準偏差
        #expect(ChartAnalysis.standardDeviation([1]) == nil)
    }

    @Test func 相関係数() {
        // 完全な正の相関
        let r1 = ChartAnalysis.pearsonCorrelation(xs: [1, 2, 3, 4], ys: [2, 4, 6, 8])
        #expect(abs((r1 ?? 0) - 1) < 1e-9)
        // 完全な負の相関
        let r2 = ChartAnalysis.pearsonCorrelation(xs: [1, 2, 3, 4], ys: [8, 6, 4, 2])
        #expect(abs((r2 ?? 0) + 1) < 1e-9)
        // 分散ゼロはnil
        #expect(ChartAnalysis.pearsonCorrelation(xs: [1, 1, 1], ys: [1, 2, 3]) == nil)
        // 3点未満はnil
        #expect(ChartAnalysis.pearsonCorrelation(xs: [1, 2], ys: [1, 2]) == nil)
    }

    @Test func 相関ラベル() {
        #expect(ChartAnalysis.correlationLabel(0.8) == "強い正の相関")
        #expect(ChartAnalysis.correlationLabel(-0.5) == "中程度の負の相関")
        #expect(ChartAnalysis.correlationLabel(0.3) == "弱い正の相関")
        #expect(ChartAnalysis.correlationLabel(0.1) == "ほぼ相関なし")
    }

    @Test func 前年同月の値を見つける() {
        let calendar = Calendar.current
        let all = points(Array(1...24).map(Double.init)) // 2024/01〜2025/12
        let target = calendar.date(from: DateComponents(year: 2025, month: 3, day: 10))!
        // 2024/03 の値は 3
        #expect(ChartAnalysis.valueOneYearBefore(of: target, in: all) == 3)
        let early = calendar.date(from: DateComponents(year: 2024, month: 2, day: 10))!
        #expect(ChartAnalysis.valueOneYearBefore(of: early, in: all) == nil)
    }

    @Test func 前年同月比() {
        #expect(ChartAnalysis.yearOverYearChange(current: 110, previous: 100) == 10)
        #expect(ChartAnalysis.yearOverYearChange(current: 90, previous: 100) == -10)
        #expect(ChartAnalysis.yearOverYearChange(current: 1, previous: 0) == nil)
    }
}

// MARK: - 数値フォーマット

struct FormatValueTests {

    private let ja = Locale(identifier: "ja_JP")

    @Test func 整数はカンマ区切り() {
        #expect(formatValue(12345, "%.0f", locale: ja) == "12,345")
        #expect(formatValue(8500, "%.0f", locale: ja) == "8,500")
        #expect(formatValue(999, "%.0f", locale: ja) == "999")
    }

    @Test func 小数桁はフォーマットに従う() {
        #expect(formatValue(12345.678, "%.1f", locale: ja) == "12,345.7")
        #expect(formatValue(65.2, "%.2f", locale: ja) == "65.20")
        #expect(formatValue(1234.5, "%.0f", locale: ja) == "1,235")
    }
}

// MARK: - カタログ

struct HealthCatalogTests {

    @Test func 項目のタイプは重複しない() {
        let items = Health.buildItems()
        let ids = items.map { $0.type.rawValue }
        #expect(Set(ids).count == ids.count)
    }

    @Test func 全項目の単位がタイプと互換() {
        for item in Health.buildItems() {
            let quantityType = HKQuantityType.quantityType(forIdentifier: item.type)
            #expect(quantityType != nil, "存在しないタイプ: \(item.type.rawValue)")
            if let quantityType {
                #expect(quantityType.is(compatibleWith: item.sampleUnit),
                        "単位が不一致: \(item.title) (\(item.type.rawValue)) - \(item.sampleUnit.unitString)")
            }
        }
    }

    @Test func 累積タイプは棒グラフになる() {
        for item in Health.buildItems() where item.chart == .bar {
            let quantityType = HKQuantityType.quantityType(forIdentifier: item.type)!
            #expect(quantityType.aggregationStyle == .cumulative,
                    "棒グラフなのに累積型でない: \(item.title)")
        }
    }

    @Test func percent単位の表示倍率は100() {
        let items = Health.buildItems()
        let bodyFat = items.first { $0.type == .bodyFatPercentage }
        #expect(bodyFat?.displayMultiplier == 100)
        let bodyMass = items.first { $0.type == .bodyMass }
        #expect(bodyMass?.displayMultiplier == 1)
    }

    @Test func 血圧は特別扱い() {
        let items = Health.buildItems()
        #expect(items.first { $0.type == .bloodPressureSystolic }?.chart == .bloodPress)
        #expect(items.first { $0.type == .bloodPressureDiastolic }?.chart == .hidden)
    }

    @Test func 全カテゴリに項目がある() {
        let items = Health.buildItems()
        for category in HealthCategory.allCases {
            #expect(items.contains { $0.category == category }, "項目のないカテゴリ: \(category)")
        }
    }
}

// MARK: - 区間分割

struct SplitSpanTests {

    @Test func 短い区間はそのまま() {
        let span = MonthSpan(startYear: 2024, startMonth: 3, endYear: 2024, endMonth: 8)
        let result = MonthMath.splitSpan(span, maxMonths: 12)
        #expect(result == [span])
        #expect(MonthMath.monthCount(span) == 6)
    }

    @Test func 長い区間は12ヶ月ごとに分割() {
        let span = MonthSpan(startYear: 2014, startMonth: 1, endYear: 2016, endMonth: 6)
        let result = MonthMath.splitSpan(span, maxMonths: 12)
        #expect(result.count == 3)
        #expect(result[0] == MonthSpan(startYear: 2014, startMonth: 1, endYear: 2014, endMonth: 12))
        #expect(result[1] == MonthSpan(startYear: 2015, startMonth: 1, endYear: 2015, endMonth: 12))
        #expect(result[2] == MonthSpan(startYear: 2016, startMonth: 1, endYear: 2016, endMonth: 6))
        #expect(result.reduce(0) { $0 + MonthMath.monthCount($1) } == MonthMath.monthCount(span))
    }

    @Test func 年マタギも月数が保存される() {
        let span = MonthSpan(startYear: 2023, startMonth: 11, endYear: 2025, endMonth: 2)
        let result = MonthMath.splitSpan(span, maxMonths: 12)
        #expect(result.reduce(0) { $0 + MonthMath.monthCount($1) } == 16)
        // 分割区間は連続している
        for i in 1..<result.count {
            let prev = result[i - 1]
            let next = result[i]
            let expectedMonth = prev.endMonth == 12 ? 1 : prev.endMonth + 1
            let expectedYear = prev.endMonth == 12 ? prev.endYear + 1 : prev.endYear
            #expect(next.startYear == expectedYear && next.startMonth == expectedMonth)
        }
    }

    @Test func 運動量スコアはサンプル集計対象() {
        if #available(iOS 18.0, *) {
            #expect(HealthStatsService.isSampleQueryOnly(.workoutEffortScore))
            #expect(HealthStatsService.isSampleQueryOnly(.estimatedWorkoutEffortScore))
        }
        #expect(!HealthStatsService.isSampleQueryOnly(.stepCount))
    }
}
