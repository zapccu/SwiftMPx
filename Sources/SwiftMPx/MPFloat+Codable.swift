//
//  MPFloat+Codable.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 12.07.26.
//

import Foundation


//
// Extend MPFloat to support Codable protocol
//
extension MPFloat: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case value, precision
    }
    
    /// Encode MPFloat value
    /// - Parameter encoder: Encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.toString(), forKey: .value)
        try container.encode(self.precision, forKey: .precision)
    }
    
    /// Decode MPFloat value
    /// - Parameter decoder: Decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stringValue = try container.decode(String.self, forKey: .value)
        let precision   = try container.decode(Int.self, forKey: .precision)
        self.init(stringValue, precision: precision)
    }
    
}
