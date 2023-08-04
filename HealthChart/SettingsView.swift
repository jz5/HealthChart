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

    var body: some View {
        Form {
            Section(header: Text("ヘルスケアデータ取得開始年")) {
                Stepper(value: $startYear, in: 1900...year) {
                    Text(verbatim: "\(startYear) 年")
                }
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
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
