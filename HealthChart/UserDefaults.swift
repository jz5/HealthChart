//
//  UserDefaults.swift
//  HealthChart
//
//  Created by jz5 on 2023/03/19.
//

import Foundation
import HealthKit

extension UserDefaults {

    func isVisible(for identifier: HKQuantityTypeIdentifier) -> Bool {
        if let enabled = object(forKey: identifier.rawValue) as? Bool {
            return enabled
        } else {
            return true
        }
    }

    func setVisibility(_ enabled: Bool, for identifier: HKQuantityTypeIdentifier) {
        set(enabled, forKey: identifier.rawValue)
    }
}

