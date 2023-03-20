//
//  HealthItemVisibilitySettingsView.swift
//  HealthChart
//
//  Created by jz5 on 2023/03/19.
//

import SwiftUI

struct VisibilitySettingsView: View {
    @ObservedObject var health: Health

    init(health: Health) {
        self.health = health
    }

    var body: some View {
        List {
            ForEach(health.items.filter { $0.chart != .hidden }) { item in

                Toggle(isOn: Binding(
                    get: { item.isVisible },
                    set: { health.updateVisibility(for: item, to: $0) }
                    )) {
                    HStack {
                        Image(systemName: item.image)
                            .foregroundColor(item.color)
                        Text(item.title)
                            .foregroundColor(item.color)
                            .fontWeight(.semibold)
                            .truncationMode(.tail)
                            .lineLimit(1)
                    }
                }
            }
        }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("表示する項目")
    }
}

struct HealthItemVisibilitySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        VisibilitySettingsView(health: Health())
    }
}
