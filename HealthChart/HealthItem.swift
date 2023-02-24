//
//  HealthItem.swift
//  HealthChart
//
//  Created by jz5 on 2023/02/23.
//

import SwiftUI
import Charts
import HealthKit

struct HealthItem : Identifiable {
    let id = UUID()
    let type: HKQuantityTypeIdentifier
    let image: String
    let title: String
    let color: Color
    let sampleValueTitle: String
    let sampleUnitText: String
    let sampleValueFormat: String
    let sampleUnit: HKUnit
}
