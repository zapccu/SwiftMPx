//
//  MPFloat.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

import Foundation
import CMPFR


public enum FloatValue {
    case dp(v: Double)
    case ap(v: MPFloat)
}

//
// Floating point type with variable precision
//

public struct MPFloat: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Comparable, CustomStringConvertible, Sendable {

    //
    // Class for internal storage
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
    
    // Internal storage
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
    
    /// Calculate required precision.
    ///
    /// - Parameters:
    ///   - real:        Base value for precision estimation. Decimal string (i.e. "1.5e-12").
    ///   - scale:       Scaling factor, default = 1 (no scaling)
    ///   - safetyBits:  Additional bits as safety buffer, default = 8
    /// - Returns:       Tuple (isDbl: Bool, precision: Int, isError: Bool)
    public static func getPrecision(real: String, scale: Int = 1, safetyBits: Int = 8) -> (isDbl: Bool, precision: Int)? {

        /// Parse exponent of floating point string
        func parseExponent(_ string: String) -> Int? {
            let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()
            
            // Try Double parsing
            if let value = Double(trimmed), value.isFinite, value != 0 {
                return Int(floor(Foundation.log10(Swift.abs(value))))
            }
            
            // Underflow/Overflow: Extract exponent from string
            // Format: [±][digits][.digits]e[±]exponent
            if let eIdx = trimmed.firstIndex(of: "e") {
                let expString = String(trimmed[trimmed.index(after: eIdx)...])
                return Int(expString)
            }
            
            return nil
        }
        
        let s: Double = Swift.max(Double(scale), 1.0)

        if var e = parseExponent(real) {
            // Scaled exponent: real / scaling
            // log10(real / scale) = log10(real) - log10(scale)
            // log10(1) = 0 => No scaling
            e -= Int(floor(Foundation.log10(s)))
            
            // bits = ceil(-log2(10^exp)) = ceil(-exp * log2(10))
            // log2_10 = 3.32193
            let log2_10: Double = Foundation.log2(10.0)
            let rawBits = Int(ceil(-Double(e) * log2_10))
            let totalBits = Swift.max(rawBits + safetyBits, 53)
            let doubleIsSufficient = rawBits <= (53 - safetyBits)
            
            return (doubleIsSufficient, totalBits)
        }
        
        return nil
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
    /// - Parameters:
    ///   - sval: A number as a string
    ///   - precision: Required precision / number of bits. -1 = detect precision
    public init(_ sval: String, precision: Int = -1) {
        var p: Int
        if precision <= 0 {
            if let precisionRequirements = Self.getPrecision(real: sval, safetyBits: 8) {
                p = precisionRequirements.precision
            }
            else {
                p = 128
            }
        }
        else {
            p = precision
        }
        storage = Storage(precision: p)
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
    /// - Parameter digits: Number of decimal digits, default = 32
    /// - Returns: Value as string
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
            result += String(repeating: "0", count: Swift.abs(Int(exp)))
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
    
    /// Addition: MPFloat + MPFloat
    public static func + (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_add(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Addition: MPFloat + Double
    public static func + (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_add_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Addition: Double + MPFloat
    public static func + (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rhs.precision)
        mpfr_add_d(&result.storage.value, &rhs.storage.value, lhs, MPFR_RNDN)
        return result
    }
    
    /// Addition (in place): MPFloat += MPFloat
    public static func += (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_add(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }
    
    /// Addition (in place): MPFloat += Double
    public static func += (lhs: inout MPFloat, rhs: Double) {
        mpfr_add_d(&lhs.mutableValue, &lhs.storage.value, rhs, MPFR_RNDN)
    }
    
    //
    // Subtraction
    //
    
    /// Subtraction: MPFloat - MPFloat
    public static func - (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_sub(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Subtraction: MPFloat - Double
    public static func - (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_sub_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Subtraction: Double - MPFloat
    public static func - (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rhs.precision)
        mpfr_d_sub(&result.storage.value, lhs, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Subtraction (in place): MPFloat -= MPFloat
    public static func -= (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_sub(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }
    
    /// Subtraction (in place): MPFloat -= Double
    public static func -= (lhs: inout MPFloat, rhs: Double) {
        mpfr_sub_d(&lhs.mutableValue, &lhs.storage.value, rhs, MPFR_RNDN)
    }

    //
    // Multiplication
    //
    
    /// Multiplication: MPFloat * MPFloat
    public static func * (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_mul(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Multiplication: MPFloat * Double
    public static func * (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_mul_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Multiplication: Double * MPFloat
    public static func * (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rhs.precision)
        mpfr_mul_d(&result.storage.value, &rhs.storage.value, lhs, MPFR_RNDN)
        return result
    }
    
    /// Inplace multiplication: MPFloat *= MPFloat
    public static func *= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_mul(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }
    
    /// Inplace multiplication: MPFloat *= Double
    public static func *= (_ lhs: inout MPFloat, _ rhs: Double) {
        mpfr_mul_d(&lhs.mutableValue, &lhs.storage.value, rhs, MPFR_RNDN)
    }

    //
    // Division
    //
    
    /// Divison: MPFloat / MPFloat
    public static func / (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_div(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Divison: MPFloat / Double
    public static func / (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_div_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Division: Double / MPFloat
    public static func / (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rhs.precision)
        mpfr_d_div(&result.storage.value, lhs, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Division: in-place MPFloat /= MPFloat
    public static func /= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_div(&lhs.mutableValue, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
    }
    
    /// Division: in-place MPFloat /= Double
    public static func /= (_ lhs: inout MPFloat, _ rhs: Double) {
        mpfr_div_d(&lhs.mutableValue, &lhs.storage.value, rhs, MPFR_RNDN)
    }
    
    //
    // Comparision operators
    //
    
    /// MPFloat == MPFloat
    public static func == (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) == 0
    }
    
    /// MPFloat == Double
    public static func == (lhs: MPFloat, rhs: Double) -> Bool {
        return mpfr_cmp_d(&lhs.storage.value, rhs) == 0
    }

    /// MPFloat != MPFloat
    public static func != (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) != 0
    }
    
    /// MPFloat != Double
    public static func != (lhs: MPFloat, rhs: Double) -> Bool {
        return mpfr_cmp_d(&lhs.storage.value, rhs) != 0
    }
    
    public static func < (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) < 0
    }
    
    public static func < (lhs: MPFloat, rhs: Double) -> Bool {
        return mpfr_cmp_d(&lhs.storage.value, rhs) < 0
    }
    
    public static func <= (lhs: MPFloat, rhs: MPFloat) -> Bool {
        let r = mpfr_cmp(&lhs.storage.value, &rhs.storage.value)
        return r <= 0
    }
    
    public static func <= (lhs: MPFloat, rhs: Double) -> Bool {
        let r = mpfr_cmp_d(&lhs.storage.value, rhs)
        return r <= 0
    }

    public static func > (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.storage.value, &rhs.storage.value) > 0
    }
    
    public static func > (lhs: MPFloat, rhs: Double) -> Bool {
        return mpfr_cmp_d(&lhs.storage.value, rhs) > 0
    }
    
    public static func >= (lhs: MPFloat, rhs: MPFloat) -> Bool {
        let r = mpfr_cmp(&lhs.storage.value, &rhs.storage.value)
        return r >= 0
    }
    
    public static func >= (lhs: MPFloat, rhs: Double) -> Bool {
        let r = mpfr_cmp_d(&lhs.storage.value, rhs)
        return r >= 0
    }
    
    //
    // Constants
    //

    /// Return PI with specified precision
    public static func PI(precision: Int = 128) -> MPFloat {
        let result = MPFloat(precision: precision)
        mpfr_const_pi(&result.storage.value, MPFR_RNDN)
        return result
    }

    /// Return ln(2) with specified precision
    public static func LOG2(precision: Int = 128) -> MPFloat {
        let result = MPFloat(precision: precision)
        mpfr_const_log2(&result.storage.value, MPFR_RNDN)
        return result
    }
    
    //
    // Min/Max/Abs
    //
    
    /// Return maximum of two values
    /// - Parameters:
    ///   - lhs: Value 1
    ///   - rhs: Value 2
    /// - Returns: Maximum of lhs, rhs
    public static func max(_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        if mpfr_cmp(&lhs.storage.value, &rhs.storage.value) > 0 {
            let result = MPFloat(precision: lhs.precision)
            mpfr_set(&result.storage.value, &lhs.storage.value, MPFR_RNDN)
            return result
        }
        else {
            let result = MPFloat(precision: rhs.precision)
            mpfr_set(&result.storage.value, &rhs.storage.value, MPFR_RNDN)
            return result
        }
    }

    /// Return minimum of two values
    /// - Parameters:
    ///   - lhs: Value 1
    ///   - rhs: Value 2
    /// - Returns: Minimum of lhs, rhs
    public static func min(_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        if mpfr_cmp(&lhs.storage.value, &rhs.storage.value) < 0 {
            let result = MPFloat(precision: lhs.precision)
            mpfr_set(&result.storage.value, &lhs.storage.value, MPFR_RNDN)
            return result
        }
        else {
            let result = MPFloat(precision: rhs.precision)
            mpfr_set(&result.storage.value, &rhs.storage.value, MPFR_RNDN)
            return result
        }
    }
    
    /// Return absolute value
    /// - Parameter x: value
    /// - Returns: absolute value
    public static func abs(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_abs(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    //
    // sqrt/root/square/pow/fmod
    //
    
    /// Square root
    public static func sqrt(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sqrt(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }

    /// nth root
    public static func root(_ x: MPFloat, _ n: Int) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_rootn_si(&result.storage.value, &result.storage.value, n, MPFR_RNDN)
        return result
    }
    
    /// Square
    public static func square(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sqr(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Floating point modulo division
    public static func fmod(_ x: MPFloat, _ y: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_fmod(&result.storage.value, &x.storage.value, &y.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Power: MPFloat ^ MPFloat
    public static func pow(_ x: MPFloat, _ y: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_pow(&result.storage.value, &x.storage.value, &y.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Power: MPFloat ^ Uint
    public static func pow(_ x: MPFloat, _ y: Int) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_pow_si(&result.storage.value, &x.storage.value, y, MPFR_RNDN)
        return result
    }
    
    ///
    /// Logarithm and exponential functions
    ///

    /// Logarithm
    public static func log(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Logarithm of (1 + x). For very small x
    /// As we are calculating with arbitrary precision, we can simply use log(x)
    public static func log(onePlus x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log1p(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }

    /// Logarithm with base 2
    public static func log2(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log2(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Logarithm with base 10
    public static func log10(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log10(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }

    /// Exponential function
    public static func exp(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_exp(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    public static func exp2(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_exp2(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    public static func exp10(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_exp10(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Exponential function minus 1: exp(x) - 1
    public static func expMinusOne(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_expm1(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    ///
    /// Trigonometric functions
    ///

    /// Sine
    public static func sin(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sin(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }

    /// Cosine
    public static func cos(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_cos(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }

    /// Tangent
    public static func tan(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_tan(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// The signed angle formed in the plane between the vector `(x,y)` and the
    /// positive real axis, measured in radians.
    public static func atan2(y: MPFloat, x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_atan2(&result.storage.value, &y.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Inverse sine
    public static func asin(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_asin(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Inverse cosine
    public static func acos(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_acos(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Inverse tangent
    public static func atan(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_atan(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Hyperbolic sine
    public static func sinh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sinh(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Hyperbolic cosine
    public static func cosh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_cosh(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Hyperbolic tangent
    public static func tanh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_tanh(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Inverse hyperbolic sine
    public static func asinh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_asinh(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Inverse hyperbolic cosine
    public static func acosh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_acosh(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Inverse hyperbolic tangent
    public static func atanh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_atanh(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    //
    // Error handling
    //
    
    /// Error function
    public static func erf(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_erf(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Complementary error function
    public static func erfc(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_erfc(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    //
    // Gamma functions
    
    // Gamma
    public static func gamma(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_gamma(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Logarithm of absolute value of gamma
    public static func logGamma(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_lngamma(&result.storage.value, &x.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Sign of gamma
    public static func signGamma(_ x: MPFloat) -> FloatingPointSign {
        let result = MPFloat(precision: x.precision)
        var sign: Int32 = 0
        mpfr_lgamma(&result.storage.value, &sign, &x.storage.value, MPFR_RNDN)
        return sign == 1 ? .plus : .minus
    }
    
    //
    // Other functions
    //
    
    public static func hypot(_ x: MPFloat, _ y: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_hypot(&result.storage.value, &x.storage.value, &y.storage.value, MPFR_RNDN)
        return result
    }
}

//
// Extend Double to support casting from MPFloat to Double
//
extension Double {
    
    /// Convert MPFloat to Double
    public init(_ mpf: MPFloat) {
        self = mpf.toDouble()
    }
    
}


