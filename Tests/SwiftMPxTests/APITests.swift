//
//  APITests.swift
//  SwiftMPx
//
//  Tests for protocol conformances, precision handling of MPComplex operators and the
//  MPComplex String initializers.
//

import Foundation
import Testing
@testable import SwiftMPx

private let p = 128

// MARK: - Hashable / AdditiveArithmetic

@Suite("Conformances")
struct ConformanceTests {

    @Test func equalValuesWithDifferentPrecisionHaveEqualHashes() {
        let a = MPFloat(1.5, precision: 53)
        let b = MPFloat(1.5, precision: 300)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        let pz = MPFloat(0.0, precision: p)
        let nz = MPFloat(-0.0, precision: p)
        #expect(pz == nz)
        #expect(pz.hashValue == nz.hashValue)
    }

    @Test func setAndDictionary() {
        let values: Set<MPFloat> = [MPFloat(1.0, precision: 64), MPFloat(1.0, precision: 256), MPFloat(2.0, precision: p)]
        #expect(values.count == 2)

        var dict: [MPComplex: String] = [:]
        dict[MPComplex(1.0, 2.0, precision: p)] = "a"
        #expect(dict[MPComplex(1.0, 2.0, precision: 256)] == "a")
        #expect(dict[MPComplex(2.0, 1.0, precision: p)] == nil)
    }

    @Test func zero() {
        #expect(MPFloat.zero == 0.0)
        #expect(MPFloat.zero.isZero)
        #expect(MPComplex.zero == MPComplex(0.0, 0.0, precision: p))
    }

    @Test func zeroWithPrecision() {
        let x = MPFloat.zero(precision: 300)
        #expect(x.isZero)
        #expect(x.precision == 300)

        let z = MPComplex.zero(precision: 300)
        #expect(z.real.isZero && z.imaginary.isZero)
        #expect(z.precision == 300)
        #expect(z.imaginary.precision == 300)

        // Accumulator keeps its precision with in-place operators
        var sum = MPFloat.zero(precision: 256)
        for v in [MPFloat("0.1", precision: 256), MPFloat("0.2", precision: 256)] { sum += v }
        #expect(sum.precision == 256)
        #expect(sum == MPFloat("0.3", precision: 256))
    }

    @Test func genericAdditiveArithmetic() {
        func sum<T: AdditiveArithmetic>(_ values: [T]) -> T {
            values.reduce(T.zero, +)
        }
        let s = sum([MPFloat(1.0, precision: p), MPFloat(2.5, precision: p), MPFloat(-0.5, precision: p)])
        #expect(s == 3.0)

        let z = sum([MPComplex(1.0, 1.0, precision: p), MPComplex(2.0, -3.0, precision: p)])
        #expect(z == MPComplex(3.0, -2.0, precision: p))
    }
}

// MARK: - Precision

@Suite("Precision handling (API)")
struct APIPrecisionTests {

    @Test func precisionIsStoredInMPFRValue() {
        var x = MPFloat(1.0, precision: 77)
        #expect(x.precision == 77)
        x.precision = 300
        #expect(x.precision == 300)
        let y = MPFloat(x)                      // shares storage
        #expect(y.precision == 300)
        let z = MPFloat(x, precision: 64)
        #expect(z.precision == 64)
        #expect(MPFloat("1.25", precision: 99).precision == 99)
    }

    @Test func inPlaceOperatorsKeepLeftPrecision() {
        var z = MPComplex(1.0, 2.0, precision: 64)
        z *= MPComplex(3.0, 4.0, precision: 256)
        #expect(z.precision == 64)
        z /= MPComplex(3.0, 4.0, precision: 256)
        #expect(z.precision == 64)
    }

    @Test func complexGetPrecisionUsesLargerRequirement() {
        let r = MPComplex.getPrecision(real: "1e-5", imaginary: "1e-40")
        let im = MPFloat.getPrecision(real: "1e-40")
        #expect(r?.precision == im?.bits)
        #expect(r?.isDbl == false)

        let d = MPComplex.getPrecision(real: "0.5", imaginary: "0.25")
        #expect(d?.isDbl == true)
        #expect(d?.precision == 53)

        #expect(MPComplex.getPrecision(real: "abc", imaginary: "1") == nil)
    }
}

// MARK: - MPComplex String initializers

@Suite("MPComplex String initializers")
struct ComplexStringInitTests {

    @Test func invalidStringGivesNaNWithRequestedPrecision() {
        let z = MPComplex("abc", "1.0", precision: 200)
        #expect(z.isNaN)
        #expect(z.real.precision == 200)
        #expect(z.imaginary.precision == 200)
    }

    @Test func validatingInit() {
        let z = MPComplex(validatingReal: "1.5", validatingImaginary: "-2.25", precision: p)
        #expect(z == MPComplex(1.5, -2.25, precision: p))
        #expect(MPComplex(validatingReal: "1.5x", validatingImaginary: "0", precision: p) == nil)
        #expect(MPComplex(validatingReal: "1", validatingImaginary: "abc", precision: p) == nil)
        #expect(MPComplex(validatingReal: "0.75")?.imaginary.isZero == true)
    }

    @Test func validatingInitDetectsPrecision() {
        let z = MPComplex(validatingReal: "-0.743643887037158704752191506114774",
                          validatingImaginary: "0.131825904205311970493132056385139")
        #expect(z != nil)
        #expect((z?.precision ?? 0) > 53)
    }
}

// Tests that change the global precision settings belong to the serialized suite
extension DefaultPrecisionTests {

    @Test func complexOperatorsUseResultPrecisionMode() {
        // Global state: runs in the serialized suite "Default precision"
        let oldDefault = MPFloat.defaultPrecision
        let oldMode = MPFloat.resultPrecision
        defer { MPFloat.setPrecisions(defaultPrecision: oldDefault, resultPrecision: oldMode) }
        MPFloat.setPrecisions(defaultPrecision: oldDefault, resultPrecision: .maxOfOperands)

        let low  = MPComplex(1.0, 2.0, precision: 64)
        let high = MPComplex(3.0, 4.0, precision: 256)
        let f    = MPFloat(2.0, precision: 256)

        #expect((low * high).precision == 256)
        #expect((low / high).precision == 256)
        #expect((f * low).precision == 256)
        #expect((low / f).precision == 256)
        #expect((f / low).precision == 256)
        #expect((low + high).precision == 256)

        // .leftOperand
        MPFloat.setPrecisions(defaultPrecision: oldDefault, resultPrecision: .leftOperand)
        #expect((low * high).precision == 64)
        #expect((f / low).precision == 256)
    }
}
