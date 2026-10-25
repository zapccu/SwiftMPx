//
//  PointerAccessTests.swift
//  SwiftMPx
//
//  Tests for the public pointer API (ptr / mutablePtr) and the storage based on the MPFR
//  custom interface. The extension below uses only public API, like an application would.
//

import Foundation
import Testing
import CMPFR
import SwiftMPx

private let p = 192

private func c(_ re: Double, _ im: Double, precision: Int = p) -> MPComplex {
    MPComplex(re, im, precision: precision)
}

// In-place iteration functions as implemented in an application (only public API)
private extension MPComplex {

    mutating func testFormSquareAdd(_ c: MPComplex, scratch: inout MPFloat) {
        if scratch.precision != real.precision {
            scratch = MPFloat(precision: real.precision)
        }
        // scratch = a² - b²
        mpfr_fmms(scratch.mutablePtr, real.ptr, real.ptr, imaginary.ptr, imaginary.ptr, MPFR_RNDN)
        // imaginary = 2ab + c.imaginary
        mpfr_mul(imaginary.mutablePtr, real.ptr, imaginary.ptr, MPFR_RNDN)
        mpfr_mul_2ui(imaginary.mutablePtr, imaginary.ptr, 1, MPFR_RNDN)
        mpfr_add(imaginary.mutablePtr, imaginary.ptr, c.imaginary.ptr, MPFR_RNDN)
        // real = a² - b² + c.real
        mpfr_add(real.mutablePtr, scratch.ptr, c.real.ptr, MPFR_RNDN)
    }

    mutating func testFormDerivativeStep(z: MPComplex, scratch: inout MPFloat) {
        if scratch.precision != real.precision {
            scratch = MPFloat(precision: real.precision)
        }
        mpfr_fmms(scratch.mutablePtr, real.ptr, z.real.ptr, imaginary.ptr, z.imaginary.ptr, MPFR_RNDN)
        mpfr_fmma(imaginary.mutablePtr, real.ptr, z.imaginary.ptr, imaginary.ptr, z.real.ptr, MPFR_RNDN)
        mpfr_mul_2ui(imaginary.mutablePtr, imaginary.ptr, 1, MPFR_RNDN)
        mpfr_mul_2ui(scratch.mutablePtr, scratch.ptr, 1, MPFR_RNDN)
        mpfr_add_ui(scratch.mutablePtr, scratch.ptr, 1, MPFR_RNDN)
        swap(&real, &scratch)
    }
}

@Suite("Pointer access")
struct PointerAccessTests {

    @Test func newValueIsNaNWithRequestedPrecision() {
        let x = MPFloat(precision: 333)
        #expect(x.isNaN)
        #expect(x.precision == 333)
        #expect(mpfr_get_prec(x.ptr) == 333)
    }

    @Test func readAccessWorksForLetConstants() {
        let a = MPFloat(1.5, precision: p)
        let b = MPFloat(2.25, precision: p)
        var r = MPFloat(precision: p)
        mpfr_add(r.mutablePtr, a.ptr, b.ptr, MPFR_RNDN)
        #expect(r == 3.75)
    }

    @Test func mutablePtrCopiesSharedStorage() {
        let a = MPFloat(1.0, precision: p)
        var b = a
        mpfr_add_ui(b.mutablePtr, b.ptr, 1, MPFR_RNDN)
        #expect(a == 1.0)
        #expect(b == 2.0)
    }

    @Test func outputMayBeInput() {
        var x = MPFloat(3.0, precision: p)
        mpfr_mul(x.mutablePtr, x.ptr, x.ptr, MPFR_RNDN)
        mpfr_mul_2ui(x.mutablePtr, x.ptr, 1, MPFR_RNDN)
        #expect(x == 18.0)
    }

    @Test func precisionChangeRoundsAndKeepsCopies() {
        let a = MPFloat.PI(precision: 1000)
        var b = a
        b.precision = 53
        #expect(b.toDouble() == Double.pi)
        #expect(mpfr_get_prec(b.ptr) == 53)
        #expect(mpfr_get_prec(a.ptr) == 1000)
        #expect(a == MPFloat.PI(precision: 1000))

        // Operations after a precision change use the new storage
        b += 1.0
        #expect(b.toDouble() == Double.pi + 1.0)
    }

    @Test func largePrecision() {
        let x = MPFloat.PI(precision: 100_000)
        let y = MPFloat.sqrt(MPFloat.square(x))
        #expect(MPFloat.abs(x - y).exponent < -99_000 || (x - y).isZero)
    }

    @Test func subtractionRealMinusComplex() {
        // 5 - (2 + 3i) = 3 - 3i
        let r = MPFloat(5.0, precision: p) - c(2, 3)
        #expect(r == c(3, -3))
    }
}

@Suite("Application style iteration")
struct ApplicationIterationTests {

    @Test func squareAddMatchesOperators() {
        let cc = MPComplex("-0.743643887037158704752191506114774", "0.131825904205311970493132056385139", precision: p)
        var a = c(0, 0), b = c(0, 0)
        var scratch = MPFloat(precision: p)
        for _ in 0..<500 {
            a = MPComplex.square(a) + cc
            b.testFormSquareAdd(cc, scratch: &scratch)
        }
        #expect(a == b)
    }

    @Test func squareAddWithItselfAndCopies() {
        let original = c(1, 2)
        var z = original
        var scratch = MPFloat(precision: p)
        z.testFormSquareAdd(z, scratch: &scratch)    // z² + z = (-3 + 4i) + (1 + 2i)
        #expect(z == c(-2, 6))
        #expect(original == c(1, 2))
    }

    @Test func derivativeStep() {
        // D = 1 + 2i, Z = 3 + 4i: 2·D·Z + 1 = -9 + 20i
        var d = c(1, 2)
        let z = c(3, 4)
        var scratch = MPFloat(precision: p)
        d.testFormDerivativeStep(z: z, scratch: &scratch)
        #expect(d == c(-9, 20))
        #expect(z == c(3, 4))
    }

    @Test func mandelbrotStepWithSharedScratch() {
        // Z0 = 1 + 2i, D0 = 1, c = 1 + 1i: D1 = 3 + 4i, Z1 = (-3 + 4i) + (1 + 1i) = -2 + 5i
        var z = c(1, 2), d = c(1, 0)
        var scratch = MPFloat(precision: p)
        d.testFormDerivativeStep(z: z, scratch: &scratch)
        z.testFormSquareAdd(c(1, 1), scratch: &scratch)
        #expect(d == c(3, 4))
        #expect(z == c(-2, 5))
    }
}
