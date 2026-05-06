//
//  Item.swift
//  Masjidly - Official Masjid Prayer Times
//
//  Created by Mikhail on 06/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
