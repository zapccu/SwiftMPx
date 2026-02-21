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

infix operator <- : AssignmentPrecedence

public class MPFloat : Comparable, CustomStringConvertible {

    // The value
    public var value: mpfr_t
    
    // Temporary value, prevent memory allocation
    public var tmp: mpfr_t

    // Precision (default is 128 bit)
    public let precision: Int32

    init(prec: Int32 = 128) {
        precision = prec
        value = mpfr_t()
        mpfr_init2(&value, mpfr_prec_t(prec))
        tmp = mpfr_t()
        mpfr_init2(&tmp, mpfr_prec_t(prec))
    }
    
    /// Initialize a value with a String
    public init(_ string: String = "0", precision: Int32 = 128) {
        self.precision = precision
        
        self.value = mpfr_t()
        mpfr_init2(&self.value, mpfr_prec_t(precision))
        tmp = mpfr_t()
        mpfr_init2(&tmp, mpfr_prec_t(precision))
        
        // Store value
        mpfr_set_str(&self.value, string, 10, MPFR_RNDN)
    }
    
    /// Initialize value with a Double
    public init(_ dval: Double, precision: Int32 = 128) {
        self.precision = precision
        self.value = mpfr_t()
        mpfr_init2(&self.value, mpfr_prec_t(precision))
        
        mpfr_set_d(&self.value, dval, MPFR_RNDN)
        
        tmp = mpfr_t()
        mpfr_init2(&tmp, mpfr_prec_t(precision))
    }

    /// Free memory
    deinit {
        mpfr_clear(&self.value)
        mpfr_clear(&self.tmp)
    }
    
    public var description: String {
        return self.toString()
    }
    
    /// Return a copy of a value
    /// Use y = x.copy() instead of y = x to create a new instance
    func copy() -> MPFloat {
        let newObj = MPFloat(prec: self.precision)
        mpfr_set(&newObj.value, &self.value, MPFR_RNDN)
        return newObj
    }
    
    /// Set value to string
    public func set(_ string: String) {
        mpfr_set_str(&self.value, string, 10, MPFR_RNDN)
    }
    
    /// Set value to string
    public static func <- (lhs: MPFloat, _ rhs: String) {
        mpfr_set_str(&lhs.value, rhs, 10, MPFR_RNDN)
    }

    /// Set value to Double
    public func set(_ dval: Double) {
        mpfr_set_d(&self.value, dval, MPFR_RNDN)
    }
    
    /// Set value to Double
    public static func <- (_ lhs: MPFloat, _ rhs: Double) {
        mpfr_set_d(&lhs.value, rhs, MPFR_RNDN)
    }
    /// Set value to value of MPFloat (deep copy)
    public func set(_ other: MPFloat) {
        mpfr_set(&self.value, &other.value, MPFR_RNDN)
    }
    
    /// Set value to value of MPFloat (deep copy)
    public static func <- (lhs: MPFloat, rhs: MPFloat) {
        mpfr_set(&lhs.value, &rhs.value, MPFR_RNDN)
    }
    
    /// Convert value to Double
    public func toDouble() -> Double {
        return mpfr_get_d(&self.value, MPFR_RNDN)
    }

    /// Convert value to String
    public func toString(digits: Int = 32) -> String {
        var exp: mpfr_exp_t = 0
        // MPFR liefert die Ziffern (ohne Punkt) und den Exponenten separat
        guard let cStr = mpfr_get_str(nil, &exp, 10, digits, &self.value, MPFR_RNDN) else {
            return "NaN"
        }
        
        var rawDigits = String(cString: cStr)
        mpfr_free_str(cStr)
        
        if rawDigits.isEmpty || rawDigits == "0" { return "0" }
        
        // Vorzeichen extrahieren
        let isNegative = rawDigits.hasPrefix("-")
        if isNegative { rawDigits.removeFirst() }
        
        var result = isNegative ? "-" : ""
        
        // Fallunterscheidung basierend auf dem Exponenten
        if exp > 0 && exp <= rawDigits.count {
            // Fall 1: Punkt liegt innerhalb der Ziffern (z.B. 123.45)
            let dotIndex = Int(exp)
            result += rawDigits.prefix(dotIndex)
            let suffix = rawDigits.dropFirst(dotIndex)
            if !suffix.isEmpty {
                result += "." + suffix
            }
        } else if exp > 0 {
            // Fall 2: Zahl ist größer als die Ziffernanzahl (z.B. 1234500)
            result += rawDigits
            result += String(repeating: "0", count: Int(exp) - rawDigits.count)
        } else {
            // Fall 3: Sehr kleine Zahl (z.B. 0.000123)
            result += "0."
            result += String(repeating: "0", count: abs(Int(exp)))
            result += rawDigits
        }
        
        // Trimmen von unnötigen Nullen am Ende (optional)
        if result.contains(".") {
            while result.last == "0" { result.removeLast() }
            if result.last == "." { result.removeLast() }
        }
        
        return result
    }
    
    //
    // Addition
    //
    
    /// Addition, return new value (additional memory needed)
    public static func + (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_add(&result.value, &lhs.value, &rhs.value, MPFR_RNDN)
        return result
    }
    
    /// Addition (in place)
    public static func += (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_add(&lhs.tmp, &lhs.value, &rhs.value, MPFR_RNDN)
        mpfr_set(&lhs.value, &lhs.tmp, MPFR_RNDN)
    }
    
    //
    // Subtraction
    //
    
    /// Subtraction, return new value (additional memory needed)
    public static func - (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_sub(&result.value, &lhs.value, &rhs.value, MPFR_RNDN)
        return result
    }
    
    /// Subtraction (in place)
    public static func -= (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_sub(&lhs.tmp, &lhs.value, &rhs.value, MPFR_RNDN)
        mpfr_set(&lhs.value, &lhs.tmp, MPFR_RNDN)
    }

    //
    // Multiplication
    //
    
    /// Multiplication: MPFloat with MPFloat
    public static func * (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_mul(&result.value, &lhs.value, &rhs.value, MPFR_RNDN)
        return result
    }
    
    /// Multiplication: Double with MPFloat
    public static func * (lhs: Double, rhs: MPFloat) -> MPFloat {
        let res = MPFloat(prec: rhs.precision)
        mpfr_mul_d(&res.value, &rhs.value, lhs, MPFR_RNDN)
        return res
    }
    
    /// Multiplication: MPFloat with Double
    public static func * (lhs: MPFloat, rhs: Double) -> MPFloat {
        let res = MPFloat(prec: lhs.precision)
        mpfr_mul_d(&res.value, &lhs.value, rhs, MPFR_RNDN)
        return res
    }
    
    /// Inplace multiplication with MPFloat
    public static func *= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_mul(&lhs.tmp, &lhs.value, &rhs.value, MPFR_RNDN)
        mpfr_set(&lhs.value, &lhs.tmp, MPFR_RNDN)
    }
    
    /// Inplace multiplication with Double
    public static func *= (lhs: inout MPFloat, rhs: Double) {
        mpfr_mul_d(&lhs.tmp, &lhs.value, rhs, MPFR_RNDN)
        mpfr_set(&lhs.value, &lhs.tmp, MPFR_RNDN)
    }

    //
    // Division
    //
    
    /// Divison: MPFloat by MPFloat
    public static func / (_ lhs: MPFloat, _ rhs: MPFloat) -> MPFloat {
        let result = MPFloat(precision: lhs.precision)
        mpfr_div(&result.value, &lhs.value, &rhs.value, MPFR_RNDN)
        return result
    }
    
    /// Division: Double by MPFloat
    public static func / (lhs: Double, rhs: MPFloat) -> MPFloat {
        let res = MPFloat(prec: rhs.precision)
        mpfr_d_div(&res.value, lhs, &rhs.value, MPFR_RNDN)
        return res
    }
    
    /// Division: MPFloat by Double
    public static func / (lhs: MPFloat, rhs: Double) -> MPFloat {
        let res = MPFloat(prec: lhs.precision)
        mpfr_div_d(&res.value, &lhs.value, rhs, MPFR_RNDN)
        return res
    }
    
    /// Division: in-place by MPFloat
    public static func /= (_ lhs: inout MPFloat, _ rhs: MPFloat) {
        mpfr_div(&lhs.tmp, &lhs.value, &rhs.value, MPFR_RNDN)
        mpfr_set(&lhs.value, &lhs.tmp, MPFR_RNDN)
    }
    
    /// Division: in-place by Double
    public static func /= (lhs: inout MPFloat, rhs: Double) {
        mpfr_div_d(&lhs.tmp, &lhs.value, rhs, MPFR_RNDN)
        mpfr_set(&lhs.value, &lhs.tmp, MPFR_RNDN)
    }
    
    //
    // Comparision
    //
    
    public static func == (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.value, &rhs.value) == 0
    }

    public static func < (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.value, &rhs.value) < 0
    }

    public static func < (lhs: MPFloat, rhs: Double) -> Bool {
        return mpfr_cmp_d(&lhs.value, rhs) < 0
    }

    public static func > (lhs: MPFloat, rhs: MPFloat) -> Bool {
        return mpfr_cmp(&lhs.value, &rhs.value) > 0
    }

    public static func > (lhs: MPFloat, rhs: Double) -> Bool {
        return mpfr_cmp_d(&lhs.value, rhs) > 0
    }
    
    //
    // Mathematic functions
    //
    
    /// Square root, return new value
    public func sqrt() -> MPFloat {
        let res = MPFloat(prec: precision)
        mpfr_sqrt(&res.value, &self.value, MPFR_RNDN)
        return res
    }
    
    /// Square, return new value
    public func square() -> MPFloat {
        let res = MPFloat(prec: precision)
        mpfr_sqr(&res.value, &self.value, MPFR_RNDN)
        return res
    }
    
    /// Logarithm, return new value
    public func log() -> MPFloat {
        let res = MPFloat(prec: precision)
        mpfr_log(&res.value, &self.value, MPFR_RNDN)
        return res
    }

}

extension Double {
    /// Convert MPFloat to Double
    init(_ mpf: MPFloat) {
        self = mpf.toDouble()
    }
}


