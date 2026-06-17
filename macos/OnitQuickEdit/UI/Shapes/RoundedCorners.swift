//
//  RoundedCorners.swift
//  Onit
//
//  Created by Kévin Naudin on 03/04/2025.
//

import SwiftUI

struct Corner: OptionSet {
    let rawValue: Int
    
    static let topLeft = Corner(rawValue: 1 << 0)
    static let topRight = Corner(rawValue: 1 << 1)
    static let bottomLeft = Corner(rawValue: 1 << 2)
    static let bottomRight = Corner(rawValue: 1 << 3)
    
    static let all: Corner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    static let left: Corner = [.topLeft, .bottomLeft]
    static let right: Corner = [.topRight, .bottomRight]
    static let top: Corner = [.topLeft, .topRight]
    static let bottom: Corner = [.bottomLeft, .bottomRight]
}
