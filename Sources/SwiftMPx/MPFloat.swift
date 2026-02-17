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

public class MPFloat : Comparable {

    // The value
    var value: mpfr_t
    
    // Precision (default is 128 bit)
    public let precision: Int32

    init(prec: Int32 = 128) {
        precision = prec
        value = mpfr_t()
        mpfr_init2(&value, mpfr_prec_t(prec))
    }
    
    /// Initialize a value with a String
    public init(_ string: String = "0", precision: Int32 = 128) {
        self.precision = precision
        self.value = mpfr_t()

        // Allocate memory
        mpfr_init2(&self.value, mpfr_prec_t(precision))
        
        // Store value
        mpfr_set_str(&self.value, string, 10, MPFR_RNDN)
    }
    
    /// Initialize value with a Double
    public init(_ dval: Double, precision: Int32 = 128) {
        self.precision = precision
        self.value = mpfr_t()
        
        mpfr_init2(&self.value, mpfr_prec_t(precision))
        mpfr_set_d(&self.value, dval, MPFR_RNDN)
    }

    /// Free memory
    deinit {
        mpfr_clear(&self.value)
    }
    
    /// Return a copy of a value
    /// Use y = x.copy() instead of y = x
    func copy() -> MPFloat {
        let newObj = MPFloat(prec: self.precision)
        mpfr_set(&newObj.value, &self.value, MPFR_RNDN)
        return newObj
    }
    
    /// Set value to string
    public func set(_ string: String) {
        mpfr_set_str(&self.value, string, 10, MPFR_RNDN)
    }
    
    /// Set value to Double
    public func set(_ dval: Double) {
        mpfr_set_d(&self.value, dval, MPFR_RNDN)
    }
        
    /// Set value to value of MPFloat (deep copy)
    public func set(from other: MPFloat) {
        mpfr_set(&self.value, &other.value, MPFR_RNDN)
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
    static func += (lhs: inout MPFloat, rhs: MPFloat) {
        mpfr_add(&lhs.value, &lhs.value, &rhs.value, MPFR_RNDN)
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
        mpfr_sub(&lhs.value, &lhs.value, &rhs.value, MPFR_RNDN)
    }

    //
    // Multiplication
    //
    
    /// Multiplication, return new value (additional memory needed)
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
        mpfr_mul(&lhs.value, &lhs.value, &rhs.value, MPFR_RNDN)
    }
    
    /// Inplace multiplication with Double
    public static func *= (lhs: inout MPFloat, rhs: Double) {
        mpfr_mul_d(&lhs.value, &lhs.value, rhs, MPFR_RNDN)
    }

    /// Square, returns new value (additional memory needed)
    public static func squared(_ lhs: MPFloat) -> MPFloat {
        let res = MPFloat(prec: lhs.precision)
        mpfr_pow_ui(&res.value, &lhs.value, 2, MPFR_RNDN)
        return res
    }
    
    /// Inplace square
    public func squared() {
        mpfr_pow_ui(&self.value, &self.value, 2, MPFR_RNDN)
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

    
    /*
     In der  gezeigten Funktion werden tmp1 und tmp2 als inout-Parameter übergeben. Das ist der "Profi-Trick": Du erstellst diese Hilfsvariablen einmalig vor der Schleife und reichst sie nur herum. Dadurch findet innerhalb der 10.000 Iterationen deines Referenz-Orbits keine einzige Speicherreservierung statt.

    func iterateInPlace(zRe: inout HighPrec, zIm: inout HighPrec, cRe: HighPrec, cIm: HighPrec, tmp1: inout HighPrec, tmp2: inout HighPrec) {
        // Formel:
        // newRe = zRe^2 - zIm^2 + cRe
        // newIm = 2 * zRe * zIm + cIm
        
        // 1. tmp1 = zRe^2
        mpfr_pow_ui(&tmp1.value, &zRe.value, 2, MPFR_RNDN)
        
        // 2. tmp2 = zIm^2
        mpfr_pow_ui(&tmp2.value, &zIm.value, 2, MPFR_RNDN)
        
        // 3. Berechne Imaginärteil: zIm = 2 * zRe * zIm + cIm
        // Wir nutzen mpfr_mul_si für den Faktor 2 (sehr schnell)
        mpfr_mul(&zIm.value, &zRe.value, &zIm.value, MPFR_RNDN)
        mpfr_mul_si(&zIm.value, &zIm.value, 2, MPFR_RNDN)
        zIm += cIm
        
        // 4. Berechne Realteil: zRe = tmp1 - tmp2 + cRe
        mpfr_sub(&zRe.value, &tmp1.value, &tmp2.value, MPFR_RNDN)
        zRe += cRe
    }
     
     */
}

extension Double {
    /// Convert MPFloat to Double
    init(_ mpf: MPFloat) {
        self = mpf.toDouble()
    }
}


/*
 Referenz Orbit
 
 func generateReferenceOrbit(cRe: String, cIm: String, maxIter: Int) -> [HighPrecComplex] {
     let re = HighPrec(cRe)
     let im = HighPrec(cIm)
     var zRe = HighPrec("0.0")
     var zIm = HighPrec("0.0")
     
     // Unsere Arbeits-Variablen (Recycling!)
     var t1 = HighPrec()
     var t2 = HighPrec()
     
     var orbit: [HighPrecComplex] = []

     for _ in 0..<maxIter {
         // 1. Aktuellen Punkt speichern (muss kopiert werden!)
         orbit.append(HighPrecComplex(re: zRe.copy(), im: zIm.copy()))
         
         // 2. Escape Check
         if checkEscapeOptimized(zRe: zRe, zIm: zIm, tmp1: &t1, tmp2: &t2) {
             break
         }
         
         // 3. Nächster Schritt (In-Place)
         iterateInPlace(zRe: &zRe, zIm: &zIm, cRe: re, cIm: im, tmp1: &t1, tmp2: &t2)
     }
     return orbit
 }
 
 
 struct ComplexDouble {
     var re: Double
     var im: Double
 }

 func calculateDeltaPixel(deltaC: ComplexDouble, referenceOrbit: [HighPrecComplex], maxIter: Int) -> Int {
     var dzRe = deltaC.re
     var dzIm = deltaC.im
     
     for n in 0..<min(referenceOrbit.count - 1, maxIter) {
         // Hol den Referenzpunkt aus dem 128-Bit Speicher und wandle ihn in Double
         let ZnRe = referenceOrbit[n].re.toDouble()
         let ZnIm = referenceOrbit[n].im.toDouble()
         
         // Die Perturbations-Formel:
         // dz_next = 2 * Zn * dz + dz^2 + dc
         
         // 1. (2 * Zn * dz)
         let twoZn_dz_Re = 2 * (ZnRe * dzRe - ZnIm * dzIm)
         let twoZn_dz_Im = 2 * (ZnRe * dzIm + ZnIm * dzRe)
         
         // 2. (dz^2)
         let dz2Re = dzRe * dzRe - dzIm * dzIm
         let dz2Im = 2 * dzRe * dzIm
         
         // 3. Alles zusammenfügen
         dzRe = twoZn_dz_Re + dz2Re + deltaC.re
         dzIm = twoZn_dz_Im + dz2Im + deltaC.im
         
         // 4. Escape Check auf Delta-Basis
         // Achtung: Wir prüfen, ob der absolute Punkt (Z + dz) entkommt!
         let totalZRe = ZnRe + dzRe
         let totalZIm = ZnIm + dzIm
         
         if (totalZRe * totalZRe + totalZIm * totalZIm) > 4.0 {
             return n // Punkt ist entkommen
         }
     }
     
     return maxIter // Punkt ist (wahrscheinlich) in der Menge
 }
 */
