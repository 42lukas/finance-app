//
//  ArchiveFilter.swift
//  Finance
//

import Foundation

enum ArchiveFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case completed = "Erledigt"
    case open = "Offen"

    var id: String { rawValue }

    func includes(_ item: Item) -> Bool {
        switch self {
        case .all:
            return true
        case .completed:
            return item.openAmount <= 0.005
        case .open:
            return item.openAmount > 0.005
        }
    }
}
