//
//  StatsCache.swift
//  HealthChart
//

import Foundation

/// 確定した過去の月の集計値をJSONファイルに保存するキャッシュ。
/// ヘルスケアの過去データを編集した場合は設定画面からクリアする。
actor StatsCache {

    struct TypeCache: Codable {
        /// 集計時の単位。単位が変わったらキャッシュは使わない。
        var unit: String
        var months: [String: MonthlyStat]
    }

    struct CacheFile: Codable {
        var version: Int
        var types: [String: TypeCache]
    }

    static let currentVersion = 1

    private var file: CacheFile?
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = support.appendingPathComponent("HealthChart", isDirectory: true)
                .appendingPathComponent("statsCache.json")
        }
    }

    /// 指定タイプのキャッシュ済み月次集計(単位が一致する場合のみ)
    func stats(for typeIdentifier: String, unit: String) -> [String: MonthlyStat] {
        loadIfNeeded()
        guard let typeCache = file?.types[typeIdentifier], typeCache.unit == unit else {
            return [:]
        }
        return typeCache.months
    }

    /// 確定済みの月次集計を保存する(今月を渡さないのは呼び出し側の責任)
    func store(_ stats: [MonthlyStat], for typeIdentifier: String, unit: String) {
        guard !stats.isEmpty else { return }
        loadIfNeeded()

        var f = file ?? CacheFile(version: Self.currentVersion, types: [:])
        var typeCache = f.types[typeIdentifier] ?? TypeCache(unit: unit, months: [:])
        if typeCache.unit != unit {
            typeCache = TypeCache(unit: unit, months: [:])
        }
        for stat in stats {
            typeCache.months[stat.key] = stat
        }
        f.types[typeIdentifier] = typeCache
        file = f
        save()
    }

    func clear() {
        file = CacheFile(version: Self.currentVersion, types: [:])
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// キャッシュ済みの (タイプ数, 月数, バイト数)
    func summary() -> (typeCount: Int, monthCount: Int, byteCount: Int) {
        loadIfNeeded()
        let types = file?.types ?? [:]
        let monthCount = types.values.reduce(0) { $0 + $1.months.count }
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = (attributes?[.size] as? Int) ?? 0
        return (types.count, monthCount, size)
    }

    private func loadIfNeeded() {
        guard file == nil else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(CacheFile.self, from: data),
              decoded.version == Self.currentVersion else {
            file = CacheFile(version: Self.currentVersion, types: [:])
            return
        }
        file = decoded
    }

    private func save() {
        guard let file else { return }
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(file)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // キャッシュ保存失敗は無視(次回また取得するだけ)
        }
    }
}
