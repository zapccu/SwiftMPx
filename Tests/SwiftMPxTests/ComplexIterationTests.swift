//
//  ComplexIterationTests.swift
//  SwiftMPx
//
//  Tests for formDerivativeStep, formMandelbrotStep and the ComplexIteration protocol.
//

import Foundation
import Testing
@testable import SwiftMPx

private let p = 192

private func c(_ re: Double, _ im: Double, precision: Int = p) -> MPComplex {
    MPComplex(re, im, precision: precision)
}

/// Check that a and b agree to at least `bits` bits relative to the magnitude of b
private func agree(_ a: MPComplex, _ b: MPComplex, bits: Int) -> Bool {
    let err = MPComplex.abs(a - b)
    if err.isZero() { return true }
    let mag = MPComplex.abs(b)
    return err.exponent <= mag.exponent - bits
}

/// Generic iteration, as used in an app: only uses the ComplexIteration protocol
private func iterate<T: ComplexIteration>(z: T, d: T, c: T, precision: Int, steps: Int) -> (z: T, d: T) {
    var z = z, d = d
    var scratch = T.makeScratch(precision: precision)
    for _ in 0..<steps {
        T.formMandelbrotStep(z: &z, d: &d, c: c, scratch: &scratch)
    }
    return (z, d)
}

@Suite("Derivative step")
struct DerivativeStepTests {

    @Test func singleStepExact() {
        // D = 1 + 2i, Z = 3 + 4i: D·Z = -5 + 10i, 2·D·Z + 1 = -9 + 20i
        var d = c(1, 2)
        var scratch = MPFloat(precision: p)
        d.formDerivativeStep(z: c(3, 4), scratch: &scratch)
        #expect(d == c(-9, 20))
        #expect(d.real.precision == p)
        #expect(d.imaginary.precision == p)
    }

    @Test func withoutScratch() {
        var d = c(1, 2)
        d.formDerivativeStep(z: c(3, 4))
        #expect(d == c(-9, 20))
    }

    @Test func derivativeWithItself() {
        // D = Z = 1 + 2i: 2·(1 + 2i)² + 1 = 2·(-3 + 4i) + 1 = -5 + 8i
        var d = c(1, 2)
        d.formDerivativeStep(z: d)
        #expect(d == c(-5, 8))
    }

    @Test func doesNotModifyCopies() {
        let a = c(1, 2)
        var d = a
        let z = d                       // shares storage with d and a
        var scratch = MPFloat(precision: p)
        d.formDerivativeStep(z: z, scratch: &scratch)
        #expect(a == c(1, 2))
        #expect(z == c(1, 2))
        #expect(d == c(-5, 8))
    }

    @Test func scratchPrecisionIsAdjusted() {
        var d = c(1, 2)
        var lowScratch = MPFloat(precision: 24)
        d.formDerivativeStep(z: c(3, 4), scratch: &lowScratch)
        #expect(d == c(-9, 20))
        #expect(d.real.precision == p)
    }

    @Test func matchesOperatorsWithinRounding() {
        // Compare with a reference computed with operators at 128 bits higher precision.
        // The fused implementation must agree to (nearly) the full working precision.
        let cc = MPComplex("-0.1", "0.123456789", precision: p)
        let ccRef = MPComplex("-0.1", "0.123456789", precision: p + 128)
        let two = MPFloat(2.0, precision: p + 128)

        var z = c(0, 0), d = c(1, 0)
        var zRef = c(0, 0, precision: p + 128), dRef = c(1, 0, precision: p + 128)
        var scratch = MPFloat(precision: p)

        for _ in 0..<500 {
            MPComplex.formMandelbrotStep(z: &z, d: &d, c: cc, scratch: &scratch)
            dRef = two * dRef * zRef + MPComplex(1.0, 0.0, precision: p + 128)
            zRef = zRef * zRef + ccRef
        }
        #expect(agree(z, zRef, bits: p - 16))
        #expect(agree(d, dRef, bits: p - 16))
    }
}

@Suite("Mandelbrot step")
struct MandelbrotStepTests {

    @Test func usesCurrentZForDerivative() {
        // Z0 = 1 + 2i, D0 = 1, c = 1 + 1i
        // D1 = 2·D0·Z0 + 1 = 3 + 4i   (with Z0, not Z1)
        // Z1 = Z0² + c = -2 + 6i
        var z = c(1, 2), d = c(1, 0)
        var scratch = MPFloat(precision: p)
        MPComplex.formMandelbrotStep(z: &z, d: &d, c: c(1, 1), scratch: &scratch)
        #expect(d == c(3, 4))
        #expect(z == c(-2, 6))
    }

    @Test func matchesSeparateSteps() {
        let cc = MPComplex("-0.743643887037158704752191506114774", "0.131825904205311970493132056385139", precision: p)
        var z1 = c(0, 0), d1 = c(1, 0)
        var z2 = c(0, 0), d2 = c(1, 0)
        var s1 = MPFloat(precision: p), s2 = MPFloat(precision: p), s3 = MPFloat(precision: p)

        for _ in 0..<200 {
            MPComplex.formMandelbrotStep(z: &z1, d: &d1, c: cc, scratch: &s1)
            d2.formDerivativeStep(z: z2, scratch: &s2)
            z2.formSquareAdd(cc, scratch: &s3)
        }
        #expect(z1 == z2)
        #expect(d1 == d2)
    }

    @Test func genericCodeUsesMPComplexImplementation() {
        // The generic function must produce exactly the same results as the direct calls.
        // If the protocol functions were not requirements, the generic code could not call them at all
        // or would use a different implementation.
        let cc = MPComplex("-0.1", "0.123456789", precision: p)
        let (zg, dg) = iterate(z: c(0, 0), d: c(1, 0), c: cc, precision: p, steps: 300)

        var z = c(0, 0), d = c(1, 0)
        var scratch = MPFloat(precision: p)
        for _ in 0..<300 {
            MPComplex.formMandelbrotStep(z: &z, d: &d, c: cc, scratch: &scratch)
        }
        #expect(zg == z)
        #expect(dg == d)
    }

    @Test func makeScratchHasRequestedPrecision() {
        let s = MPComplex.makeScratch(precision: 333)
        #expect(s.precision == 333)
    }
}
