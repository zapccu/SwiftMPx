//
//  Conformances.swift
//  SwiftMPx
//
//  Standard protocol conformances of MPFloat and MPComplex
//

import Foundation

//
// MPFloat
//

extension MPFloat: Hashable, AdditiveArithmetic {

    /// Zero with default precision (required by AdditiveArithmetic)
    /// Intended for generic code. If the precision is known, use zero(precision:): in-place
    /// operators keep the precision of the left operand, so `var sum = MPFloat.zero; sum += x`
    /// rounds every result to the default precision.
    public static var zero: MPFloat {
        MPFloat(0, precision: MPFloat.defaultPrecision)
    }
    
    /// Zero with the specified precision
    public static func zero(precision: Int) -> MPFloat {
        MPFloat(0, precision: precision)
    }

    /// Hash value, consistent with ==
    /// Equal values have the same correctly rounded Double approximation, also if their precisions
    /// differ (1.0 with 53 bits == 1.0 with 256 bits). +0 and -0 are equal and have the same hash
    /// value (Double hashing normalizes zero). Values that only differ beyond Double precision
    /// collide, which is allowed.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(toDouble())
    }
}

//
// MPComplex
//

extension MPComplex: Hashable, AdditiveArithmetic {

    /// Zero with default precision (required by AdditiveArithmetic)
    /// Intended for generic code. If the precision is known, use zero(precision:), see MPFloat.zero.
    public static var zero: MPComplex {
        MPComplex(0.0, 0.0, precision: MPFloat.defaultPrecision)
    }
    
    /// Zero with the specified precision
    public static func zero(precision: Int) -> MPComplex {
        MPComplex(0.0, 0.0, precision: precision)
    }

    /// Hash value, consistent with ==
    public func hash(into hasher: inout Hasher) {
        hasher.combine(real)
        hasher.combine(imaginary)
    }
}
