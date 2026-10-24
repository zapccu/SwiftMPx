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
    /// (a + bi)(c + di) = (ac - bd) + (ad + bc)i
    /// mpfr_fmms / mpfr_fmma compute both parts with a single rounding and without temporaries.
    public static func * (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        mpfr_fmms(&result.real.mutableValue,
                  &lhs.real.storage.value, &rhs.real.storage.value,
                  &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_fmma(&result.imaginary.mutableValue,
                  &lhs.real.storage.value, &rhs.imaginary.storage.value,
                  &lhs.imaginary.storage.value, &rhs.real.storage.value, MPFR_RNDN)
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
        // The real part must be computed from the original values, so it goes into a new value.
        // The imaginary part can be computed in place (MPFR allows aliasing of output and inputs).
        // If rhs shares storage with lhs (z *= z), copy on write keeps rhs unchanged.
        var re = MPFloat(precision: lhs.precision)
        mpfr_fmms(&re.mutableValue,
                  &lhs.real.storage.value, &rhs.real.storage.value,
                  &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_fmma(&lhs.imaginary.mutableValue,
                  &lhs.real.storage.value, &rhs.imaginary.storage.value,
                  &lhs.imaginary.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        lhs.real = re
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
    /// (a + bi) / (c + di) = ((ac + bd) + (bc - ad)i) / (c² + d²)
    public static func / (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        var den = MPFloat(precision: lhs.precision)

        // den = c² + d²
        mpfr_fmma(&den.mutableValue, &rhs.real.storage.value, &rhs.real.storage.value,
                  &rhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        
        // result.real = (ac + bd) / den
        mpfr_fmma(&result.real.mutableValue,
                  &lhs.real.storage.value, &rhs.real.storage.value,
                  &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_div(&result.real.mutableValue, &result.real.storage.value, &den.storage.value, MPFR_RNDN)
        
        // result.imaginary = (bc - ad) / den
        mpfr_fmms(&result.imaginary.mutableValue,
                  &lhs.imaginary.storage.value, &rhs.real.storage.value,
                  &lhs.real.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_div(&result.imaginary.mutableValue, &result.imaginary.storage.value, &den.storage.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division: MPComplex, MPFloat
    /// Divides both parts directly (correctly rounded, no reciprocal)
    public static func / (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        var result = MPComplex(precision: lhs.precision)
        mpfr_div(&result.real.mutableValue, &lhs.real.storage.value, &rhs.storage.value, MPFR_RNDN)
        mpfr_div(&result.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Division: MPFloat, MPComplex
    /// lhs / (c + di) = lhs * (c - di) / (c² + d²)
    public static func / (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        var result = MPComplex(precision: rhs.precision)
        var den = MPFloat(precision: rhs.precision)

        // den = c² + d²
        mpfr_fmma(&den.mutableValue, &rhs.real.storage.value, &rhs.real.storage.value,
                  &rhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)

        // result.real = lhs * c / den
        mpfr_mul(&result.real.mutableValue, &lhs.storage.value, &rhs.real.storage.value, MPFR_RNDN)
        mpfr_div(&result.real.mutableValue, &result.real.storage.value, &den.storage.value, MPFR_RNDN)
        
        // result.imaginary = -lhs * d / den
        mpfr_mul(&result.imaginary.mutableValue, &lhs.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_neg(&result.imaginary.mutableValue, &result.imaginary.storage.value, MPFR_RNDN)
        mpfr_div(&result.imaginary.mutableValue, &result.imaginary.storage.value, &den.storage.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division, in-place
    public static func /= (lhs: inout MPComplex, rhs: MPComplex) {
        // If rhs shares storage with lhs (z /= z), copy on write keeps rhs unchanged.
        var den = MPFloat(precision: lhs.precision)
        var re = MPFloat(precision: lhs.precision)

        // den = c² + d²
        mpfr_fmma(&den.mutableValue, &rhs.real.storage.value, &rhs.real.storage.value,
                  &rhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)

        // re = (ac + bd) / den, computed from the original values
        mpfr_fmma(&re.mutableValue,
                  &lhs.real.storage.value, &rhs.real.storage.value,
                  &lhs.imaginary.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_div(&re.mutableValue, &re.storage.value, &den.storage.value, MPFR_RNDN)

        // imaginary = (bc - ad) / den, in place
        mpfr_fmms(&lhs.imaginary.mutableValue,
                  &lhs.imaginary.storage.value, &rhs.real.storage.value,
                  &lhs.real.storage.value, &rhs.imaginary.storage.value, MPFR_RNDN)
        mpfr_div(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &den.storage.value, MPFR_RNDN)
        
        lhs.real = re
    }
    
    /// Division (in place)
    /// Divides both parts directly (correctly rounded, no reciprocal)
    public static func /= (lhs: inout MPComplex, rhs: MPFloat) {
        mpfr_div(&lhs.real.mutableValue, &lhs.real.storage.value, &rhs.storage.value, MPFR_RNDN)
        mpfr_div(&lhs.imaginary.mutableValue, &lhs.imaginary.storage.value, &rhs.storage.value, MPFR_RNDN)
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
        mpfr_fmms(&result.real.mutableValue,
                  &value.real.storage.value, &value.real.storage.value,
                  &value.imaginary.storage.value, &value.imaginary.storage.value, MPFR_RNDN)
        
        // 2ab: multiplication by 2 is an exact exponent shift
        mpfr_mul(&result.imaginary.mutableValue, &value.real.storage.value, &value.imaginary.storage.value, MPFR_RNDN)
        mpfr_mul_2ui(&result.imaginary.mutableValue, &result.imaginary.storage.value, 1, MPFR_RNDN)
        
        return result
    }
    
    /// Square of Euclidean norm: a² + b², single rounding
    public static func normSquare(_ value: MPComplex) -> MPFloat {
        var result = MPFloat(precision: value.precision)
        mpfr_fmma(&result.mutableValue,
                  &value.real.storage.value, &value.real.storage.value,
                  &value.imaginary.storage.value, &value.imaginary.storage.value, MPFR_RNDN)
        return result
    }
    
    /// Absolute value: sqrt(a² + b²), correctly rounded, no intermediate overflow
    public static func abs(_ value: MPComplex) -> MPFloat {
        var result = MPFloat(precision: value.precision)
        mpfr_hypot(&result.mutableValue, &value.real.storage.value, &value.imaginary.storage.value, MPFR_RNDN)
        return result
    }
    
    //
    // In-place iteration (no allocations)
    //
    
    /// z = z² + c, in place.
    /// Intended for hot loops like the calculation of a reference orbit. With a scratch value that is
    /// reused across iterations, no memory is allocated per iteration.
    /// - Parameters:
    ///   - c:       Value to add
    ///   - scratch: Temporary value, reused across calls. Its precision is adjusted to the
    ///              precision of self if necessary (allocation only on first use).
    public mutating func formSquareAdd(_ c: MPComplex, scratch: inout MPFloat) {
        if scratch.precision != real.precision {
            scratch = MPFloat(precision: real.precision)
        }
        
        // scratch = a² - b², from the original values
        mpfr_fmms(&scratch.mutableValue,
                  &real.storage.value, &real.storage.value,
                  &imaginary.storage.value, &imaginary.storage.value, MPFR_RNDN)
        
        // imaginary = 2ab + c.imaginary
        mpfr_mul(&imaginary.mutableValue, &real.storage.value, &imaginary.storage.value, MPFR_RNDN)
        mpfr_mul_2ui(&imaginary.mutableValue, &imaginary.storage.value, 1, MPFR_RNDN)
        mpfr_add(&imaginary.mutableValue, &imaginary.storage.value, &c.imaginary.storage.value, MPFR_RNDN)
        
        // real = a² - b² + c.real
        mpfr_add(&real.mutableValue, &scratch.storage.value, &c.real.storage.value, MPFR_RNDN)
    }
    
    /// z = z² + c, in place (allocates one temporary value per call)
    public mutating func formSquareAdd(_ c: MPComplex) {
        var scratch = MPFloat(precision: real.precision)
        formSquareAdd(c, scratch: &scratch)
    }
    
    /// z = z², in place
    public mutating func formSquare(scratch: inout MPFloat) {
        if scratch.precision != real.precision {
            scratch = MPFloat(precision: real.precision)
        }
        mpfr_fmms(&scratch.mutableValue,
                  &real.storage.value, &real.storage.value,
                  &imaginary.storage.value, &imaginary.storage.value, MPFR_RNDN)
        mpfr_mul(&imaginary.mutableValue, &real.storage.value, &imaginary.storage.value, MPFR_RNDN)
        mpfr_mul_2ui(&imaginary.mutableValue, &imaginary.storage.value, 1, MPFR_RNDN)
        swap(&real, &scratch)
    }
    
    /// D = 2·D·Z + 1, in place (derivative dZ/dc of the Mandelbrot iteration).
    /// Must be called with Z of the current iteration, i.e. BEFORE z.formSquareAdd(c).
    /// Use MPComplex.formMandelbrotStep(z:d:c:scratch:) to perform both steps in the correct order.
    /// Rounding: imaginary part 1 rounding (fmma, doubling is exact), real part 2 roundings (fmms, +1).
    /// - Parameters:
    ///   - z:       Current value Z
    ///   - scratch: Temporary value, reused across calls. Its precision is adjusted to the
    ///              precision of self if necessary. Use the same precision for D and Z to avoid
    ///              reallocations when the same scratch value is used for both steps.
    public mutating func formDerivativeStep(z: MPComplex, scratch: inout MPFloat) {
        if scratch.precision != real.precision {
            scratch = MPFloat(precision: real.precision)
        }
        
        // scratch = Re(D·Z) = dr·zr − di·zi, from the original values
        mpfr_fmms(&scratch.mutableValue,
                  &real.storage.value, &z.real.storage.value,
                  &imaginary.storage.value, &z.imaginary.storage.value, MPFR_RNDN)
        
        // Im(D) = 2·(dr·zi + di·zr)
        mpfr_fmma(&imaginary.mutableValue,
                  &real.storage.value, &z.imaginary.storage.value,
                  &imaginary.storage.value, &z.real.storage.value, MPFR_RNDN)
        mpfr_mul_2ui(&imaginary.mutableValue, &imaginary.storage.value, 1, MPFR_RNDN)
        
        // Re(D) = 2·Re(D·Z) + 1
        mpfr_mul_2ui(&scratch.mutableValue, &scratch.storage.value, 1, MPFR_RNDN)
        mpfr_add_ui(&scratch.mutableValue, &scratch.storage.value, 1, MPFR_RNDN)
        
        // New real part is in scratch. The old real part becomes the next scratch value.
        swap(&real, &scratch)
    }
    
    /// D = 2·D·Z + 1, in place (allocates one temporary value per call)
    public mutating func formDerivativeStep(z: MPComplex) {
        var scratch = MPFloat(precision: real.precision)
        formDerivativeStep(z: z, scratch: &scratch)
    }
    
    /// Angle between real and imaginary part
    /// - Parameter value: Complex value
    /// - Returns: atan2(imaginary, real)
    public static func arg(_ value: MPComplex) -> MPFloat {
        return MPFloat.atan2(y: value.imaginary, x: value.real)
    }
    
}







