//
//  MPFloat.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

import Foundation
import CMPFR


//
// Floating point type with variable precision
//

public struct MPFloat: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Comparable, CustomStringConvertible, Sendable {

    ///
    /// Type for precision information
    ///
    public struct Precision: Sendable, Codable, Equatable {
        public var isDbl: Bool
        public var bits: Int
        
        public init(isDbl: Bool, bits: Int) {
            self.isDbl = isDbl
            self.bits = bits
        }
    }
    
    ///
    /// Flags
    ///
    public enum Flag {
        case inexact        // Inexact / rounded value
        case nan            // Not a number
        case underflow      // Underflow
        case overflow       // Overflow
        case erange         // Range error
        
        public static func clearAll() {
            mpfr_clear_flags()
        }
    }

    ///
    /// Class for internal storage
    ///
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
    
    /// Internal storage
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
    
    /// Result precision mode
    public enum ResultPrecision: Int, Sendable {
        case leftOperand
        case rightOperand
        case defaultPrecision
        case maxOfOperands
    }
    
    /// Result precision mode for functions with 2 or more arguments
    /// WARNING: This variable must not be set within parallel threads. This would cause a race condition!
    nonisolated(unsafe)private static var _resultPrecision: ResultPrecision = .maxOfOperands
    
    /// Precision bits
    private var _precision: Int

    /// Precision flags
    public static let detectPrecision: Int     = 0
    public static let useOtherPrecision: Int   = -1
    public static let useDefaultPrecision: Int = -2
    
    /// Get/set the default precision
    public private(set) static var defaultPrecision: Int {
        get { mpfr_get_default_prec() }
        set { mpfr_set_default_prec(newValue) }
    }
    
    /// Return precision
    public var precision: Int {
        get { _precision }
        set {
            _precision = newValue
            mpfr_prec_round(&storage.value, newValue, MPFR_RNDN)
        }
    }
    
    /// Return MPFloat value as String
    public var description: String {
        return self.toString()
    }
    
    /// Not a number
    public static var nan: MPFloat {
        let result = MPFloat()
        mpfr_set_nan(&result.storage.value)
        return result
    }
    
    /// Check for not a number
    public var isNaN: Bool {
        mpfr_nan_p(&storage.value) != 0
    }
    
    /// Check for infinite number
    public var isInfinite: Bool {
        mpfr_inf_p(&storage.value) != 0
    }
    
    /// Return exponent
    public var exponent: Int {
        guard mpfr_regular_p(&storage.value) != 0 else {
            // 0, Inf or NaN - no valid exponent
            return 0
        }
        return Int(mpfr_get_exp(&storage.value))
    }
    
    /// Return result precision
    @inline(__always)
    private static func rp(_ p1: Int, _ p2: Int) -> Int {
        switch Self._resultPrecision {
        case .leftOperand:
            return p1
        case .rightOperand:
            return p2
        case .maxOfOperands:
            return Swift.max(p1, p2)
        case .defaultPrecision:
            return Self.defaultPrecision
        }
    }
    
    public static func setPrecisions(defaultPrecision: Int, resultPrecision: ResultPrecision) {
        guard Thread.isMainThread else { return }
        Self._resultPrecision = resultPrecision
        Self.defaultPrecision = defaultPrecision
    }
    
    /// Calculate required precision for numeric string
    /// - Parameters:
    ///   - real:        Base value for precision estimation. Decimal string (i.e. "1.5e-12").
    ///   - scale:       Scaling factor, default = 1 (no scaling)
    ///   - safetyBits:  Additional bits as safety buffer, default = 8
    /// - Returns:       Tuple (isDbl: Bool, precision: Int), nil on error
    public static func getPrecision(real: String, scale: Int = 1, safetyBits: Int = 8) -> Precision? {

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
            
            return Precision(isDbl: doubleIsSufficient, bits: totalBits)
        }
        
        return nil
    }

    //
    // Initializers
    //
    
    /// Initialize value as NaN
    public init(precision: Int = MPFloat.defaultPrecision) {
        _precision = precision
        storage = Storage(precision: _precision)
    }
    
    /// Initialize by assigning a Double value
    public init(floatLiteral value: Double) {
        _precision = MPFloat.defaultPrecision
        storage = Storage(precision: _precision)
        mpfr_set_d(&storage.value, value, MPFR_RNDN)
    }
    
    /// Initialize by assigning an Int value
    public init(integerLiteral value: Int) {
        _precision = MPFloat.defaultPrecision
        storage = Storage(precision: _precision)
        mpfr_set_si(&storage.value, value, MPFR_RNDN)
    }
    
    /// Initialize a value with a String
    /// - Parameters:
    ///   - sval: A number as a string
    ///   - precision: Required precision / number of bits.
    public init(_ sval: String, precision: Int = MPFloat.detectPrecision) {
        if precision == MPFloat.detectPrecision {
            if let precisionRequirements = Self.getPrecision(real: sval, safetyBits: 8) {
                _precision = precisionRequirements.bits
            }
            else {
                _precision = MPFloat.defaultPrecision
            }
        }
        else {
            _precision = precision
        }
        storage = Storage(precision: _precision)
        mpfr_set_str(&mutableValue, sval, 10, MPFR_RNDN)
    }
    
    /// Initialize value with a Float
    public init(_ fval: Float, precision: Int = MPFloat.defaultPrecision) {
        _precision = precision
        storage = Storage(precision: _precision)
        mpfr_set_d(&mutableValue, Double(fval), MPFR_RNDN)
    }
    
    /// Initialize value with a Double
    public init(_ dval: Double, precision: Int = MPFloat.defaultPrecision) {
        _precision = precision
        storage = Storage(precision: _precision)
        mpfr_set_d(&mutableValue, dval, MPFR_RNDN)
    }
    
    /// Initialize value with an Int
    public init(_ ival: Int, precision: Int = MPFloat.defaultPrecision) {
        _precision = precision
        storage = Storage(precision: _precision)
        mpfr_set_d(&mutableValue, Double(ival), MPFR_RNDN)
    }
    
    /// Initialize value with a MPFloat with optional precision conversion
    public init(_ other: MPFloat, precision: Int = MPFloat.useOtherPrecision) {
        switch precision {
        case MPFloat.useDefaultPrecision:
            _precision = MPFloat.defaultPrecision
        case MPFloat.useOtherPrecision:
            _precision = other.precision
        default:
            _precision = precision
        }
        
        storage = Storage(precision: _precision)
        mpfr_set(&storage.value, &other.storage.value, MPFR_RNDN)
    }
    
    //
    // Tests and checks
    //
    
    /// Check for zero
    public func isZero() -> Bool {
        mpfr_zero_p(&storage.value) != 0 ? true : false
    }
    
    /// Check flag
    /// - Parameter flag: Flag:
    ///   - .inexact
    ///   - .underflow
    ///   - .overflow
    ///   - .erange
    ///   - .nan
    /// - Returns: true if flag is set
    public static func isFlagSet(_ flag: Flag) -> Bool {
        switch flag {
        case .inexact:
            mpfr_inexflag_p() != 0 ? true : false
        case .underflow:
            mpfr_underflow_p() != 0 ? true : false
        case .overflow:
            mpfr_overflow_p() != 0 ? true : false
        case .erange:
            mpfr_erangeflag_p() != 0 ? true : false
        case .nan:
            mpfr_nanflag_p() != 0 ? true : false
        }
    }
    
    //
    // Conversion functions
    //
    
    /// Convert value to Double
    /// - Returns: Double value
    public func toDouble() -> Double {
        return mpfr_get_d(&self.storage.value, MPFR_RNDN)
    }

    /// Convert value to String
    /// - Parameters:
    ///   - digits: Number of decimal digits. 0 = maximum number of digits
    ///   - expFmt: If true (default) use exponential format for values with negativ exponent
    /// - Returns: Value as string or "NaN" on error
    public func toString(digits: Int, expFmt: Bool = true) -> String {
        var exp: mpfr_exp_t = 0
        
        // MPFR returns digits without decimal point and exponent separately
        guard let cStr = mpfr_get_str(nil, &exp, 10, digits, &self.storage.value, MPFR_RNDN) else {
            return "NaN"
        }
        
        // Convert C-String to Swift String and free memory of C-String
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
            if expFmt {
                if let firstChar = rawDigits.first {
                    result += String(firstChar) + "."
                    result += rawDigits.dropFirst()
                }
                result += "E" + String(exp - 1)
            }
            else {
                result += "0."
                result += String(repeating: "0", count: Swift.abs(Int(exp)))
                result += rawDigits
            }
        }
        
        // Trim zeroes
        if result.contains(".") {
            while result.last == "0" { result.removeLast() }
            if result.last == "." { result.removeLast() }
        }
        
        return result
    }
    
    /// Convert MPFloat to String
    /// - Returns: Numeric string
    @inline(__always)
    public func toString() -> String {
        self.toString(digits: 0)
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
    
    /// Addition: MPFloat + MPFloat, precision = lhs.precision
    public static func + (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_add(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Addition: MPFloat + Double
    public static func + (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_add_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Addition: Double + MPFloat
    public static func + (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
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
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_sub(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Subtraction: MPFloat - Double
    public static func - (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_sub_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Subtraction: Double - MPFloat
    public static func - (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
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
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_mul(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Multiplication: MPFloat * Double
    public static func * (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_mul_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Multiplication: Double * MPFloat
    public static func * (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
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
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_div(&result.storage.value, &lhs.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Divison: MPFloat / Double
    public static func / (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_div_d(&result.storage.value, &lhs.storage.value, rhs, MPFR_RNDN)
        return result
    }
    
    /// Division: Double / MPFloat
    public static func / (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
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
    @inline(__always)
    public static func PI(precision: Int = useDefaultPrecision) -> MPFloat {
        let result = MPFloat(precision: precision == useDefaultPrecision ? Self.defaultPrecision : precision)
        mpfr_const_pi(&result.storage.value, MPFR_RNDN)
        return result
    }

    /// Return ln(2) with specified precision
    @inline(__always)
    public static func LOG2(precision: Int = useDefaultPrecision) -> MPFloat {
        let result = MPFloat(precision: precision == useDefaultPrecision ? Self.defaultPrecision : precision)
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
    //
    
    /// Gamma correction
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
    // Interpolation functions
    //
    
    /// Linear interpolation
    /// - Parameters:
    ///   - a: Start / lower value
    ///   - b: End / upper value
    ///   - t: Interpolation factor. Should be in range 0...1
    /// - Returns: Interpolated value
    @inline(__always)
    public static func lerp(a: Self, b: Self, t: Self) -> Self {
        return a + (b - a) * t
    }
    
    /// Exact linear interpolation
    /// - Parameters:
    ///   - a: Start / lower value
    ///   - b: End / upper value
    ///   - t: Interpolation factor. Should be in range 0...1
    /// - Returns: Interpolated value
    @inline(__always)
    public static func lerpExact(a: Self, b: Self, t: Self) -> Self {
        return (1.0 - t) * a + t * b
    }

    /// Cubic interpolation
    public static func interpolateCubic(edge0: Self, edge1: Self, x: Self) -> Self {
        // map x into [0, 1]
        // If x < edge0: t = 0; if x > edge1: t = 1
        let t = Self.min(Self.max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
        
        // Cubic Hermite interpolation
        return t * t * (3.0 - 2.0 * t)
    }
    
    /// Create an array with linear distributed foating point values
    /// - Parameters:
    ///   - start: First value of array
    ///   - end: Last value of array
    ///   - n: Number of values in array
    /// - Returns: Array of size n
    public static func linspace(_ start: Self, _ end: Self, _ n: Int) -> [Self] {
        guard n > 0 else { return [] }
        let step = (end - start) / Self(n - 1, precision: start.precision)
        var a = Array(0..<n).map { Self($0, precision: start.precision) * step + start }
        
        // Prevent rounding errors for last array element
        if n > 1 { a[n-1] = end }
        
        return a
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

    /// Return Double precision
    var precision: Int { 53 }
    
    /// Convert MPFloat to Double. Parameter precision is not used
    public init(_ mpf: MPFloat, precision: Int = 53) {
        self = mpf.toDouble()
    }
    
}


