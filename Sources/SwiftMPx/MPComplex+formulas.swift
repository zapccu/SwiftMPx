//
//  MPComplex+formulas.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 24.10.26.
//


import Foundation
import CMPFR


//
// Extend MPComplex by optimized formulas
//
extension MPComplex {
    
    //
    // In-place iteration (no allocations)
    //
    
    /// Create a reusable scratch value. Call once before the iteration loop and reuse it.
    /// - Parameter precision: Precision in bits (ignored by fixed precision types)
    public static func makeScratch(precision: Int) -> MPFloat {
        MPFloat(precision: precision)
    }
    
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
    
}
