//
//  EvenSharedStore.swift
//  Finance
//

import Foundation

enum EvenSharedStore {
    static let appGroupIdentifier = "group.com.lukas42.finance"
    static let storeFileName = "Finance.sqlite"
    static let migrationMarkerKey = "even.sharedStore.ready.v1"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    static var storeURL: URL? {
        containerURL?.appendingPathComponent(storeFileName)
    }

    static var isReady: Bool {
        sharedDefaults.bool(forKey: migrationMarkerKey)
    }

    static func markReady() {
        sharedDefaults.set(true, forKey: migrationMarkerKey)
    }
}
