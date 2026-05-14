//
//  MPFloat.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

import CMPFR

//
// Floating point type with variable precision
//

public struct MPFloat: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Comparable, CustomStringConvertible, Sendable {

    //
    // Internal storage
    //
    
    internal final class Storage: @unchecked Sendable {
        var value: mpfr_t
        
        init(precision: Int) {
            value = mpfr_t()
            mpfr_init2(&value, precision)
        }
        
        init(copying other: Storage) {
            value = mpfr_t()
            mpfr_init2(&value, mpfr_get_prec(&other.value))
            mpfr_set(&value, &other.value, MPFR_RNDN)
        }
        
        deinit {
            mpfr_clear(&value)
        }
    }
    
    internal var storage: Storage
    
    //
    // COW (Copy On Write) access
    //
    
    /// Read access, never a copy
    public var value: mpfr_t {
        _read { yield storage.value }
    }
    
    /// Write access – copy if necessary
    internal var mutableValue: mpfr_t {
        _read { yield storage.value }
        mutating _modify {
            if !isKnownUniquelyReferenced(&storage) {
                storage = Storage(copying: storage)
            }
            yield &storage.value
        }
    }
    
    /// Return precision
    public var precision: Int {
        mpfr_get_prec(&storage.value)
    }
    
    /// Return MPFloat value as String
    public var description: String {
        return self.toString()
    }

    //
    // Initializers
    //
    
    /// Initialize empty value
    public init(precision: Int = 128) {
        storage = Storage(precision: precision)
    }
    
    /// Initialize by assigning Double value
    public init(floatLiteral value: Double) {
        storage = Storage(precision: 64)
        mpfr_set_d(&storage.value, value, MPFR_RNDN)
    }
    
    /// Initialize by assigning Int value
    public init(integerLiteral value: Int) {
        storage = Storage(precision: 64)
        mpfr_set_si(&storage.value, value, MPFR_RNDN)
    }
    
    /// Initialize a value with a String
    public init(_ sval: String, precision: Int = 128) {
        storage = Storage(precision: precision)
        mpfr_set_str(&mutableValue, sval, 10, MPFR_RNDN)
    }
    
    /// Initialize value with a Double
    public init(_ dval: Double, precision: Int = 128) {
        storage = Storage(precision: precision)
        mpfr_set_d(&mutableValue, dval, MPFR_RNDN)
    }
    
    /// Initialize value with an Int
    public init(_ ival: Int, precision: Int = 128) {
        storage = Storage(precision: precision)
        mpfr_set_d(&mutableValue, Double(ival), MPFR_RNDN)
    }
    
    /// Initialize value with a MPFloat with precision conversion
    public init(_ other: MPFloat, precision: Int) {
        storage = Storage(precision: precision)
        mpfr_set(&storage.value, &other.storage.value, MPFR_RNDN)
    }

    //
    // Conversion functions
    //
    
    /// Convert value to Double
    public func toDouble() -> Double {
        return mpfr_get_d(&self.storage.value, MPFR_RNDN)
    }

    /// Convert value to String
    public func toString(digits: Int = 32) -> String {
        var exp: mpfr_exp_t = 0
        
        // MPFR returns digits without decimal point and exponent separately
        guard let cStr = mpfr_get_str(nil, &exp, 10, digits, &self.storage.value, MPFR_RNDN) else {
            return "NaN"
        }
        
        var rawDigits = String(cString: cStr)
        mpfr_free_str(cStr)
        
        if rawDigits.isEmpty || rawDigits == "0" { return "0" }
        
        // Extract sign
        let isNegative = rawDigits.hasPrefix("-")
        if isNegative { rawDigits.removeFirst() }
        
        var result = isNegative ? "-" : ""
        
        if exp > 0 && exp <= rawDigits.count {
            // Case 1: "123.45"
            let dotIndex = Int(exp)
            result += rawDigits.prefix(dotIndex)
            let suffix = rawDigits.dropFirst(dotIndex)
            if !suffix.isEmpty {
                result += "." + suffix
            }
        } else if exp > 0 {
            // Case 2: "1234500"
            result += rawDigits
            result += String(repeating: "0", count: Int(exp) - rawDigits.count)
        } else {
            // Case 3: Very small number "0.000123"
            result += "0."
            result += String(repeating: "0", count: abs(Int(exp)))
            result += rawDigits
        }
        
        // Trim zeroes
        if result.contains(".") {
            while result.last == "0" { result.removeLast() }
            if result.last == "." { result.removeLast() }
        }
        
        return result
    }
    
    //
    // Unary operations
    //
    
    /// Negate MPFloat
    public static prefix func - (rhs: MPFloat) -> MPFloat {
        var result = rhs
        mpfr_neg(&result.mutableValue, &result.storage.value, MPFR_RNDN)
        return result
    }
    
    //
    // Addition
    //
    
    /// Addition, return new value (additional memory needed)
    public static func + (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        var result = MPFloat(precision: lhs.precision)
        mpfr_add(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Addition (in place)
    public static func += (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_add(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }
    
    //
    // Subtraction
    //
    
    /// Subtraction, return new value (additional memory needed)
    public static func - (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        var result = MPFloat(precision: lhs.precision)
        mpfr_sub(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Subtraction (in place)
    public static func -= (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_sub(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }

    //
    // Multiplication
    //
    
    /// Multiplication: MPFloat with MPFloat
    public static func * (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        var result = MPFloat(precision: lhs.precision)
        mpfr_mul(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Inplace multiplication with MPFloat
    public static func *= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_mul(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }

    //
    // Division
    //
    
    /// Divison: MPFloat by MPFloat
    public static func / (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        var result = MPFloat(precision: lhs.precision)
        mpfr_div(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Division: in-place by MPFloat
    public static func /= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_div(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }
    
    //
    // Comparision
    //
    
    public static func == (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) == 0
    }

    public static func != (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) != 0
    }
    
    public static func < (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) < 0
    }
    
    public static func <= (lhs: MPFloat, rhs: MPFloat) -> Bool {
        let r = mpfr_cmp(&lhs.storage.value, &rhs.storage.value)
        return r <= 0
    }

    public static func > (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) > 0
    }
    
    public static func >= (lhs: MPFloat, rhs: MPFloat) -> Bool {
        let r = mpfr_cmp(&lhs.storage.value, &rhs.storage.value)
        return r >= 0
    }
    
    //
    // Constants
    //

    /// Return PI with specified precision
    public static func PI(precision: Int = 128) -> MPFloat {
        var result = MPFloat(precision: precision)
        mpfr_const_pi(&result.storage.value, MPFR_RNDN)
        return result
    }

    /// Return ln(2) with specified precision
    public static func LOG2(precision: Int = 128) -> MPFloat {
        var result = MPFloat(precision: precision)
        mpfr_const_log2(&result.storage.value, MPFR_RNDN)
        return result
    }

}

//
// Min/Max
//

/// Return maximum of two values
/// - Parameters:
///   - lhs: Value 1
///   - rhs: Value 2
/// - Returns: Maximum of lhs, rhs
public func max(_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
    if mpfr_cmp(&lhs.storage.value, &rhs.storage.value) > 0 {
        var result = MPFloat(precision: lhs.precision)
        mpfr_set(&result.storage.value, &lhs.storage.value, MPFR_RNDN)
        return result
    }
    else {
        var result = MPFloat(precision: rhs.precision)
        mpfr_set(&result.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
}

/// Return minimum of two values
/// - Parameters:
///   - lhs: Value 1
///   - rhs: Value 2
/// - Returns: Minimum of lhs, rhs
public func min(_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
    if mpfr_cmp(&lhs.storage.value, &rhs.storage.value) < 0 {
        var result = MPFloat(precision: lhs.precision)
        mpfr_set(&result.storage.value, &lhs.storage.value, MPFR_RNDN)
        return result
    }
    else {
        var result = MPFloat(precision: rhs.precision)
        mpfr_set(&result.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
}

//
// Mathematic functions
//

public func fmod(_ x: MPFloat, _ y: MPFloat) -> MPFloat {
    var result = MPFloat(precision: x.precision)
    mpfr_fmod(&result.storage.value, &x.storage.value, &y.storage.value, MPFR_RNDN)
    return result
}

/// Square root, return new value
public func sqrt(_ x: MPFloat) -> MPFloat {
    var result = MPFloat(precision: x.precision)
    mpfr_sqrt(&result.storage.value, &x.storage.value, MPFR_RNDN)
    return result
}

/// Square, return new value
public func square(_ x: MPFloat) -> MPFloat {
    var result = MPFloat(precision: x.precision)
    mpfr_sqr(&result.storage.value, &x.storage.value, MPFR_RNDN)
    return result
}

/// Power
public func pow(_ x: MPFloat, _ y: MPFloat) -> MPFloat {
    var result = MPFloat(precision: x.precision)
    mpfr_pow(&result.storage.value, &x.storage.value, &y.storage.value, MPFR_RNDN)
    return result
}

/// Logarithm, return new value
public func log(_ x: MPFloat) -> MPFloat {
    var result = MPFloat(precision: x.precision)
    mpfr_log(&result.storage.value, &x.storage.value, MPFR_RNDN)
    return result
}

/// Logarithm with base 2
public func log2(_ x: MPFloat) -> MPFloat {
    var result = MPFloat(precision: x.precision)
    mpfr_log2(&result.storage.value, &x.storage.value, MPFR_RNDN)
    return result
}

/// Exponential function
public func exp(_ x: MPFloat) -> MPFloat {
    var result = MPFloat(precision: x.precision)
    mpfr_exp(&result.storage.value, &x.storage.value, MPFR_RNDN)
    return result
}

extension Double {
    
    /// Convert MPFloat to Double
    init(_ mpf: MPFloat) {
        self = mpf.toDouble()
    }
    
}


