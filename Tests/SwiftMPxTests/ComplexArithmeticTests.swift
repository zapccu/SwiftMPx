//
//  ComplexArithmeticTests.swift
//  SwiftMPx
//
//  Tests for the MPComplex arithmetic based on mpfr_fmma / mpfr_fmms and for the
//  in-place iteration API (formSquareAdd, formSquare).
//

import Foundation
import Testing
@testable import SwiftMPx

private let p = 192

private func c(_ re: Double, _ im: Double) -> MPComplex {
    MPComplex(re, im, precision: p)
}

@Suite("Complex arithmetic")
struct ComplexArithmeticTests {

    @Test func multiplication() {
        // (1 + 2i)(3 + 4i) = -5 + 10i
        #expect(c(1, 2) * c(3, 4) == c(-5, 10))
    }

    @Test func multiplicationInPlace() {
        var z = c(1, 2)
        z *= c(3, 4)
        #expect(z == c(-5, 10))
    }

    @Test func multiplicationInPlaceWithItself() {
        // z *= z must use the original value of z for both factors
        var z = c(1, 2)
        z *= z
        #expect(z == c(-3, 4))
    }

    @Test func multiplicationDoesNotModifyCopies() {
        let a = c(1, 2)
        var b = a
        b *= c(3, 4)
        #expect(a == c(1, 2))
        #expect(b == c(-5, 10))
    }

    @Test func division() {
        // (-5 + 10i) / (3 + 4i) = 1 + 2i
        #expect(c(-5, 10) / c(3, 4) == c(1, 2))
    }

    @Test func divisionInPlace() {
        var z = c(-5, 10)
        z /= c(3, 4)
        #expect(z == c(1, 2))
    }

    @Test func divisionInPlaceByItself() {
        var z = c(3, -7)
        z /= z
        #expect(z == c(1, 0))
    }

    @Test func divisionByReal() {
        let two = MPFloat(2.0, precision: p)
        #expect(c(3, -5) / two == c(1.5, -2.5))
        var z = c(3, -5)
        z /= two
        #expect(z == c(1.5, -2.5))
    }

    @Test func divisionByRealIsCorrectlyRounded() {
        // 1/3 must be identical to the correctly rounded real division, both parts
        let three = MPFloat(3.0, precision: p)
        let one = MPFloat(1.0, precision: p)
        let z = c(1, 1) / three
        #expect(z.real == one / three)
        #expect(z.imaginary == one / three)
    }

    @Test func squareNormAbs() {
        let z = c(3, 4)
        #expect(MPComplex.square(c(1, 2)) == c(-3, 4))
        #expect(MPComplex.normSquare(z) == 25.0)
        #expect(MPComplex.abs(z) == 5.0)
        #expect(z.length == 5.0)
        #expect(z.lengthSquared == 25.0)
    }

    @Test func squareMatchesMultiplication() {
        let z = MPComplex("-0.743643887037158704752191506114774", "0.131825904205311970493132056385139", precision: p)
        #expect(MPComplex.square(z) == z * z)
    }
}

@Suite("In-place iteration")
struct InPlaceIterationTests {

    let c0 = MPComplex("-0.743643887037158704752191506114774", "0.131825904205311970493132056385139", precision: p)

    @Test func formSquareAddMatchesOperators() {
        var a = MPComplex(0.0, 0.0, precision: p)
        var b = MPComplex(0.0, 0.0, precision: p)
        var scratch = MPFloat(precision: p)

        for _ in 0..<1000 {
            a = MPComplex.square(a) + c0
            b.formSquareAdd(c0, scratch: &scratch)
            #expect(a == b)
            if a != b { break }
        }
    }

    @Test func formSquareAddWithoutScratch() {
        var a = c(0.5, 0.25)
        var b = a
        a = MPComplex.square(a) + c0
        b.formSquareAdd(c0)
        #expect(a == b)
    }

    @Test func formSquareAddWithItself() {
        // z = z² + z: c shares storage with self
        var z = c(1, 2)
        z.formSquareAdd(z)
        #expect(z == c(-2, 6))      // (-3 + 4i) + (1 + 2i)
    }

    @Test func formSquareAddDoesNotModifyCopies() {
        let a = c(1, 2)
        var b = a
        var scratch = MPFloat(precision: p)
        b.formSquareAdd(c(1, 1), scratch: &scratch)
        #expect(a == c(1, 2))
        #expect(b == c(-2, 5))
    }

    @Test func scratchPrecisionIsAdjusted() {
        // A scratch value with too low precision must not reduce the accuracy
        var a = c0
        var b = c0
        var lowScratch = MPFloat(precision: 24)
        a.formSquareAdd(c0)
        b.formSquareAdd(c0, scratch: &lowScratch)
        #expect(a == b)
        #expect(lowScratch.precision == p)
    }

    @Test func formSquare() {
        var z = c(1, 2)
        var scratch = MPFloat(precision: p)
        z.formSquare(scratch: &scratch)
        #expect(z == c(-3, 4))
        #expect(z.real.precision == p)
    }
}
