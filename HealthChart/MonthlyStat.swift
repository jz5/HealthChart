//
//  MonthlyStat.swift
//  HealthChart
//

import Foundation

/// 1ヶ月分の集計値。確定した過去の月はキャッシュされる。
struct MonthlyStat: Codable, Equatable {
    let year: Int
    let month: Int

    /// 累積型: 日ごとの合計の総和
    var sum: Double = 0
    /// 累積型: データがあった日数
    var dayCount: Int = 0
    /// 離散型: 月間平均
    var average: Double?
    /// 離散型: 月間最小
    var minValue: Double?
    /// 離散型: 月間最大
    var maxValue: Double?

    var hasData: Bool {
        dayCount > 0 || average != nil || minValue != nil || maxValue != nil
    }

    /// 累積型: 1日あたりの平均
    var dailyAverage: Double? {
        dayCount > 0 ? sum / Double(dayCount) : nil
    }

    var key: String { Self.key(year: year, month: month) }

    static func key(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
    }

    /// グラフにプロットする月の中央の日時
    var midDate: Date {
        startDate.addingTimeInterval(endDate.timeIntervalSince(startDate) / 2)
    }
}

/// 年月の連続区間。キャッシュにない月をまとめて1クエリで取得するために使う。
struct MonthSpan: Equatable {
    var startYear: Int
    var startMonth: Int
    var endYear: Int
    var endMonth: Int

    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: startYear, month: startMonth, day: 1))!
    }

    /// 区間終端(終端月の翌月1日)
    var endDate: Date {
        let start = Calendar.current.date(from: DateComponents(year: endYear, month: endMonth, day: 1))!
        return Calendar.current.date(byAdding: .month, value: 1, to: start)!
    }
}

enum MonthMath {

    /// startYear 1月から今月までの (year, month) 一覧
    static func requiredMonths(startYear: Int, now: Date = Date()) -> [(year: Int, month: Int)] {
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        guard let curYear = comps.year, let curMonth = comps.month, startYear <= curYear else { return [] }

        var result: [(Int, Int)] = []
        for year in startYear...curYear {
            let last = (year == curYear) ? curMonth : 12
            for month in 1...last {
                result.append((year, month))
            }
        }
        return result
    }

    /// キャッシュにない月(と今月)をまとめた連続区間を返す。
    /// 今月はまだ値が変わるため、キャッシュされていても必ずクエリ対象に含める。
    static func missingSpans(required: [(year: Int, month: Int)],
                             cachedKeys: Set<String>,
                             now: Date = Date()) -> [MonthSpan] {
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        let currentKey = MonthlyStat.key(year: comps.year ?? 0, month: comps.month ?? 0)

        var spans: [MonthSpan] = []
        var current: MonthSpan?

        for (year, month) in required {
            let key = MonthlyStat.key(year: year, month: month)
            let needsQuery = !cachedKeys.contains(key) || key == currentKey

            if needsQuery {
                if var span = current {
                    span.endYear = year
                    span.endMonth = month
                    current = span
                } else {
                    current = MonthSpan(startYear: year, startMonth: month, endYear: year, endMonth: month)
                }
            } else if let span = current {
                spans.append(span)
                current = nil
            }
        }
        if let span = current {
            spans.append(span)
        }
        return spans
    }
}
