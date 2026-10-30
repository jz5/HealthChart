//
//  SettingsView.swift
//  HealthChart
//
//  Created by jz5 on 2023/03/04.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("startYear") private var startYear = 2014
    let year = Calendar.current.component(.year, from: Date())

    @State private var cacheMonthCount = 0
    @State private var cacheByteCount = 0
    @State private var showClearConfirm = false
    @State private var didClear = false

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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
