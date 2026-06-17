//
//  JSONEncoder+With.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation

extension JSONEncoder {
    func with(_ configure: (JSONEncoder) -> Void) -> JSONEncoder {
        configure(self)
        return self
    }
}
