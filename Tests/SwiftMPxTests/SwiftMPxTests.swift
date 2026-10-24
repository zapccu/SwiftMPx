//
//  SwiftMPxTests.swift
//  SwiftMPx
//
//  Regression tests for the fixes from the code review (October 2026).
//  All tests use explicit precisions, except the suite "Default precision", which changes the
//  global default precision and is therefore serialized.
//

import Foundation
import Testing
@testable import SwiftMPx

private let p = 128

// MARK: - Comparisons with NaN

@Suite("NaN comparisons")
struct NaNComparisonTests {

    let nan = MPFloat.nan
    let one = MPFloat(1.0, precision: p)

    @Test func nanIsNotEqualToAnything() {
        #expect(!(nan == nan))
        #expect(!(nan == one))
        #expect(!(one == nan))
        #expect(!(nan == 1.0))
        #expect(nan != nan)
        #expect(nan != one)
        #expect(nan != 1.0)
    }

    @Test func nanIsUnordered() {
        #expect(!(nan < one))
        #expect(!(nan <= one))
        #expect(!(nan > one))
        #expect(!(nan >= one))
        #expect(!(one < nan))
        #expect(!(one >= nan))
        #expect(!(nan < 1.0))
        #expect(!(nan <= 1.0))
        #expect(!(nan > 1.0))
        #expect(!(nan >= 1.0))
        #expect(!(one < Double.nan))
    }

    @Test func regularComparisonsStillWork() {
        let two = MPFloat(2.0, precision: p)
        #expect(one == one)
        #expect(one < two)
        #expect(one <= two)
        #expect(two > one)
        #expect(two >= one)
        #expect(one == 1.0)
        #expect(one < 1.5)
        #expect(one != two)
    }

    @Test func minMaxIgnoreNaN() {
        let two = MPFloat(2.0, precision: p)
        #expect(MPFloat.max(nan, two) == two)
        #expect(MPFloat.min(two, nan) == two)
        #expect(MPFloat.max(one, two) == two)
        #expect(MPFloat.min(one, two) == one)
    }
}

// MARK: - Copy on write

@Suite("Copy on write")
struct CopyOnWriteTests {

    @Test func precisionSetterDoesNotModifyCopies() {
        let a = MPFloat("0.1", precision: 256)
        let reference = MPFloat("0.1", precision: 256)
        var b = a
        b.precision = 24

        #expect(a.precision == 256)
        #expect(a == reference)
        #expect(b.precision == 24)
        #expect(b != a)
    }

    @Test func inPlaceOperationDoesNotModifyCopies() {
        let a = MPFloat(1.0, precision: p)
        var b = a
        b += 1.0
        #expect(a == 1.0)
        #expect(b == 2.0)
    }

    @Test func copyInitWithSamePrecisionIsIndependent() {
        let a = MPFloat(3.0, precision: p)
        var b = MPFloat(a)
        b *= 2.0
        #expect(a == 3.0)
        #expect(b == 6.0)
    }
}

// MARK: - Functions

@Suite("Functions")
struct FunctionTests {

    @Test func root() {
        let x = MPFloat(27.0, precision: p)
        let r = MPFloat.root(x, 3)
        #expect(!r.isNaN)
        #expect(r == 3.0)
    }

    @Test func linspaceSingleElement() {
        let a = MPFloat(2.0, precision: p)
        let b = MPFloat(5.0, precision: p)
        let l = MPFloat.linspace(a, b, 1)
        #expect(l.count == 1)
        #expect(l[0] == a)
    }

    @Test func linspace() {
        let l = MPFloat.linspace(MPFloat(0.0, precision: p), MPFloat(1.0, precision: p), 5)
        #expect(l.count == 5)
        #expect(l[2] == 0.5)
        #expect(l[4] == 1.0)
    }

    @Test func intInitIsExact() {
        let a = MPFloat(Int.max, precision: 64)
        let b = MPFloat("9223372036854775807", precision: 64)
        #expect(a == b)
        #expect(a.toString() == "9223372036854775807")
    }
}

// MARK: - Complex division

@Suite("Complex division")
struct ComplexDivisionTests {

    @Test func realDividedByComplex() {
        // 1 / i = -i
        let one = MPFloat(1.0, precision: p)
        let i = MPComplex(0.0, 1.0, precision: p)
        let r = one / i
        #expect(r.real == 0.0)
        #expect(r.imaginary == -1.0)

        // 2 / (1 + i) = 1 - i
        let r2 = MPFloat(2.0, precision: p) / MPComplex(1.0, 1.0, precision: p)
        #expect(r2.real == 1.0)
        #expect(r2.imaginary == -1.0)
    }

    @Test func realDividedByComplexMatchesComplexDivision() {
        let a = MPFloat(3.0, precision: p)
        let z = MPComplex(2.0, -5.0, precision: p)
        let r1 = a / z
        let r2 = MPComplex(a, MPFloat(0.0, precision: p)) / z
        #expect(r1 == r2)
    }

    @Test func getPrecisionWithZeroScale() {
        // Previously trapped: Int(log10(0)) = Int(-inf)
        let r = MPComplex.getPrecision(real: "1e-20", imaginary: "1e-20", scaleReal: 0, scaleImaginary: -3)
        #expect(r != nil)
    }
}

// MARK: - String conversion and Codable

@Suite("String conversion and Codable")
struct StringCodableTests {

    @Test func specialValuesToString() {
        #expect(MPFloat.nan.toString() == "@NaN@")
        #expect(MPFloat(Double.infinity, precision: p).toString() == "@Inf@")
        #expect(MPFloat(-Double.infinity, precision: p).toString() == "-@Inf@")
        #expect(MPFloat(0.0, precision: p).toString() == "0")
        #expect(MPFloat(-0.0, precision: p).toString() == "-0")
    }

    @Test func trailingZerosInExponentFormat() {
        let x = MPFloat("1.5e-10", precision: 64)
        #expect(x.toString(digits: 5) == "1.5E-10")
        #expect(MPFloat("123.45", precision: 64).toString(digits: 8) == "123.45")
        #expect(MPFloat("0.00125", precision: 64).toString(digits: 6, expFmt: false) == "0.00125")
    }

    @Test func stringRoundTrip() {
        let x = MPFloat("-0.743643887037158704752191506114774", precision: 256)
        let y = MPFloat(x.toString(), precision: 256)
        #expect(x == y)
    }

    private func roundTrip(_ x: MPFloat) throws -> MPFloat {
        let data = try JSONEncoder().encode(x)
        return try JSONDecoder().decode(MPFloat.self, from: data)
    }

    @Test func codableRoundTripSpecialValues() throws {
        #expect(try roundTrip(MPFloat.nan).isNaN)

        let inf = try roundTrip(MPFloat(Double.infinity, precision: p))
        #expect(inf.isInfinite)
        #expect(inf.sign == .plus)

        let minf = try roundTrip(MPFloat(-Double.infinity, precision: p))
        #expect(minf.isInfinite)
        #expect(minf.sign == .minus)

        let mzero = try roundTrip(MPFloat(-0.0, precision: p))
        #expect(mzero.isZero())
        #expect(mzero.sign == .minus)
    }

    @Test func codableRoundTripKeepsPrecisionAndValue() throws {
        let x = MPFloat("1.2345678901234567890123456789e-40", precision: 300)
        let y = try roundTrip(x)
        #expect(y.precision == 300)
        #expect(x == y)
    }

    @Test func codableRejectsInvalidPrecision() {
        for json in [#"{"value":"1","precision":-1}"#, #"{"value":"1","precision":0}"#] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(MPFloat.self, from: Data(json.utf8))
            }
        }
    }

    @Test func codableRejectsInvalidValue() {
        let json = #"{"value":"abc","precision":64}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MPFloat.self, from: Data(json.utf8))
        }
    }

    @Test func invalidStringGivesNaN() {
        #expect(MPFloat("abc", precision: 64).isNaN)
        #expect(MPFloat(validating: "1.5x", precision: 64) == nil)
        #expect(MPFloat(validating: "1.5", precision: 64) != nil)
    }
}

// MARK: - Precision handling

@Suite("Precision handling")
struct PrecisionTests {

    @Test func stringInitDoesNotTruncateLongMantissa() {
        let s = "-0.743643887037158704752191506114774"
        let x = MPFloat(s)
        #expect(x.precision > 53)
        #expect(x.toString().hasPrefix("-0.74364388703715870475219150611477"))
    }

    @Test func stringInitKeepsMagnitudeBasedPrecisionAsLowerBound() {
        let x = MPFloat("1e-50")
        #expect(x.precision >= MPFloat.getPrecision(real: "1e-50")!.bits)
    }

    @Test func complexStringInitDoesNotTruncateLongMantissa() {
        let z = MPComplex("-0.743643887037158704752191506114774", "0.131825904205311970493132056385139")
        #expect(z.precision > 53)
        #expect(z.imaginary.toString().hasPrefix("0.13182590420531197049313205638513"))
    }

    // Previously these calls passed negative or zero precisions to mpfr_init2 (MPFR assertion, abort).
    // The global default precision is not compared here, because the suite "Default precision"
    // may change it concurrently.
    @Test func precisionFlagsDoNotCrash() {
        let a = MPFloat(1.0, precision: MPFloat.useDefaultPrecision)
        #expect(MPFloat.isValidPrecision(a.precision))
        #expect(a == 1.0)

        let b = MPFloat(a, precision: MPFloat.detectPrecision)
        #expect(b.precision == a.precision)

        let c = MPFloat(Float(1.5), precision: MPFloat.useOtherPrecision)
        #expect(MPFloat.isValidPrecision(c.precision))
        #expect(c == 1.5)

        let d = MPFloat(42, precision: MPFloat.useDefaultPrecision)
        #expect(d == 42.0)

        var e = MPFloat(1.0, precision: p)
        e.precision = MPFloat.detectPrecision     // no change
        #expect(e.precision == p)
    }
}

// MARK: - Default precision (global state, serialized)

@Suite("Default precision", .serialized)
struct DefaultPrecisionTests {

    @Test func defaultPrecisionIsVisibleInOtherThreads() async {
        let oldDefault = MPFloat.defaultPrecision
        let oldMode = MPFloat.resultPrecision
        defer { MPFloat.setPrecisions(defaultPrecision: oldDefault, resultPrecision: oldMode) }

        MPFloat.setPrecisions(defaultPrecision: 200, resultPrecision: .maxOfOperands)

        // Detached task runs on a thread of the cooperative pool, not on the main thread
        let precisions = await Task.detached {
            (MPFloat(1.0).precision, MPFloat().precision, MPComplex(1.0, 2.0).precision)
        }.value

        #expect(precisions.0 == 200)
        #expect(precisions.1 == 200)
        #expect(precisions.2 == 200)
    }

    @Test func setPrecisionsWorksFromBackgroundThread() async {
        let oldDefault = MPFloat.defaultPrecision
        let oldMode = MPFloat.resultPrecision
        defer { MPFloat.setPrecisions(defaultPrecision: oldDefault, resultPrecision: oldMode) }

        await Task.detached {
            MPFloat.setPrecisions(defaultPrecision: 99, resultPrecision: .leftOperand)
        }.value

        #expect(MPFloat.defaultPrecision == 99)
        #expect(MPFloat.resultPrecision == .leftOperand)
    }
}
