//
//  GetPrecisionTests.swift
//  SwiftMPx
//
//  Tests for MPFloat.getPrecision / MPComplex.getPrecision with all kinds of numeric strings.
//
//  Expected bits: max(ceil(-e * log2(10)) + safetyBits, 53) with e = floor(log10(|value|))
//

import Foundation
import Testing
@testable import SwiftMPx

@Suite("getPrecision")
struct GetPrecisionTests {

    /// (string, expected bits, expected isDbl)
    static let validCases: [(String, Int, Bool)] = [
        // Integers and fixed point
        ("1",            53, true),
        ("-1",           53, true),
        ("123",          53, true),
        ("123.456",      53, true),
        ("-123.456",     53, true),
        ("+1.5",         53, true),
        (".5",           53, true),
        ("5.",           53, true),
        ("0.000123",     53, true),
        ("-0.743643887037158704752191506114774", 53, true),
        // Exponential format
        ("1.23e-5",      53, true),
        ("1.23E-5",      53, true),
        ("1e5",          53, true),
        ("1.5e+3",       53, true),
        ("1e-15",        58, false),     // e = -15: ceil(49.83) + 8 = 58, 50 > 45 bits
        ("1.5e-15",      58, false),
        ("1e-300",     1005, false),
        // Beyond Double range: mantissa must be taken into account
        ("1e-400",     1337, false),
        ("2.5e-350",   1171, false),
        ("0.0025e-347", 1171, false),    // = 2.5e-350
        ("123456e-405", 1337, false),    // = 1.23456e-400
        ("1e400",        53, false),     // Double overflows
        // Whitespace
        ("  1.5",        53, true),
        ("1.5  ",        53, true),
        ("\t1.23e-5\n",  53, true),
        // Zero: no precision requirement
        ("0",            53, true),
        ("-0",           53, true),
        ("0.0",          53, true),
        ("0e-500",       53, true),
    ]

    static let invalidCases: [String] = [
        "", "abc", "1,5", "1.5.3", "e5", "1e", "--1", "0x1p3", "1.5x",
        "@NaN@", "@Inf@", "-@Inf@", "nan", "inf",
    ]

    @Test(arguments: validCases)
    func validStrings(_ testCase: (String, Int, Bool)) throws {
        let (s, bits, isDbl) = testCase
        let r = try #require(MPFloat.getPrecision(real: s), "nil for \"\(s)\"")
        #expect(r.bits == bits, "bits for \"\(s)\"")
        #expect(r.isDbl == isDbl, "isDbl for \"\(s)\"")
    }

    @Test(arguments: invalidCases)
    func invalidStrings(_ s: String) {
        #expect(MPFloat.getPrecision(real: s) == nil, "\"\(s)\" should be invalid")
    }

    @Test(arguments: validCases.map { $0.0 } + invalidCases)
    func sameFormatsAsInitializer(_ s: String) {
        // Every string accepted by getPrecision is accepted by the initializer.
        // Special values (NaN, Inf) are valid values, but have no precision requirement.
        let accepted = MPFloat(validating: s, precision: 64) != nil
        let special = ["@NaN@", "@Inf@", "-@Inf@", "nan", "inf"].contains(s)
        #expect((MPFloat.getPrecision(real: s) != nil) == (accepted && !special), "\"\(s)\"")
    }

    @Test func scaling() {
        // 1e-5 / 1e12 = 1e-17: ceil(56.47) + 8 = 65 bits
        let r = MPFloat.getPrecision(real: "1e-5", scale: 1_000_000_000_000)
        #expect(r?.bits == 65)
        #expect(r?.isDbl == false)
        // Scale <= 1 is ignored
        #expect(MPFloat.getPrecision(real: "1e-5", scale: 0)?.bits == 53)
    }

    @Test func safetyBits() {
        // e = -15: ceil(49.83) = 50 raw bits
        #expect(MPFloat.getPrecision(real: "1e-15", safetyBits: 20)?.bits == 70)
        #expect(MPFloat.getPrecision(real: "1e-15", safetyBits: 0)?.isDbl == true)
    }

    @Test func complexWithZeroPart() {
        // Previously nil, because "0" was not accepted
        let r = MPComplex.getPrecision(real: "1e-30", imaginary: "0")
        #expect(r?.bits == MPFloat.getPrecision(real: "1e-30")?.bits)
        #expect(r?.isDbl == false)

        let z = MPComplex.getPrecision(real: "0", imaginary: "0")
        #expect(z?.bits == 53)
        #expect(z?.isDbl == true)
    }

    @Test func initializersTrimWhitespace() {
        #expect(MPFloat("  1.5\n", precision: 64) == 1.5)
        #expect(MPFloat(validating: " -2.25 ", precision: 64) == MPFloat(-2.25, precision: 64))
        #expect(MPComplex(" 1.5", "2.5 ", precision: 64) == MPComplex(1.5, 2.5, precision: 64))
        #expect(MPFloat(" 0.0025e-347 ").exponent < -1150)
    }

    @Test func detectedPrecisionBeyondDoubleRange() {
        // Magnitude based lower bound must also work beyond Double range
        let x = MPFloat("0.0025e-347")
        #expect(x.precision >= 1171)
        #expect(!x.isNaN && !x.isZero)
    }
}
