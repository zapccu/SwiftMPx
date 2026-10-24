//
//  ComplexIteration.swift
//  SwiftMPx
//
//  Protocol for allocation-free in-place iteration steps, so that generic iteration code can use
//  the optimized MPFR implementations of MPComplex and plain arithmetic for Complex<Double>.
//

import Foundation

/// In-place iteration steps for complex numbers.
///
/// All functions are protocol **requirements**. Generic code (`func iterate<T: ComplexIteration>`)
/// therefore calls the implementation of the concrete type. If they were only defined in a protocol
/// extension, generic code would always call the extension version and silently ignore the
/// optimized implementation of MPComplex.
///
/// Usage in a generic iteration:
/// ```
/// var scratch = T.makeScratch(precision: p)
/// for _ in 0..<maxIter {
///     T.formMandelbrotStep(z: &z, d: &d, c: c, scratch: &scratch)   // D = 2·D·Z + 1, Z = Z² + c
/// }
/// ```
///
/// Conformance for Complex<Double> (swift-numerics), to be added in the app.
/// With specialization (-O, concrete type known) all functions are inlined and the empty scratch
/// value disappears, so there is no overhead compared to `z = z * z + c`:
/// ```
/// extension Complex: ComplexIteration where RealType == Double {
///     public typealias Scratch = Void
///
///     @inline(__always)
///     public static func makeScratch(precision: Int) -> Void { () }
///
///     @inline(__always)
///     public mutating func formSquareAdd(_ c: Self, scratch: inout Void) {
///         self = Complex(real * real - imaginary * imaginary + c.real,
///                        2 * real * imaginary + c.imaginary)
///     }
///
///     @inline(__always)
///     public mutating func formDerivativeStep(z: Self, scratch: inout Void) {
///         self = Complex(2 * (real * z.real - imaginary * z.imaginary) + 1,
///                        2 * (real * z.imaginary + imaginary * z.real))
///     }
/// }
/// ```
public protocol ComplexIteration {

    /// Type of temporary values used by the in-place functions (MPFloat for MPComplex, Void for Double)
    associatedtype Scratch

    /// Create a scratch value. Call once before the iteration loop and reuse it.
    /// - Parameter precision: Precision in bits (ignored by fixed precision types)
    static func makeScratch(precision: Int) -> Scratch

    /// z = z² + c, in place
    mutating func formSquareAdd(_ c: Self, scratch: inout Scratch)

    /// D = 2·D·Z + 1, in place. Must be called with Z of the current iteration (before formSquareAdd)
    mutating func formDerivativeStep(z: Self, scratch: inout Scratch)

    /// One Mandelbrot iteration step including derivative, in the correct order:
    /// D = 2·D·Z + 1 (with the current Z), then Z = Z² + c.
    /// A default implementation is provided.
    static func formMandelbrotStep(z: inout Self, d: inout Self, c: Self, scratch: inout Scratch)
}

extension ComplexIteration {

    @inline(__always)
    public static func formMandelbrotStep(z: inout Self, d: inout Self, c: Self, scratch: inout Scratch) {
        d.formDerivativeStep(z: z, scratch: &scratch)
        z.formSquareAdd(c, scratch: &scratch)
    }
}

extension MPComplex: ComplexIteration {

    public typealias Scratch = MPFloat

    public static func makeScratch(precision: Int) -> MPFloat {
        MPFloat(precision: precision)
    }

    // formSquareAdd(_:scratch:) and formDerivativeStep(z:scratch:) are implemented in MPComplex.swift
}
