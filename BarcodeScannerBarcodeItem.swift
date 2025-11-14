//
//  BarcodeItem.swift
//  BarcodeScanner
//

import Foundation
import SwiftUI

struct BarcodeItem: Identifiable, Codable {
    let id: UUID
    let value: String
    let type: String
    let timestamp: Date
    
    init(value: String, type: String) {
        self.id = UUID()
        self.value = value
        self.type = type
        self.timestamp = Date()
    }
}
