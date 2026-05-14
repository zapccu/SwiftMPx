//
//  MPComplex.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

import CMPFR


public struct MPComplex : ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, CustomStringConvertible, Sendable {
    
    public var real: MPFloat
    public var imaginary: MPFloat
    
    // Precision (default is 128 bit)
    public let precision: Int
    
    /// Initialize MPComplex
    init(precision: Int = 128) {
        self.precision = precision
        self.real = MPFloat(precision: precision)
        self.imaginary = MPFloat(precision: precision)
    }
    
    public init(floatLiteral value: Double) {
        self.precision = 64
        self.real = MPFloat(value, precision: 64)
        self.imaginary = MPFloat(0, precision: 64)
    }
    
    public init(integerLiteral value: Int) {
        self.precision = 64
        self.real = MPFloat(value, precision: 64)
        self.imaginary = MPFloat(0, precision: 64)
    }
    
    /// Initialize MPComplex with Double values
    public init(_ real: Double, _ imaginary: Double, precision: Int = 128) {
        self.precision = precision
        self.real = MPFloat(real, precision: precision)
        self.imaginary = MPFloat(imaginary, precision: precision)
    }
    
    /// Initialize MPComplex with String values
    public init(_ real: String, _ imaginary: String = "0", precision: Int = 128) {
        self.precision = precision
        self.real = MPFloat(real, precision: precision)
        self.imaginary = MPFloat(imaginary, precision: precision)
    }
    
    /// Initialize MPComplex with MPFloat values
    public init(_ real: MPFloat, _ imaginary: MPFloat, precision: Int = -1) {
        let p = precision == -1 ? Swift.max(real.precision, imaginary.precision) : precision
        self.precision = p
        self.real = MPFloat(real, precision: p)
        self.imaginary = MPFloat(imaginary, precision: p)
    }
    
    public init(_ real: MPFloat, _ imaginary: MPFloat) {
        self.init(real, imaginary, precision: Swift.max(real.precision, imaginary.precision))
    }
    
    public static let zero = MPComplex(0.0, 0.0, precision: 64)
    
    /// Make MPComplex printable
    public var description: String {
        return "\(self.real.toString()) + \(self.imaginary.toString())i"
    }
    
    public var length: MPFloat {
        sqrt(norm(self))
    }
    
    public var lengthSquared: MPFloat {
        norm(self)
    }

    /// Return minimum of real and imaginary part
    public var min: MPFloat {
        SwiftMPx.min(self.real, self.imaginary)
    }

    /// Return minimum of real and imaginary part
    public var max: MPFloat {
        SwiftMPx.max(self.real, self.imaginary)
    }
    
    /// Negate MPComplex
    public static prefix func - (rhs: MPComplex) -> MPComplex {
        var result = rhs
        mpfr_neg(&result.real.mutableValue, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_neg(&result.imaginary.mutableValue, &rhs.imaginary.storage.value, MPFR_RNDN)
        return result
    }
    
    //
    // Addition
    //

    /// Addition, return new value
    public static func + (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        mpfr_add(&result.real.mutableValue, &lhs.real.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_add(&result.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Addition, in-place
    public static func += (lhs: inout MPComplex, rhs: MPComplex) {
        mpfr_add(&lhs.real.mutableValue, &lhs.real.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_add(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
    }
    
    //
    // Subtraction
    //
    
    /// Subtraction, return new value
    public static func - (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        mpfr_sub(&result.real.mutableValue, &lhs.real.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_sub(&result.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Subtraction, in-place
    public static func -= (lhs: inout MPComplex, rhs: MPComplex) {
        mpfr_sub(&lhs.real.mutableValue, &lhs.real.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_sub(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
    }
    
    //
    // Multiplication
    //

    /// Multiplication (MPComplex, MPComplex), return new value
    public static func * (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        var tmp = MPFloat(precision: lhs.precision)
        
        // result.real = lhs.real * rhs.real - lhs.imaginary * rhs.imaginary
        mpfr_mul(&result.real.mutableValue,      &lhs.real.storage.value, &rhs.real.storage.value,           MPFR_RNDN)
        mpfr_mul(&tmp.mutableValue,              &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_sub(&result.real.mutableValue,      &result.real.storage.value, &tmp.storage.value,             MPFR_RNDN)

        // result.imaginary = lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        mpfr_mul(&result.imaginary.mutableValue, &lhs.real.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_mul(&tmp.mutableValue,              &lhs.imaginary.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_add(&result.imaginary.mutableValue, &result.imaginary.storage.value, &tmp.storage.value,   MPFR_RNDN)

        return result
    }
    
    /// Multiplication (MPComplex, MPFloat), return new value
    public static func * (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        mpfr_mul(&result.real.mutableValue, &lhs.real.storage.value, &rhs.storage.value, MPFR_RNDN)
        mpfr_mul(&result.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Multiplication (MPFloat, MPComplex), return new value
    public static func * (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: rhs.precision)
        mpfr_mul(&result.real.mutableValue, &lhs.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_mul(&result.imaginary.mutableValue, &lhs.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Multiplication (in place)
    public static func *= (lhs: inout MPComplex, rhs: MPComplex) {
        var tmp1 = MPFloat(precision: lhs.precision)
        var tmp2 = MPFloat(precision: lhs.precision)
        var tmp3 = lhs.real
        
        // result.real = lhs.real * rhs.real - lhs.imaginary * rhs.imaginary
        mpfr_mul(&tmp1.mutableValue, &lhs.real.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_mul(&tmp2.mutableValue, &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_sub(&lhs.real.mutableValue, &tmp1.storage.value, &tmp2.storage.value, MPFR_RNDN)

        // result.imaginary = lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        mpfr_mul(&tmp1.mutableValue, &tmp3.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_mul(&tmp2.mutableValue, &lhs.imaginary.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_add(&lhs.imaginary.mutableValue, &tmp1.storage.value, &tmp2.storage.value, MPFR_RNDN)
    }
    
    /// Multiplication (in place)
    public static func *= (lhs: inout MPComplex, rhs: MPFloat) {
        mpfr_mul(&lhs.real.mutableValue, &lhs.real.storage.value, &rhs.storage.value, MPFR_RNDN)
        mpfr_mul(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.storage.value, MPFR_RNDN)
    }

    //
    // Division
    //
    
    /// Division: MPComplex, MPComplex
    public static func / (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        var tmp1 = MPFloat(precision: lhs.precision)
        var tmp2 = MPFloat(precision: lhs.precision)

        // tmp1 = rhs.real * rhs.real + rhs.imag * rhs.imag
        mpfr_sqr(&tmp1.mutableValue, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_sqr(&tmp2.mutableValue, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_add(&tmp1.mutableValue, &tmp1.storage.value, &tmp2.storage.value, MPFR_RNDN)
        
        // result.real = (lhs.real * rhs.real + lhs.imag * rhs.imag) / tmp1
        mpfr_mul(&result.real.mutableValue, &lhs.real.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_mul(&tmp2.mutableValue, &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_add(&result.real.mutableValue, &result.real.storage.value, &tmp2.storage.value, MPFR_RNDN)
        mpfr_div(&result.real.mutableValue, &result.real.storage.value, &tmp1.storage.value, MPFR_RNDN)
        
        // result.imag = (rhs.real * lhs.imag - lhs.real * rhs.imag) / tmp1
        mpfr_mul(&result.imaginary.mutableValue, &rhs.real.storage.value, &lhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_mul(&tmp2.mutableValue, &lhs.real.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_sub(&result.imaginary.mutableValue, &result.imaginary.storage.value, &tmp2.storage.value, MPFR_RNDN)
        mpfr_div(&result.imaginary.mutableValue, &result.imaginary.storage.value, &tmp1.storage.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division: MPComplex, MPFloat
    public static func / (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        var tmp = MPFloat(precision: lhs.precision)

        mpfr_ui_div(&tmp.mutableValue, 1, &rhs.storage.value, MPFR_RNDN)

        // result.real = lhs.real * tmp
        mpfr_mul(&result.real.mutableValue, &lhs.real.storage.value, &tmp.storage.value, MPFR_RNDN)
        
        // result.imaginary = lhs.imaginary * tmp
        mpfr_mul(&result.imaginary.mutableValue, &lhs.imaginary.storage.value, &tmp.storage.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division: MPFloat, MPComplex
    public static func / (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: rhs.precision)
        var tmp = MPFloat(precision: rhs.precision)

        mpfr_ui_div(&tmp.mutableValue, 1, &lhs.storage.value, MPFR_RNDN)

        // result.real = rhs.real * tmp1
        mpfr_mul(&result.real.mutableValue, &rhs.real.storage.value, &tmp.storage.value, MPFR_RNDN)
        
        // result.imaginary = rhs.imaginary * tmp1
        mpfr_mul(&result.imaginary.mutableValue, &rhs.imaginary.storage.value, &tmp.storage.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division, in-place
    public static func /= (lhs: inout MPComplex, rhs: MPComplex) {
        var tmp1 = MPFloat(precision: lhs.precision)
        var tmp2 = MPFloat(precision: lhs.precision)
        var originalReal = lhs.real  // COW: keine Kopie bis tmp1/tmp2 geschrieben werden

        // tmp1 = rhs.real² + rhs.imag²
        mpfr_sqr(&tmp1.mutableValue, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_sqr(&tmp2.mutableValue, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_add(&tmp1.mutableValue, &tmp1.storage.value, &tmp2.storage.value, MPFR_RNDN)

        // result.real = (lhs.real * rhs.real + lhs.imag * rhs.imag) / tmp1
        mpfr_mul(&lhs.real.mutableValue, &lhs.real.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_mul(&tmp2.mutableValue, &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_add(&lhs.real.mutableValue, &lhs.real.storage.value, &tmp2.storage.value, MPFR_RNDN)
        mpfr_div(&lhs.real.mutableValue, &lhs.real.storage.value, &tmp1.storage.value, MPFR_RNDN)

        // result.imag = (rhs.real * lhs.imag - originalReal * rhs.imag) / tmp1
        mpfr_mul(&lhs.imaginary.mutableValue, &rhs.real.storage.value, &lhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_mul(&tmp2.mutableValue, &originalReal.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_sub(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &tmp2.storage.value, MPFR_RNDN)
        mpfr_div(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &tmp1.storage.value, MPFR_RNDN)
    }
    
    /// Division (in place)
    public static func /= (lhs: inout MPComplex, rhs: MPFloat) {
        var tmp = MPFloat(precision: lhs.precision)
        
        mpfr_ui_div(&tmp.mutableValue, 1, &rhs.storage.value, MPFR_RNDN)

        // result.real = lhs.real * tmp1
        mpfr_mul(&lhs.real.mutableValue, &lhs.real.storage.value, &tmp.storage.value, MPFR_RNDN)
        
        // result.imaginary = lhs.imaginary * tmp1
        mpfr_mul(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &tmp.storage.value, MPFR_RNDN)
    }
    
    //
    // Comparision
    //
    
    public static func == (lhs: MPComplex, rhs: MPComplex) -> Bool {
        return lhs.real == rhs.real && lhs.imaginary == rhs.imaginary
    }
    
}

//
// Mathematic functions
//

/// Square
public func square(_ value: MPComplex) -> MPComplex {
    var result = MPComplex(precision: value.precision)
    var tmp1 = MPFloat(precision: value.precision)
    var tmp2 = MPFloat(precision: value.precision)

    mpfr_sqr(&tmp1.mutableValue, &value.real.storage.value, MPFR_RNDN)
    mpfr_sqr(&tmp2.mutableValue, &value.imaginary.storage.value, MPFR_RNDN)
    mpfr_sub(&result.real.mutableValue, &tmp1.storage.value, &tmp2.storage.value, MPFR_RNDN)
    
    mpfr_mul_ui(&tmp1.mutableValue, &value.real.storage.value, 2, MPFR_RNDN)
    mpfr_mul(&result.imaginary.mutableValue, &tmp1.storage.value, &value.imaginary.storage.value, MPFR_RNDN)
    
    return result
}

/// Norm / magnitude
public func norm(_ value: MPComplex) -> MPFloat {
    var result = MPFloat(precision: value.precision)
    var tmp = MPFloat(precision: value.precision)

    mpfr_sqr(&result.mutableValue, &value.real.storage.value, MPFR_RNDN)
    mpfr_sqr(&tmp.mutableValue, &value.imaginary.storage.value, MPFR_RNDN)
    mpfr_add(&result.mutableValue, &result.storage.value, &tmp.storage.value, MPFR_RNDN)
    
    return result
}

/// Absolute value
public func abs(_ value: MPComplex) -> MPFloat {
    var result = MPFloat(precision: value.precision)
    var tmp = MPFloat(precision: value.precision)

    mpfr_sqr(&result.mutableValue, &value.real.storage.value, MPFR_RNDN)
    mpfr_sqr(&tmp.mutableValue, &value.imaginary.storage.value, MPFR_RNDN)
    mpfr_add(&result.mutableValue, &result.storage.value, &tmp.storage.value, MPFR_RNDN)
    mpfr_sqrt(&result.mutableValue, &result.storage.value, MPFR_RNDN)
    
    return result
}

