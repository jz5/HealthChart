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
