//
//  MPComplex.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

import CMPFR

public class MPComplex : CustomStringConvertible {
    public var real: MPFloat
    public var imaginary: MPFloat
    
    // Precision (default is 128 bit)
    public let precision: Int32

    // Temporary variables, prevent memory allocation
    public var tmp1: MPFloat
    public var tmp2: MPFloat
    public var tmp3: MPFloat
    public var tmp4: MPFloat
    
    /// Initialize MPComplex
    init(prec: Int32 = 128) {
        self.precision = prec
        self.real = MPFloat(prec: prec)
        self.imaginary = MPFloat(prec: prec)
        self.tmp1 = MPFloat(prec: prec)
        self.tmp2 = MPFloat(prec: prec)
        self.tmp3 = MPFloat(prec: prec)
        self.tmp4 = MPFloat(prec: prec)
    }
    
    /// Initialize MPComplex with Double values
    public init(_ real: Double, _ imaginary: Double = 0.0, precision: Int32 = 128) {
        self.precision = precision
        self.real = MPFloat(real, precision: precision)
        self.imaginary = MPFloat(imaginary, precision: precision)
        self.tmp1 = MPFloat(prec: precision)
        self.tmp2 = MPFloat(prec: precision)
        self.tmp3 = MPFloat(prec: precision)
        self.tmp4 = MPFloat(prec: precision)
    }
    
    /// Initialize MPComplex with String values
    public init(_ real: String, _ imaginary: String = "0", precision: Int32 = 128) {
        self.precision = precision
        self.real = MPFloat(real, precision: precision)
        self.imaginary = MPFloat(imaginary, precision: precision)
        self.tmp1 = MPFloat(prec: precision)
        self.tmp2 = MPFloat(prec: precision)
        self.tmp3 = MPFloat(prec: precision)
        self.tmp4 = MPFloat(prec: precision)
    }
    
    /// Initialize MPComplex with MPFloat values
    public init(_ real: MPFloat, _ imaginary: MPFloat = MPFloat(0.0), precision: Int32 = 128) {
        self.precision = precision
        self.real = MPFloat(prec: precision)
        self.imaginary = MPFloat(prec: precision)
        self.real.set(real)
        self.imaginary.set(imaginary)
        self.tmp1 = MPFloat(prec: precision)
        self.tmp2 = MPFloat(prec: precision)
        self.tmp3 = MPFloat(prec: precision)
        self.tmp4 = MPFloat(prec: precision)
    }
    
    /// Make MPComplex printable
    public var description: String {
        return "\(self.real.toString()) + \(self.imaginary.toString())i"
    }
    
    public var length: MPFloat {
        self.abs()
    }
    
    public var lengthSquared: MPFloat {
        self.norm()
    }
    
    /// Return a copy of a value
    /// Use y = x.copy() instead of y = x
    public func copy() -> MPComplex {
        let newObj = MPComplex(prec: self.precision)
        newObj.real.set(self.real)
        newObj.imaginary.set(self.imaginary)
        return newObj
    }
    
    /// Set value to String
    public func set(_ real: String, _ imaginary: String = "0") {
        self.real.set(real)
        self.imaginary.set(imaginary)
    }
    
    /// Set value to Double
    public func set(_ real: Double, _ imaginary: Double = 0.0) {
        self.real.set(real)
        self.imaginary.set(imaginary)
    }
    
    /// Set value to value of MPFloat (deep copy)
    public func set(_ real: MPFloat, _ imaginary: MPFloat) {
        self.real.set(real)
        self.imaginary.set(imaginary)
    }
    
    /// Set value to value of MPComplex (deep copy)
    public func set(_ cval: MPComplex) {
        self.real.set(cval.real)
        self.imaginary.set(cval.imaginary)
    }
    
    //
    // Addition
    //

    /// Addition, return new value
    public static func + (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        let result = MPComplex(prec: lhs.precision)
        mpfr_add(&result.real.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_add(&result.imaginary.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        return result
    }
    
    /// Addition, in-place
    public static func += (lhs: inout MPComplex, rhs: MPComplex) {
        mpfr_add(&lhs.tmp1.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_set(&lhs.real.value, &lhs.tmp1.value, MPFR_RNDN)
        mpfr_add(&lhs.tmp1.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_set(&lhs.imaginary.value, &lhs.tmp1.value, MPFR_RNDN)
    }
    
    //
    // Subtraction
    //
    
    /// Subtraction, return new value
    public static func - (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        let result = MPComplex(prec: lhs.precision)
        mpfr_sub(&result.real.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_sub(&result.imaginary.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        return result
    }
    
    /// Subtraction, in-place
    public static func -= (lhs: inout MPComplex, rhs: MPComplex) {
        let tmp1 = MPFloat(prec: lhs.precision)
        mpfr_sub(&tmp1.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_set(&lhs.real.value, &tmp1.value, MPFR_RNDN)
        mpfr_sub(&tmp1.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_set(&lhs.imaginary.value, &tmp1.value, MPFR_RNDN)
    }
    
    //
    // Multiplication
    //

    /// Multiplication (MPComplex, MPComplex), return new value
    public static func * (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        let result = MPComplex(prec: lhs.precision)
        
        // result.real = lhs.real * rhs.real - lhs.imaginary * rhs.imaginary
        mpfr_mul(&result.tmp1.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_mul(&result.imaginary.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_sub(&result.real.value, &result.tmp1.value, &result.imaginary.value, MPFR_RNDN)

        // result.imaginary = lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        mpfr_mul(&result.tmp1.value, &lhs.real.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_mul(&result.tmp2.value, &lhs.imaginary.value, &rhs.real.value, MPFR_RNDN)
        mpfr_add(&result.imaginary.value, &result.tmp1.value, &result.tmp2.value, MPFR_RNDN)
        
        return result
    }
    
    /// Multiplication (MPComplex, MPFloat), return new value
    public static func * (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        let result = MPComplex(prec: lhs.precision)

        // result.real = lhs.real * rhs
        mpfr_mul(&result.real.value, &lhs.real.value, &rhs.value, MPFR_RNDN)
        
        // result.imaginary = lhs.imaginary * rhs
        mpfr_mul(&result.imaginary.value, &lhs.imaginary.value, &rhs.value, MPFR_RNDN)
        
        return result
    }
    
    /// Multiplication (MPFloat, MPComplex), return new value
    public static func * (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        let result = MPComplex(prec: rhs.precision)

        // result.real = lhs * rhs.real
        mpfr_mul(&result.real.value, &lhs.value, &rhs.real.value, MPFR_RNDN)
        
        // result.imaginary = lhs * rhs.imaginary
        mpfr_mul(&result.imaginary.value, &lhs.value, &rhs.imaginary.value, MPFR_RNDN)
        
        return result
    }
    
    /// Multiplication (in place)
    public static func *= (lhs: inout MPComplex, rhs: MPComplex) {
        // result.real = lhs.real * rhs.real - lhs.imaginary * rhs.imaginary
        mpfr_mul(&lhs.tmp1.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_mul(&lhs.tmp2.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_sub(&lhs.tmp3.value, &lhs.tmp1.value, &lhs.tmp2.value, MPFR_RNDN)

        // result.imaginary = lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        mpfr_mul(&lhs.tmp1.value, &lhs.real.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_mul(&lhs.tmp2.value, &lhs.imaginary.value, &rhs.real.value, MPFR_RNDN)
        mpfr_add(&lhs.imaginary.value, &lhs.tmp1.value, &lhs.tmp2.value, MPFR_RNDN)
        
        mpfr_set(&lhs.real.value, &lhs.tmp3.value, MPFR_RNDN)
    }
    
    /// Multiplication (in place)
    public static func *= (lhs: inout MPComplex, rhs: MPFloat) {
        // lhs.real = lhs.real * rhs
        mpfr_mul(&lhs.real.value, &lhs.real.value, &rhs.value, MPFR_RNDN)
        
        // lhs.imaginary = lhs.imaginary * rhs
        mpfr_mul(&lhs.imaginary.value, &lhs.imaginary.value, &rhs.value, MPFR_RNDN)
    }

    //
    // Division
    //
    
    /// Division: MPComplex, MPComplex
    public static func / (_ lhs: MPComplex, _ rhs: MPComplex) -> MPComplex {
        let result = MPComplex(prec: lhs.precision)

        // tmp3 = rhs.real * rhs.real + rhs.imag * rhs.imag
        mpfr_sqr(&result.tmp1.value, &rhs.real.value, MPFR_RNDN)
        mpfr_sqr(&result.tmp2.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_add(&result.tmp3.value, &result.tmp1.value, &result.tmp2.value, MPFR_RNDN)
        
        // result.real = (lhs.real * rhs.real + lhs.imag * rhs.imag) / tmp3
        mpfr_mul(&result.real.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_mul(&result.tmp1.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_add(&result.tmp2.value, &result.real.value, &result.tmp1.value, MPFR_RNDN)
        mpfr_div(&result.real.value, &result.tmp2.value, &result.tmp3.value, MPFR_RNDN)
        
        // result.imag = (rhs.real * lhs.imag - lhs.real * rhs.imag) / tmp3
        mpfr_mul(&result.imaginary.value, &rhs.real.value, &lhs.imaginary.value, MPFR_RNDN)
        mpfr_mul(&result.tmp1.value, &lhs.real.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_sub(&result.tmp2.value, &result.imaginary.value, &result.tmp1.value, MPFR_RNDN)
        mpfr_div(&result.imaginary.value, &result.tmp2.value, &result.tmp3.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division: MPComplex, MPFloat
    public static func / (_ lhs: MPComplex, _ rhs: MPFloat) -> MPComplex {
        let result = MPComplex(prec: lhs.precision)

        mpfr_ui_div(&result.tmp1.value, 1, &rhs.value, MPFR_RNDN)

        // result.real = lhs.real * tmp1
        mpfr_mul(&result.real.value, &lhs.real.value, &result.tmp1.value, MPFR_RNDN)
        
        // result.imaginary = lhs.imaginary * tmp1
        mpfr_mul(&result.imaginary.value, &lhs.imaginary.value, &rhs.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division: MPFloat, MPComplex
    public static func / (_ lhs: MPFloat, _ rhs: MPComplex) -> MPComplex {
        let result = MPComplex(prec: rhs.precision)

        mpfr_ui_div(&result.tmp1.value, 1, &lhs.value, MPFR_RNDN)

        // result.real = rhs.real * tmp1
        mpfr_mul(&result.real.value, &rhs.real.value, &result.tmp1.value, MPFR_RNDN)
        
        // result.imaginary = rhs.imaginary * tmp1
        mpfr_mul(&result.imaginary.value, &rhs.imaginary.value, &result.tmp1.value, MPFR_RNDN)
        
        return result
    }
    
    /// Division, in-place
    public static func /= (lhs: inout MPComplex, rhs: MPComplex) {
        let result = MPComplex(prec: lhs.precision)

        // tmp3 = rhs.real * rhs.real + rhs.imag * rhs.imag
        mpfr_sqr(&lhs.tmp1.value, &rhs.real.value, MPFR_RNDN)
        mpfr_sqr(&lhs.tmp2.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_add(&lhs.tmp3.value, &lhs.tmp1.value, &lhs.tmp2.value, MPFR_RNDN)
        
        // result.real = (lhs.real * rhs.real + lhs.imag * rhs.imag) / tmp3
        mpfr_mul(&result.real.value, &lhs.real.value, &rhs.real.value, MPFR_RNDN)
        mpfr_mul(&lhs.tmp1.value, &lhs.imaginary.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_add(&lhs.tmp2.value, &result.real.value, &lhs.tmp1.value, MPFR_RNDN)
        mpfr_div(&result.real.value, &lhs.tmp2.value, &lhs.tmp3.value, MPFR_RNDN)
        
        // result.imag = (rhs.real * lhs.imag - lhs.real * rhs.imag) / tmp3
        mpfr_mul(&result.imaginary.value, &rhs.real.value, &lhs.imaginary.value, MPFR_RNDN)
        mpfr_mul(&lhs.tmp1.value, &lhs.real.value, &rhs.imaginary.value, MPFR_RNDN)
        mpfr_sub(&lhs.tmp2.value, &result.imaginary.value, &lhs.tmp1.value, MPFR_RNDN)
        mpfr_div(&lhs.imaginary.value, &lhs.tmp2.value, &lhs.tmp3.value, MPFR_RNDN)
        
        mpfr_set(&lhs.real.value, &result.real.value, MPFR_RNDN)
    }
   
    /// Division (in place)
    public static func /= (lhs: inout MPComplex, rhs: MPFloat) {
        mpfr_ui_div(&lhs.tmp1.value, 1, &rhs.value, MPFR_RNDN)

        // result.real = lhs.real * tmp1
        mpfr_mul(&lhs.real.value, &lhs.real.value, &lhs.tmp1.value, MPFR_RNDN)
        
        // result.imaginary = lhs.imaginary * tmp1
        mpfr_mul(&lhs.imaginary.value, &lhs.imaginary.value, &lhs.tmp1.value, MPFR_RNDN)
    }
    
    //
    // Comparision
    //
    
    public static func == (lhs: MPComplex, rhs: MPComplex) -> Bool {
        return lhs.real == rhs.real && lhs.imaginary == rhs.imaginary
    }

    //
    // Mathematic functions
    //
    
    /// Square
    public func square() -> MPComplex {
        let result = MPComplex(prec: precision)

        mpfr_sqr(&tmp1.value, &self.real.value, MPFR_RNDN)
        mpfr_sqr(&tmp2.value, &self.imaginary.value, MPFR_RNDN)
        mpfr_sub(&result.real.value, &tmp1.value, &tmp2.value, MPFR_RNDN)
        
        mpfr_mul_ui(&tmp1.value, &self.real.value, 2, MPFR_RNDN)
        mpfr_mul(&result.imaginary.value, &tmp1.value, &self.imaginary.value, MPFR_RNDN)
        
        return result
    }
    
    /// Norm / magnitude
    public func norm () -> MPFloat {
        let result = MPFloat(prec: precision)

        mpfr_sqr(&tmp1.value, &self.real.value, MPFR_RNDN)
        mpfr_sqr(&tmp2.value, &self.imaginary.value, MPFR_RNDN)
        mpfr_add(&result.value, &tmp1.value, &tmp2.value, MPFR_RNDN)
        
        return result
    }
    
    /// Absolute value
    public func abs () -> MPFloat {
        let result = MPFloat(prec: precision)

        mpfr_sqr(&tmp1.value, &self.real.value, MPFR_RNDN)
        mpfr_sqr(&tmp2.value, &self.imaginary.value, MPFR_RNDN)
        mpfr_add(&tmp3.value, &tmp1.value, &tmp2.value, MPFR_RNDN)
        mpfr_sqrt(&result.value, &tmp3.value, MPFR_RNDN)
        
        return result
    }
    
}

