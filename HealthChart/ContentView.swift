//
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

    @ObservedObject var health = Health.shared
    @ObservedObject var favorites = Favorites.shared
    @ObservedObject var comparisonPairs = ComparisonPairs.shared
    @ObservedObject var availability = DataAvailability.shared
    @Environment(\.scenePhase) private var scenePhase

    private var favoriteItems: [HealthItem] {
        favorites.types.compactMap { raw in
            health.items.first { $0.type.rawValue == raw && $0.chart != .hidden }
        }
    }

    var body: some View {
        if !isHealthAvailable {
            Text("この端末はサポートしていません")

        } else {

            NavigationStack {
                List {
                    if !favoriteItems.isEmpty {
                        Section("お気に入り") {
                            ForEach(favoriteItems) { item in
                                itemRow(item)
                            }
                        }
                    }
                    Section("分析") {
                        NavigationLink {
                            ComparisonChartView()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundColor(.teal)
                                Text("2項目の比較")
                                    .foregroundColor(.teal)
                                    .fontWeight(.semibold)
                            }
                        }
                        ForEach(comparisonPairs.pairs, id: \.self) { key in
                            if let (itemA, itemB) = pairItems(key) {
                                NavigationLink {
                                    ComparisonChartView(presetA: itemA.type.rawValue,
                                                        presetB: itemB.type.rawValue)
                                } label: {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                        Text("\(itemA.title) × \(itemB.title)")
                                            .foregroundColor(.teal)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        comparisonPairs.remove(key)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }
                    ForEach(HealthCategory.allCases) { category in
                        let items = health.items.filter { $0.category == category && $0.chart != .hidden }
                        if !items.isEmpty {
                            Section(category.title) {
                                ForEach(items) { item in
                                    itemRow(item)
                                }
                            }
                        }
                    }
                    Section {
                    } footer: {
                        Text("薄く表示されている項目には、データがないか読み取りが許可されていません。「ヘルスケア」アプリで許可やデータを追加したあとは、リストを下に引っ張ると再チェックできます。")
                    }
                }
                .navigationTitle("ヘルスチャート")
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    await availability.refresh(items: health.items)
                }
                .refreshable {
                    await availability.refresh(items: health.items, force: true)
                }
                .onChange(of: scenePhase) {
                    // 「ヘルスケア」アプリで許可を変えて戻ってきた場合に反映する
                    if scenePhase == .active {
                        Task { await availability.refresh(items: health.items) }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("設定")
                            }
                        }
                    }
                }
            }
        }
    }

    /// "typeA|typeB" キーから2項目を引く。どちらかが現OSにない場合はnil。
    private func pairItems(_ key: String) -> (HealthItem, HealthItem)? {
        let raws = key.split(separator: "|").map(String.init)
        guard raws.count == 2,
              let a = health.items.first(where: { $0.type.rawValue == raws[0] }),
              let b = health.items.first(where: { $0.type.rawValue == raws[1] }) else { return nil }
        return (a, b)
    }

    private func itemRow(_ item: HealthItem) -> some View {
        NavigationLink {
            chartView(item: item)
        } label: {
            HStack {
                Image(systemName: item.image)
                    .foregroundColor(item.color)
                Text(item.title)
                    .foregroundColor(item.color)
                    .fontWeight(.semibold)
            }
            // データなし(読み取り不許可を含む)は薄く表示。あとから読める場合があるので
            // 無効化はせず、タップはできるままにする
            .opacity(availability.hasData(item) == false ? 0.4 : 1)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                favorites.toggle(item)
            } label: {
                Image(systemName: favorites.contains(item) ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
    }

    private func chartView(item: HealthItem) -> some View {
        Group {
            switch item.chart {
            case .bar:
                BarChartView(health: item)
            case .line:
                LineChartView(health: item)
            case .bloodPress:
                BloodPressureChartView(health: item)
            default:
                RangeChartView(health: item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FavoriteButton(item: item)
            }
        }
    }
}

/// お気に入りの追加・解除ボタン。Favoritesを直接観測して星の表示を更新する。
struct FavoriteButton: View {
    @ObservedObject var favorites = Favorites.shared
    let item: HealthItem

    var body: some View {
        Button {
            favorites.toggle(item)
        } label: {
            Image(systemName: favorites.contains(item) ? "star.fill" : "star")
                .foregroundColor(.yellow)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
