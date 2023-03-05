//
//  AuthorizationView.swift
//  HealthChart
//
//  Created by jz5 on 2023/03/04.
//

import SwiftUI
import HealthKit

struct AuthorizationView: View {

    let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    @Binding var requested: Bool
    @State private var showAlert = false
    @State private var isLoading = false
    @ObservedObject var health = Health()
    
    var body: some View {
        Button {
            requestAuthorization()
        } label: {
            HStack {
                Image(systemName: "info.circle")
                Text("ヘルスケアデータの読み取り許可")
                if isLoading {
                    ProgressView()
                        .padding(.leading)
                        .background(.background)
                }
            }
        }
        .disabled(isLoading)
        .alert("読み取り許可の方法", isPresented: $showAlert) {
        } message: {
            Text("ヘルスケア」のデータを読み取ってチャートを作成し表示します。読み取りの許可・拒否は、「ヘルスケア」アプリの画面下にある「共有」から共有画面を開き、「App」の「ヘルスチャート」から行えます。")
        }
    }
    
    func requestAuthorization() {
        let types = health.items.map { HKObjectType.quantityType(forIdentifier: $0.type)! }
        let notDetermined = types.contains(where: {
            healthStore?.authorizationStatus(for: $0) == .notDetermined
        })
        if (notDetermined) {
            isLoading = true

            healthStore!.requestAuthorization(toShare: nil, read: Set(types)) { (success, error) in
                requested.toggle()
            }
        } else {
            showAlert = true
        }
    }
}
