//
//  MPComplex.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

import Foundation
import CMPFR

//
// Complex number type with variable precision
//

public struct MPComplex : ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, CustomStringConvertible, Sendable {
    
    // Real und imaginary parts
    public var real: MPFloat
    public var imaginary: MPFloat

    /// Get/set precision of real and imaginary part
    public var precision: Int {
        get { real.precision }
        set {
            real.precision      = newValue
            imaginary.precision = newValue
        }
    }
            
    /// Calculate required precision
    ///
    /// - Parameters:
    ///   - real:        Base value for precision estimation. Decimal string (i.e. "1.5e-12").
    ///   - imaginary:   Base value for precision estimation. Decimal string (i.e. "1.5e-12").
    ///   - safetyBits:  Additional bits as safety buffer (default = 8).
    /// - Returns:       Tuple (isDbl: Bool, precision: Int, isError: Bool)
    public static func getPrecision(real: String, imaginary: String, scaleReal: Int = 1, scaleImaginary: Int = 1,
                                    safetyBits: Int = 8) -> (isDbl: Bool, precision: Int)? {

        /// Parse exponent of floating point string
        func parseExponent(_ string: String) -> Int? {
            let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()
            
            // Try Double parsing
            if let value = Double(trimmed), value.isFinite, value != 0 {
                return Int(floor(log10(Swift.abs(value))))
            }
            
            // Underflow/Overflow: Extract exponent from string
            // Format: [±][digits][.digits]e[±]exponent
            if let eIdx = trimmed.firstIndex(of: "e") {
                let expString = String(trimmed[trimmed.index(after: eIdx)...])
                return Int(expString)
            }
            
            return nil
        }
        
        // Parse exponents
        let realExp = parseExponent(real)
        let imagExp = parseExponent(imaginary)
        guard var re = realExp, var ie = imagExp else { return nil }

        // Scaled exponent: size / scaling
        // log10(real / scaleReal) = log10(real) - log10(scaleReal)
        // log10(imaginary / scaleImaginary) = log10(imaginary) - log10(scaleImaginary)
        // log10(1) = 0 => No scaling
        // Scaling factors < 1 are ignored (log10(0) = -inf would trap when converted to Int)
        re -= Int(floor(log10(Swift.max(Double(scaleReal), 1.0))))
        ie -= Int(floor(log10(Swift.max(Double(scaleImaginary), 1.0))))

        let smallestExp = Swift.min(re, ie)  // negativster Exponent = kleinste Ausdehnung

        // bits = ceil(-log2(10^exp)) = ceil(-exp * log2(10))
        let log2_10 = log2(10.0)
        let rawBits = Int(ceil(-Double(smallestExp) * log2_10))
        let totalBits = Swift.max(rawBits + safetyBits, 53)
        let doubleIsSufficient = rawBits <= (53 - safetyBits)
            
        return (doubleIsSufficient, totalBits)
    }

    //
    // Initializers
    //
    
    /// Initialize MPComplex with NaN
    public init(precision: Int = MPFloat.defaultPrecision) {
        self.real      = MPFloat(precision: precision)
        self.imaginary = MPFloat(precision: precision)
    }
    
    /// Initialize MPComplex with Double literal
    public init(floatLiteral value: Double) {
        self.real      = MPFloat(value)
        self.imaginary = MPFloat(0.0)
    }
    
    /// Initialize MPComplex with Int literal
    public init(integerLiteral value: Int) {
        self.real = MPFloat(value)
        self.imaginary = MPFloat(0)
    }
    
    /// Initialize MPComplex with Double values
    public init(_ real: Double, _ imaginary: Double, precision: Int = MPFloat.defaultPrecision) {
        self.real      = MPFloat(real, precision: precision)
        self.imaginary = MPFloat(imaginary, precision: precision)
    }

    /// Initialize MPComplex with String values
    /// If one of the Strings is not a number, the resulting value is (NaN, NaN)
    public init(_ real: String, _ imaginary: String = "0", precision: Int = MPFloat.detectPrecision) {
        var p: Int
        if precision == MPFloat.detectPrecision {
            // Magnitude based estimation (previous behaviour) as lower bound, plus number of
            // significant digits of both parts, so that long mantissas are not truncated
            let magnitudeBits = Self.getPrecision(real: real, imaginary: imaginary)?.precision ?? MPFloat.defaultPrecision
            p = Swift.max(magnitudeBits,
                          MPFloat.requiredPrecision(forDecimalString: real),
                          MPFloat.requiredPrecision(forDecimalString: imaginary))
        }
        else if precision == MPFloat.useDefaultPrecision || precision == MPFloat.useOtherPrecision {
            p = MPFloat.defaultPrecision
        }
        else {
            p = precision
        }
        
        self.real      = MPFloat(real, precision: p)
        self.imaginary = MPFloat(imaginary, precision: p)
        
        if self.real.isNaN || self.imaginary.isNaN {
            self.real = MPFloat.nan
            self.imaginary = MPFloat.nan
        }
    }
    
    /// Initialize MPComplex with MPFloat values.
    public init(_ real: MPFloat, _ imaginary: MPFloat) {
        let p = Swift.max(real.precision, imaginary.precision)
        self.real      = MPFloat(real, precision: p)
        self.imaginary = MPFloat(imaginary, precision: p)
    }
    
    /// Initialize MPComplex with MPFloat values.
    public init(_ real: MPFloat, _ imaginary: MPFloat, precision: Int) {
        let p = precision == MPFloat.useOtherPrecision ? Swift.max(real.precision, imaginary.precision) : precision
        self.real      = MPFloat(real, precision: p)
        self.imaginary = MPFloat(imaginary, precision: p)
    }
    
    /// Initialize MPComplex with other MPComplex
    public init(_ other: MPComplex, precision: Int = MPFloat.useOtherPrecision) {
        self.real      = MPFloat(other.real, precision: precision)
        self.imaginary = MPFloat(other.imaginary, precision: precision)
    }
    
    /// Make MPComplex printable
    public var description: String {
        let sign: String = self.imaginary < 0.0 ? "-" : "+"
        return "\(self.real.toString())\(sign)\(MPFloat.abs(self.imaginary).toString())i"
    }
    
    /// Return value as String
    public func toString(digits: Int = 0, expFmt: Bool = true) -> String {
        let sign: String = self.imaginary < 0.0 ? "-" : "+"
        return "\(self.real.toString(digits: digits, expFmt: expFmt))" + sign + "\(MPFloat.abs(self.imaginary).toString(digits: digits, expFmt: expFmt))i"
    }
    
    /// Euclidean norm
    public var length: MPFloat {
        MPComplex.abs(self)
    }
    
    /// Square of Euclidean norm
    public var lengthSquared: MPFloat {
        MPComplex.normSquare(self)
    }
    
    /// Square of value
    public var squared: MPComplex {
        MPComplex.square(self)
    }

    /// Return minimum of real and imaginary part
    public var min: MPFloat {
        MPFloat.min(self.real, self.imaginary)
    }

    /// Return minimum of real and imaginary part
    public var max: MPFloat {
        MPFloat.max(self.real, self.imaginary)
    }
    
    /// Return true if either real or imaginary part is NaN
    public var isNaN: Bool {
        self.real.isNaN || self.imaginary.isNaN
    }
    
    /// Negate MPComplex
    public static prefix func - (rhs: MPComplex) -> MPComplex {
        var result = rhs
        mpfr_neg(result.real.mutablePtr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_neg(result.imaginary.mutablePtr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    //
    // Addition
    //

    /// Addition (MPComplex, MPComplex), return new value
    public static func + (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        mpfr_add(result.real.mutablePtr, lhs.real.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_add(result.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Addition (MPComplex, MPFloat), return new value
    public static func + (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        mpfr_add(result.real.mutablePtr, lhs.real.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        mpfr_set(result.imaginary.mutablePtr, lhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Addition (MPFloat, MPComplex), return new value
    public static func + (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        mpfr_add(result.real.mutablePtr, lhs.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_set(result.imaginary.mutablePtr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }

    /// Addition, in-place
    public static func += (lhs: inout MPComplex, rhs: MPComplex) {
        mpfr_add(lhs.real.mutablePtr, lhs.real.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_add(lhs.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
    }
    
    //
    // Subtraction
    //
    
    /// Subtraction (MPComplex, MPComplex), return new value
    public static func - (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        mpfr_sub(result.real.mutablePtr, lhs.real.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_sub(result.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Subtraction (MPComplex, MPFloat), return new value
    public static func - (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        mpfr_sub(result.real.mutablePtr, lhs.real.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        mpfr_set(result.imaginary.mutablePtr, lhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Subtraction (MPFloat, MPComplex), return new value
    /// a - (c + di) = (a - c) - di
    public static func - (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        mpfr_sub(result.real.mutablePtr, lhs.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_neg(result.imaginary.mutablePtr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Subtraction, in-place
    public static func -= (lhs: inout MPComplex, rhs: MPComplex) {
        mpfr_sub(lhs.real.mutablePtr, lhs.real.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_sub(lhs.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
    }
    
    //
    // Multiplication
    //

    /// Multiplication (MPComplex, MPComplex), return new value
    /// (a + bi)(c + di) = (ac - bd) + (ad + bc)i
    /// mpfr_fmms / mpfr_fmma compute both parts with a single rounding and without temporaries.
    public static func * (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        mpfr_fmms(result.real.mutablePtr,
                  lhs.real.storage.ptr, rhs.real.storage.ptr,
                  lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_fmma(result.imaginary.mutablePtr,
                  lhs.real.storage.ptr, rhs.imaginary.storage.ptr,
                  lhs.imaginary.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Multiplication (MPComplex, MPFloat), return new value
    public static func * (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        mpfr_mul(result.real.mutablePtr, lhs.real.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        mpfr_mul(result.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Multiplication (MPFloat, MPComplex), return new value
    public static func * (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: rhs.precision)
        mpfr_mul(result.real.mutablePtr, lhs.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_mul(result.imaginary.mutablePtr, lhs.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Multiplication (in place)
    public static func *= (lhs: inout MPComplex, rhs: MPComplex) {
        // The real part must be computed from the original values, so it goes into a new value.
        // The imaginary part can be computed in place (MPFR allows aliasing of output and inputs).
        // If rhs shares storage with lhs (z *= z), copy on write keeps rhs unchanged.
        var re = MPFloat(precision: lhs.precision)
        mpfr_fmms(re.mutablePtr,
                  lhs.real.storage.ptr, rhs.real.storage.ptr,
                  lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_fmma(lhs.imaginary.mutablePtr,
                  lhs.real.storage.ptr, rhs.imaginary.storage.ptr,
                  lhs.imaginary.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        lhs.real = re
    }
    
    /// Multiplication (in place)
    public static func *= (lhs: inout MPComplex, rhs: MPFloat) {
        mpfr_mul(lhs.real.mutablePtr, lhs.real.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        mpfr_mul(lhs.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
    }

    //
    // Division
    //
    
    /// Division: MPComplex, MPComplex
    /// (a + bi) / (c + di) = ((ac + bd) + (bc - ad)i) / (c² + d²)
    public static func / (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: MPFloat.rp(lhs.precision, rhs.precision))
        var den = MPFloat(precision: result.precision)

        // den = c² + d²
        mpfr_fmma(den.mutablePtr, rhs.real.storage.ptr, rhs.real.storage.ptr,
                  rhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        
        // result.real = (ac + bd) / den
        mpfr_fmma(result.real.mutablePtr,
                  lhs.real.storage.ptr, rhs.real.storage.ptr,
                  lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_div(result.real.mutablePtr, result.real.storage.ptr, den.storage.ptr, MPFR_RNDN)
        
        // result.imaginary = (bc - ad) / den
        mpfr_fmms(result.imaginary.mutablePtr,
                  lhs.imaginary.storage.ptr, rhs.real.storage.ptr,
                  lhs.real.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_div(result.imaginary.mutablePtr, result.imaginary.storage.ptr, den.storage.ptr, MPFR_RNDN)
        
        return result
    }
    
    /// Division: MPComplex, MPFloat
    /// Divides both parts directly (correctly rounded, no reciprocal)
    public static func / (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        mpfr_div(result.real.mutablePtr, lhs.real.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        mpfr_div(result.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Division: MPFloat, MPComplex
    /// lhs / (c + di) = lhs * (c - di) / (c² + d²)
    public static func / (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: rhs.precision)
        var den = MPFloat(precision: rhs.precision)

        // den = c² + d²
        mpfr_fmma(den.mutablePtr, rhs.real.storage.ptr, rhs.real.storage.ptr,
                  rhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)

        // result.real = lhs * c / den
        mpfr_mul(result.real.mutablePtr, lhs.storage.ptr, rhs.real.storage.ptr, MPFR_RNDN)
        mpfr_div(result.real.mutablePtr, result.real.storage.ptr, den.storage.ptr, MPFR_RNDN)
        
        // result.imaginary = -lhs * d / den
        mpfr_mul(result.imaginary.mutablePtr, lhs.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_neg(result.imaginary.mutablePtr, result.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_div(result.imaginary.mutablePtr, result.imaginary.storage.ptr, den.storage.ptr, MPFR_RNDN)
        
        return result
    }
    
    /// Division, in-place
    public static func /= (lhs: inout MPComplex, rhs: MPComplex) {
        // If rhs shares storage with lhs (z /= z), copy on write keeps rhs unchanged.
        var den = MPFloat(precision: lhs.precision)
        var re = MPFloat(precision: lhs.precision)

        // den = c² + d²
        mpfr_fmma(den.mutablePtr, rhs.real.storage.ptr, rhs.real.storage.ptr,
                  rhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)

        // re = (ac + bd) / den, computed from the original values
        mpfr_fmma(re.mutablePtr,
                  lhs.real.storage.ptr, rhs.real.storage.ptr,
                  lhs.imaginary.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_div(re.mutablePtr, re.storage.ptr, den.storage.ptr, MPFR_RNDN)

        // imaginary = (bc - ad) / den, in place
        mpfr_fmms(lhs.imaginary.mutablePtr,
                  lhs.imaginary.storage.ptr, rhs.real.storage.ptr,
                  lhs.real.storage.ptr, rhs.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_div(lhs.imaginary.mutablePtr, lhs.imaginary.storage.ptr, den.storage.ptr, MPFR_RNDN)
        
        lhs.real = re
    }
    
    /// Division (in place)
    /// Divides both parts directly (correctly rounded, no reciprocal)
    public static func /= (lhs: inout MPComplex, rhs: MPFloat) {
        mpfr_div(lhs.real.mutablePtr, lhs.real.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
        mpfr_div(lhs.imaginary.mutablePtr, lhs.imaginary.storage.ptr, rhs.storage.ptr, MPFR_RNDN)
    }
    
    //
    // Comparision
    //
    
    public static func == (lhs: MPComplex, rhs: MPComplex) -> Bool {
        return lhs.real == rhs.real && lhs.imaginary == rhs.imaginary
    }
    
    public static func != (lhs: MPComplex, rhs: MPComplex) -> Bool {
        return lhs.real != rhs.real || lhs.imaginary != rhs.imaginary
    }
    
    //
    // Mathematic functions
    //
    
    /// Square
    /// (a + bi)² = (a² - b²) + 2ab i
    public static func square(_ value: MPComplex) -> MPComplex {
        var result = MPComplex(precision: value.precision)

        // a² - b², single rounding
        mpfr_fmms(result.real.mutablePtr,
                  value.real.storage.ptr, value.real.storage.ptr,
                  value.imaginary.storage.ptr, value.imaginary.storage.ptr, MPFR_RNDN)
        
        // 2ab: multiplication by 2 is an exact exponent shift
        mpfr_mul(result.imaginary.mutablePtr, value.real.storage.ptr, value.imaginary.storage.ptr, MPFR_RNDN)
        mpfr_mul_2ui(result.imaginary.mutablePtr, result.imaginary.storage.ptr, 1, MPFR_RNDN)
        
        return result
    }
    
    /// Square of Euclidean norm: a² + b², single rounding
    public static func normSquare(_ value: MPComplex) -> MPFloat {
        var result = MPFloat(precision: value.precision)
        mpfr_fmma(result.mutablePtr,
                  value.real.storage.ptr, value.real.storage.ptr,
                  value.imaginary.storage.ptr, value.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }
    
    /// Absolute value / norm: sqrt(a² + b²), correctly rounded, no intermediate overflow
    public static func abs(_ value: MPComplex) -> MPFloat {
        var result = MPFloat(precision: value.precision)
        mpfr_hypot(result.mutablePtr, value.real.storage.ptr, value.imaginary.storage.ptr, MPFR_RNDN)
        return result
    }

    /// Angle between real and imaginary part
    /// - Parameter value: Complex value
    /// - Returns: atan2(imaginary, real)
    public static func arg(_ value: MPComplex) -> MPFloat {
        return MPFloat.atan2(y: value.imaginary, x: value.real)
    }
    
}







