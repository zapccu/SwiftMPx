//
//  MPFloat.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

import Foundation
import Synchronization
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
    /// The MPFR value (header) and its significand (limbs) are allocated in one memory block using
    /// the MPFR custom interface. The address of the value is therefore stable for the lifetime of
    /// the object, and it can be passed to MPFR functions as a plain pointer, without inout
    /// conversions (`&x.value`) and without exclusivity conflicts.
    /// Note: values must never be passed to mpfr_set_prec, mpfr_prec_round or mpfr_clear, because the
    /// memory is not managed by MPFR.
    internal final class Storage: @unchecked Sendable {
        let ptr: UnsafeMutablePointer<__mpfr_struct>
        
        init(precision: Int) {
            let headerSize = MemoryLayout<__mpfr_struct>.stride
            let limbSize   = Int(mpfr_custom_get_size(precision))
            let alignment  = Swift.max(MemoryLayout<__mpfr_struct>.alignment, MemoryLayout<mp_limb_t>.alignment)
            let raw = UnsafeMutableRawPointer.allocate(byteCount: headerSize + limbSize, alignment: alignment)
            let limbs = raw + headerSize
            mpfr_custom_init(limbs, precision)
            ptr = raw.bindMemory(to: __mpfr_struct.self, capacity: 1)
            // Kind 0 = MPFR_NAN_KIND (enum mpfr_kind_t): new values are NaN, like after mpfr_init2
            mpfr_custom_init_set(ptr, 0, 0, precision, limbs)
        }
        
        convenience init(copying other: Storage) {
            self.init(precision: mpfr_get_prec(other.ptr))
            mpfr_set(ptr, other.ptr, MPFR_RNDN)
        }
        
        deinit {
            UnsafeMutableRawPointer(ptr).deallocate()
        }
    }
    
    /// Internal storage
    internal var storage: Storage
    
    //
    // Access to the MPFR value
    //
    
    /// Pointer to the MPFR value for read access (MPFR input arguments, mpfr_srcptr).
    /// Never copies, works for let constants:
    /// ```
    /// mpfr_add(result.mutablePtr, a.ptr, b.ptr, MPFR_RNDN)
    /// ```
    /// The pointer is valid as long as this value is alive and not modified. Never write through it:
    /// the storage may be shared with copies of this value. Use mutablePtr for results.
    public var ptr: mpfr_srcptr {
        UnsafePointer(storage.ptr)
    }
    
    /// Pointer to the MPFR value for write access (MPFR output argument, mpfr_ptr).
    /// Copy on write: if the storage is shared with other copies, it is copied first.
    /// MPFR allows the output to be one of the inputs:
    /// ```
    /// mpfr_mul_2ui(x.mutablePtr, x.ptr, 1, MPFR_RNDN)
    /// ```
    /// Get mutablePtr before (left of) the input pointers of the same value, so that the inputs
    /// refer to the new storage if a copy was necessary. The precision of the value must not be
    /// changed through the pointer (no mpfr_set_prec / mpfr_prec_round).
    public var mutablePtr: mpfr_ptr {
        mutating get {
            if !isKnownUniquelyReferenced(&storage) {
                storage = Storage(copying: storage)
            }
            return storage.ptr
        }
    }
    
    /// Copy of the MPFR value (header only, the significand is shared).
    /// For MPFR function arguments use ptr and mutablePtr.
    public var value: mpfr_t {
        storage.ptr.pointee
    }
    
    /// Result precision mode for operators and functions with 2 operands that return a new value.
    /// Not used by in-place operators (+=, -=, *=, /=): they keep the precision of the left operand.
    public enum ResultPrecision: Int, Sendable {
        case leftOperand
        case rightOperand
        case defaultPrecision
        case maxOfOperands
    }
    
    /// Result precision mode for functions with 2 or more arguments.
    /// Stored atomically, so it is visible to and safe for all threads.
    private static let _resultPrecision = Atomic<Int>(ResultPrecision.maxOfOperands.rawValue)

    /// Default precision in bits.
    /// MPFR's own default precision (mpfr_set_default_prec) is thread-local when MPFR is built
    /// thread-safe (Homebrew, most Linux distributions). A value set on the main thread would not be
    /// visible in tasks running on other threads. Therefore the default precision is kept here and
    /// always passed explicitly to mpfr_init2.
    private static let _defaultPrecision = Atomic<Int>(53)

    /// Precision flags
    public static let detectPrecision: Int     = 0
    public static let useOtherPrecision: Int   = -1
    public static let useDefaultPrecision: Int = -2

    /// Valid precision range (MPFR_PREC_MIN ... MPFR_PREC_MAX)
    public static let minPrecision: Int = 1
    public static let maxPrecision: Int = Int.max - 256

    /// Get the default precision (set it with setPrecisions)
    public static var defaultPrecision: Int {
        _defaultPrecision.load(ordering: .relaxed)
    }

    /// Get the current result precision mode (set it with setPrecisions)
    public static var resultPrecision: ResultPrecision {
        ResultPrecision(rawValue: _resultPrecision.load(ordering: .relaxed)) ?? .maxOfOperands
    }

    /// Check if a precision value is a valid number of bits (no flag)
    @inline(__always)
    public static func isValidPrecision(_ bits: Int) -> Bool {
        bits >= minPrecision && bits <= maxPrecision
    }

    /// Resolve a requested precision (bits or one of the precision flags) to a number of bits
    /// - Parameters:
    ///   - requested: Number of bits or one of detectPrecision, useOtherPrecision, useDefaultPrecision
    ///   - other:     Precision of a source value, used for useOtherPrecision and detectPrecision
    /// - Returns:     Valid number of bits. Traps with a clear message if requested is invalid.
    @inline(__always)
    internal static func resolvePrecision(_ requested: Int, other: Int? = nil) -> Int {
        switch requested {
        case useDefaultPrecision:
            return defaultPrecision
        case useOtherPrecision, detectPrecision:
            return other ?? defaultPrecision
        default:
            precondition(isValidPrecision(requested), "MPFloat: invalid precision \(requested)")
            return requested
        }
    }

    /// Return precision
    /// The precision is stored only in the MPFR value (single source of truth).
    public var precision: Int {
        get { mpfr_get_prec(storage.ptr) }
        set {
            let current = precision
            let bits = MPFloat.resolvePrecision(newValue, other: current)
            guard bits != current else { return }
            // New storage with requested precision, rounded value. Copies of this value keep the
            // old storage (copy on write). mpfr_prec_round must not be used with custom memory.
            let newStorage = Storage(precision: bits)
            mpfr_set(newStorage.ptr, storage.ptr, MPFR_RNDN)
            storage = newStorage
        }
    }
    
    /// Return MPFloat value as String
    public var description: String {
        return self.toString()
    }
    
    /// Not a number
    public static var nan: MPFloat {
        let result = MPFloat()
        mpfr_set_nan(result.storage.ptr)
        return result
    }
    
    /// Check for not a number
    public var isNaN: Bool {
        mpfr_nan_p(storage.ptr) != 0
    }
    
    /// Check for infinite number
    public var isInfinite: Bool {
        mpfr_inf_p(storage.ptr) != 0
    }
    
    /// Return exponent
    public var exponent: Int {
        guard mpfr_regular_p(storage.ptr) != 0 else {
            // 0, Inf or NaN - no valid exponent
            return 0
        }
        return Int(mpfr_get_exp(storage.ptr))
    }
    
    /// Return result precision for operations with 2 operands
    /// - Parameters:
    ///   - p1: Precision bits of left hand side operator
    ///   - p2: Precision bits of right hand side operator
    /// - Returns: Precision bits of operation result
    @inline(__always)
    public static func rp(_ p1: Int, _ p2: Int) -> Int {
        switch Self.resultPrecision {
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
    
    /// Set default precision and result precision mode.
    /// Both values are stored atomically and are visible to all threads. They are global settings:
    /// changing them while calculations are running affects all subsequent operations.
    public static func setPrecisions(defaultPrecision: Int, resultPrecision: ResultPrecision) {
        precondition(isValidPrecision(defaultPrecision), "MPFloat: invalid default precision \(defaultPrecision)")
        Self._resultPrecision.store(resultPrecision.rawValue, ordering: .relaxed)
        Self._defaultPrecision.store(defaultPrecision, ordering: .relaxed)
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

    /// Precision required for a decimal string without loss of digits.
    /// Combines the magnitude based estimation of getPrecision() (previous behaviour, used as lower
    /// bound) with the number of significant digits, so that long mantissas like
    /// "-0.743643887037158704752191506114774" are not truncated to 53 bits.
    /// - Parameters:
    ///   - sval:       Decimal string
    ///   - safetyBits: Additional bits
    /// - Returns:      Number of bits
    public static func requiredPrecision(forDecimalString sval: String, safetyBits: Int = 8) -> Int {
        var digits = 0
        var leadingZeros = true
        scan: for ch in sval.utf8 {
            switch ch {
            case UInt8(ascii: "0"):
                if !leadingZeros { digits += 1 }
            case UInt8(ascii: "1")...UInt8(ascii: "9"):
                leadingZeros = false
                digits += 1
            case UInt8(ascii: "e"), UInt8(ascii: "E"), UInt8(ascii: "@"):
                break scan
            default:
                continue
            }
        }
        let digitBits = Int((Double(digits) * Foundation.log2(10.0)).rounded(.up)) + safetyBits
        let magnitudeBits = getPrecision(real: sval, safetyBits: safetyBits)?.bits ?? defaultPrecision
        return Swift.min(Swift.max(digitBits, magnitudeBits), maxPrecision)
    }

    //
    // Initializers
    //
    
    /// Initialize value as NaN
    public init(precision: Int = MPFloat.defaultPrecision) {
        storage = Storage(precision: MPFloat.resolvePrecision(precision))
    }
    
    /// Initialize by assigning a Double value (float literal)
    /// The literal is converted to Double by the compiler first: `let x: MPFloat = 0.1` is the
    /// binary Double value nearest to 0.1, not decimal 0.1 with full precision. Use
    /// MPFloat("0.1", precision: p) for decimal values with more than Double precision.
    public init(floatLiteral value: Double) {
        storage = Storage(precision: MPFloat.defaultPrecision)
        mpfr_set_d(storage.ptr, value, MPFR_RNDN)
    }
    
    /// Initialize by assigning an Int value (integer literal, exact)
    public init(integerLiteral value: Int) {
        storage = Storage(precision: MPFloat.defaultPrecision)
        mpfr_set_si(storage.ptr, value, MPFR_RNDN)
    }
    
    /// Initialize a value with a String
    /// If the string is not a valid number, the value is NaN. Use init?(validating:precision:)
    /// to detect invalid strings.
    /// - Parameters:
    ///   - sval: A number as a string
    ///   - precision: Required precision / number of bits.
    public init(_ sval: String, precision: Int = MPFloat.detectPrecision) {
        let bits = precision == MPFloat.detectPrecision
            ? Self.requiredPrecision(forDecimalString: sval)
            : MPFloat.resolvePrecision(precision)
        storage = Storage(precision: bits)
        if mpfr_set_str(storage.ptr, sval, 10, MPFR_RNDN) != 0 {
            mpfr_set_nan(storage.ptr)
        }
    }
    
    /// Initialize a value with a String. Returns nil if the string is not a valid number.
    /// - Parameters:
    ///   - sval: A number as a string. Also accepts "@NaN@", "@Inf@", "-@Inf@"
    ///   - precision: Required precision / number of bits.
    public init?(validating sval: String, precision: Int = MPFloat.detectPrecision) {
        let bits = precision == MPFloat.detectPrecision
            ? Self.requiredPrecision(forDecimalString: sval)
            : MPFloat.resolvePrecision(precision)
        storage = Storage(precision: bits)
        if mpfr_set_str(storage.ptr, sval, 10, MPFR_RNDN) != 0 {
            return nil
        }
    }
    
    /// Initialize value with a Float
    public init(_ fval: Float, precision: Int = MPFloat.defaultPrecision) {
        storage = Storage(precision: MPFloat.resolvePrecision(precision))
        mpfr_set_flt(storage.ptr, fval, MPFR_RNDN)
    }
    
    /// Initialize value with a Double
    public init(_ dval: Double, precision: Int = MPFloat.defaultPrecision) {
        storage = Storage(precision: MPFloat.resolvePrecision(precision))
        mpfr_set_d(storage.ptr, dval, MPFR_RNDN)
    }
    
    /// Initialize value with an Int (exact for all Int values if precision >= 64)
    public init(_ ival: Int, precision: Int = MPFloat.defaultPrecision) {
        storage = Storage(precision: MPFloat.resolvePrecision(precision))
        mpfr_set_si(storage.ptr, ival, MPFR_RNDN)
    }
    
    /// Initialize value with a MPFloat with optional precision conversion
    public init(_ other: MPFloat, precision: Int = MPFloat.useOtherPrecision) {
        let bits = MPFloat.resolvePrecision(precision, other: other.precision)
        if bits == other.precision {
            // Same precision: share storage, copy on write
            storage = other.storage
        }
        else {
            storage = Storage(precision: bits)
            mpfr_set(storage.ptr, other.storage.ptr, MPFR_RNDN)
        }
    }
    
    //
    // Tests and checks
    //
    
    /// Check for zero
    public var isZero: Bool {
        mpfr_zero_p(storage.ptr) != 0 ? true : false
    }
    
    /// Sign of the value (also for zero, infinity and NaN)
    public var sign: FloatingPointSign {
        mpfr_signbit(storage.ptr) != 0 ? .minus : .plus
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
        return mpfr_get_d(self.storage.ptr, MPFR_RNDN)
    }

    /// Convert value to String
    /// - Parameters:
    ///   - digits: Number of decimal digits. 0 = maximum number of digits
    ///   - expFmt: If true (default) use exponential format for values with negativ exponent
    /// - Returns: Value as string or "NaN" on error
    public func toString(digits: Int, expFmt: Bool = true) -> String {
        // Special values. The strings can be parsed by mpfr_set_str (lossless Codable round trip)
        if mpfr_nan_p(self.storage.ptr) != 0 {
            return "@NaN@"
        }
        if mpfr_inf_p(self.storage.ptr) != 0 {
            return mpfr_signbit(self.storage.ptr) != 0 ? "-@Inf@" : "@Inf@"
        }
        if mpfr_zero_p(self.storage.ptr) != 0 {
            return mpfr_signbit(self.storage.ptr) != 0 ? "-0" : "0"
        }
        
        var exp: mpfr_exp_t = 0
        
        // MPFR returns digits without decimal point and exponent separately
        guard let cStr = mpfr_get_str(nil, &exp, 10, digits, self.storage.ptr, MPFR_RNDN) else {
            return "@NaN@"
        }
        
        // Convert C-String to Swift String and free memory of C-String
        var rawDigits = String(cString: cStr)
        mpfr_free_str(cStr)
        
        // Extract sign
        let isNegative = rawDigits.hasPrefix("-")
        if isNegative { rawDigits.removeFirst() }
        
        /// Remove trailing zeros (and a trailing decimal point) of a mantissa with decimal point
        func trimmed(_ mantissa: String) -> String {
            guard mantissa.contains(".") else { return mantissa }
            var m = mantissa
            while m.last == "0" { m.removeLast() }
            if m.last == "." { m.removeLast() }
            return m
        }
        
        var result = isNegative ? "-" : ""
        
        if exp > 0 && exp <= rawDigits.count {
            // Case 1: "123.45"
            let dotIndex = Int(exp)
            var mantissa = String(rawDigits.prefix(dotIndex))
            let suffix = rawDigits.dropFirst(dotIndex)
            if !suffix.isEmpty {
                mantissa += "." + String(suffix)
            }
            result += trimmed(mantissa)
        } else if exp > 0 {
            // Case 2: "1234500"
            result += rawDigits
            result += String(repeating: "0", count: Int(exp) - rawDigits.count)
        } else if expFmt {
            // Case 3a: Very small number "1.23E-4". Trim zeros of mantissa before appending exponent
            let mantissa = String(rawDigits.prefix(1)) + "." + String(rawDigits.dropFirst())
            result += trimmed(mantissa) + "E" + String(exp - 1)
        } else {
            // Case 3b: Very small number "0.000123"
            let mantissa = "0." + String(repeating: "0", count: Swift.abs(Int(exp))) + rawDigits
            result += trimmed(mantissa)
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
        mpfr_neg(result.mutablePtr, result.storage.ptr, MPFR_RNDN)
        return result
    }
    
    //
    // Addition
    //
    
    /// Addition: MPFloat + MPFloat, precision = lhs.precision
    public static func + (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_add(result.storage.ptr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Addition: MPFloat + Double
    public static func + (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_add_d(result.storage.ptr, lhs.storage.ptr, rhs, MPFR_RNDN)
        return result
    }
    
    /// Addition: Double + MPFloat
    public static func + (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_add_d(result.storage.ptr, rhs.storage.ptr, lhs, MPFR_RNDN)
        return result
    }
    
    /// Addition (in place): MPFloat += MPFloat
    public static func += (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_add(lhs.mutablePtr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
    }
    
    /// Addition (in place): MPFloat += Double
    public static func += (lhs: inout MPFloat, rhs: Double) {
        mpfr_add_d(lhs.mutablePtr, lhs.storage.ptr, rhs, MPFR_RNDN)
    }
    
    //
    // Subtraction
    //
    
    /// Subtraction: MPFloat - MPFloat
    public static func - (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_sub(result.storage.ptr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Subtraction: MPFloat - Double
    public static func - (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_sub_d(result.storage.ptr, lhs.storage.ptr, rhs, MPFR_RNDN)
        return result
    }
    
    /// Subtraction: Double - MPFloat
    public static func - (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_d_sub(result.storage.ptr, lhs, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Subtraction (in place): MPFloat -= MPFloat
    public static func -= (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_sub(lhs.mutablePtr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
    }
    
    /// Subtraction (in place): MPFloat -= Double
    public static func -= (lhs: inout MPFloat, rhs: Double) {
        mpfr_sub_d(lhs.mutablePtr, lhs.storage.ptr, rhs, MPFR_RNDN)
    }

    //
    // Multiplication
    //
    
    /// Multiplication: MPFloat * MPFloat
    public static func * (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_mul(result.storage.ptr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Multiplication: MPFloat * Double
    public static func * (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_mul_d(result.storage.ptr, lhs.storage.ptr, rhs, MPFR_RNDN)
        return result
    }
    
    /// Multiplication: Double * MPFloat
    public static func * (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_mul_d(result.storage.ptr, rhs.storage.ptr, lhs, MPFR_RNDN)
        return result
    }
    
    /// Inplace multiplication: MPFloat *= MPFloat
    public static func *= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_mul(lhs.mutablePtr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
    }
    
    /// Inplace multiplication: MPFloat *= Double
    public static func *= (_ lhs: inout MPFloat, _ rhs: Double) {
        mpfr_mul_d(lhs.mutablePtr, lhs.storage.ptr, rhs, MPFR_RNDN)
    }

    //
    // Division
    //
    
    /// Divison: MPFloat / MPFloat
    public static func / (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_div(result.storage.ptr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Divison: MPFloat / Double
    public static func / (_ lhs: MPFloat, _ rhs: Double) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_div_d(result.storage.ptr, lhs.storage.ptr, rhs, MPFR_RNDN)
        return result
    }
    
    /// Division: Double / MPFloat
    public static func / (_ lhs: Double, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: rp(lhs.precision, rhs.precision))
        mpfr_d_div(result.storage.ptr, lhs, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Division: in-place MPFloat /= MPFloat
    public static func /= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_div(lhs.mutablePtr, lhs.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
    }
    
    /// Division: in-place MPFloat /= Double
    public static func /= (_ lhs: inout MPFloat, _ rhs: Double) {
        mpfr_div_d(lhs.mutablePtr, lhs.storage.ptr, rhs, MPFR_RNDN)
    }
    
    //
    // Comparision operators
    //
    
    // All comparisons follow IEEE 754 semantics: any comparison involving NaN is false
    // (except !=, which is true). mpfr_cmp must not be used here, it returns 0 for NaN operands.
    
    /// MPFloat == MPFloat
    public static func == (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_equal_p(lhs.storage.ptr, rhs.storage.ptr) != 0
    }
    
    /// MPFloat == Double
    public static func == (lhs: MPFloat, rhs: Double) -> Bool {
        guard !lhs.isNaN && !rhs.isNaN else { return false }
        return mpfr_cmp_d(lhs.storage.ptr, rhs) == 0
    }

    /// MPFloat != MPFloat
    public static func != (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return !(lhs == rhs)
    }
    
    /// MPFloat != Double
    public static func != (lhs: MPFloat, rhs: Double) -> Bool {
        return !(lhs == rhs)
    }
    
    public static func < (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_less_p(lhs.storage.ptr, rhs.storage.ptr) != 0
    }
    
    public static func < (lhs: MPFloat, rhs: Double) -> Bool {
        guard !lhs.isNaN && !rhs.isNaN else { return false }
        return mpfr_cmp_d(lhs.storage.ptr, rhs) < 0
    }
    
    public static func <= (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_lessequal_p(lhs.storage.ptr, rhs.storage.ptr) != 0
    }
    
    public static func <= (lhs: MPFloat, rhs: Double) -> Bool {
        guard !lhs.isNaN && !rhs.isNaN else { return false }
        return mpfr_cmp_d(lhs.storage.ptr, rhs) <= 0
    }

    public static func > (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_greater_p(lhs.storage.ptr, rhs.storage.ptr) != 0
    }
    
    public static func > (lhs: MPFloat, rhs: Double) -> Bool {
        guard !lhs.isNaN && !rhs.isNaN else { return false }
        return mpfr_cmp_d(lhs.storage.ptr, rhs) > 0
    }
    
    public static func >= (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_greaterequal_p(lhs.storage.ptr, rhs.storage.ptr) != 0
    }
    
    public static func >= (lhs: MPFloat, rhs: Double) -> Bool {
        guard !lhs.isNaN && !rhs.isNaN else { return false }
        return mpfr_cmp_d(lhs.storage.ptr, rhs) >= 0
    }
    
    //
    // Constants
    //
    
    /// Return PI with specified precision
    @inline(__always)
    public static func PI(precision: Int = useDefaultPrecision) -> MPFloat {
        let result = MPFloat(precision: precision == useDefaultPrecision ? Self.defaultPrecision : precision)
        mpfr_const_pi(result.storage.ptr, MPFR_RNDN)
        return result
    }

    /// Return ln(2) with specified precision
    @inline(__always)
    public static func LOG2(precision: Int = useDefaultPrecision) -> MPFloat {
        let result = MPFloat(precision: precision == useDefaultPrecision ? Self.defaultPrecision : precision)
        mpfr_const_log2(result.storage.ptr, MPFR_RNDN)
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
        // If one value is NaN, return the other one (IEEE maxNum). No copy: storage is shared (COW)
        if lhs.isNaN { return rhs }
        if rhs.isNaN { return lhs }
        return mpfr_greater_p(lhs.storage.ptr, rhs.storage.ptr) != 0 ? lhs : rhs
    }

    /// Return minimum of two values
    /// - Parameters:
    ///   - lhs: Value 1
    ///   - rhs: Value 2
    /// - Returns: Minimum of lhs, rhs
    public static func min(_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        // If one value is NaN, return the other one (IEEE minNum). No copy: storage is shared (COW)
        if lhs.isNaN { return rhs }
        if rhs.isNaN { return lhs }
        return mpfr_less_p(lhs.storage.ptr, rhs.storage.ptr) != 0 ? lhs : rhs
    }
    
    /// Return absolute value
    /// - Parameter x: value
    /// - Returns: absolute value
    public static func abs(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_abs(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    //
    // sqrt/root/square/pow/fmod
    //
    
    /// Square root
    public static func sqrt(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sqrt(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }

    /// nth root
    public static func root(_ x: MPFloat, _ n: Int) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_rootn_si(result.storage.ptr, x.storage.ptr, n, MPFR_RNDN)
        return result
    }
    
    /// Square
    public static func square(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sqr(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Multiplication by 2
    public static func mul2(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_mul_2ui(result.storage.ptr, x.storage.ptr, 1, MPFR_RNDN)
        return result
    }
    
    /// Calculate x * y + z
    public static func fma(_ x: MPFloat, _ y: MPFloat, _ z: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_fma(result.storage.ptr, x.storage.ptr, y.storage.ptr, z.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Floating point modulo division
    public static func fmod(_ x: MPFloat, _ y: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_fmod(result.storage.ptr, x.storage.ptr, y.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Power: MPFloat ^ MPFloat
    public static func pow(_ x: MPFloat, _ y: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_pow(result.storage.ptr, x.storage.ptr, y.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Power: MPFloat ^ Uint
    public static func pow(_ x: MPFloat, _ y: Int) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_pow_si(result.storage.ptr, x.storage.ptr, y, MPFR_RNDN)
        return result
    }
    
    ///
    /// Logarithm and exponential functions
    ///

    /// Logarithm
    public static func log(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Logarithm of (1 + x), accurate also for very small x (no cancellation in 1 + x)
    public static func log(onePlus x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log1p(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }

    /// Logarithm with base 2
    public static func log2(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log2(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Logarithm with base 10
    public static func log10(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_log10(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }

    /// Exponential function
    public static func exp(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_exp(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    public static func exp2(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_exp2(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    public static func exp10(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_exp10(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Exponential function minus 1: exp(x) - 1
    public static func expMinusOne(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_expm1(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    ///
    /// Trigonometric functions
    ///

    /// Sine
    public static func sin(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sin(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }

    /// Cosine
    public static func cos(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_cos(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }

    /// Tangent
    public static func tan(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_tan(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// The signed angle formed in the plane between the vector `(x,y)` and the
    /// positive real axis, measured in radians.
    public static func atan2(y: MPFloat, x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_atan2(result.storage.ptr, y.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Inverse sine
    public static func asin(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_asin(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Inverse cosine
    public static func acos(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_acos(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Inverse tangent
    public static func atan(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_atan(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Hyperbolic sine
    public static func sinh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_sinh(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Hyperbolic cosine
    public static func cosh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_cosh(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Hyperbolic tangent
    public static func tanh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_tanh(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Inverse hyperbolic sine
    public static func asinh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_asinh(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Inverse hyperbolic cosine
    public static func acosh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_acosh(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Inverse hyperbolic tangent
    public static func atanh(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_atanh(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    //
    // Error handling
    //
    
    /// Error function
    public static func erf(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_erf(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Complementary error function
    public static func erfc(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_erfc(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    //
    // Gamma functions
    //
    
    /// Gamma function
    public static func gamma(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_gamma(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Logarithm of absolute value of gamma
    public static func logGamma(_ x: MPFloat) -> MPFloat {
        let result = MPFloat(precision: x.precision)
        mpfr_lngamma(result.storage.ptr, x.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Sign of gamma
    public static func signGamma(_ x: MPFloat) -> FloatingPointSign {
        let result = MPFloat(precision: x.precision)
        var sign: Int32 = 0
        mpfr_lgamma(result.storage.ptr, &sign, x.storage.ptr, MPFR_RNDN)
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
    
    /// Linear interpolation (1 - t)·a + t·b
    /// Returns exactly b for t = 1 (lerp returns exactly a for t = 0, but not b for t = 1).
    /// Both variants round several times, none of them is exact for all t.
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
        guard n > 1 else { return [start] }
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
        mpfr_hypot(result.storage.ptr, x.storage.ptr, y.storage.ptr, MPFR_RNDN)
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


