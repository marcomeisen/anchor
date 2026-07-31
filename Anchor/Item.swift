//
//  Item.swift
//  Anchor
//
//  Created by Marco Meisen on 31.07.26.
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
