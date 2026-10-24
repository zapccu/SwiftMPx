//
//  main.swift
//  SwiftMPxBenchmark
//
//  Benchmark for the iteration z = z² + c, as used for reference orbits.
//  Run with: swift run -c release SwiftMPxBenchmark [iterations]
//

import Foundation
import SwiftMPx

let iterations = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 200_000 : 200_000
let precisions = [128, 256, 512, 1024, 2048]

/// Run a closure and return the elapsed time in seconds
func measure(_ body: () -> MPComplex) -> (seconds: Double, result: MPComplex) {
    let clock = ContinuousClock()
    var result = MPComplex(precision: 53)
    let duration = clock.measure { result = body() }
    let c = duration.components
    return (Double(c.seconds) + Double(c.attoseconds) * 1e-18, result)
}

print("SwiftMPx benchmark: z = z² + c, \(iterations) iterations")
print("Bounded orbit (c inside the main cardioid), so all values stay finite\n")

let header = ["bits", "z * z + c", "square(z) + c", "formSquareAdd", "speedup"]
print(header.map { $0.padding(toLength: 15, withPad: " ", startingAt: 0) }.joined())

for p in precisions {
    let c = MPComplex("-0.1", "0.123456789", precision: p)

    // 1. Operators: one new value per operation
    let t1 = measure {
        var z = MPComplex(0.0, 0.0, precision: p)
        for _ in 0..<iterations { z = z * z + c }
        return z
    }

    // 2. Square function plus addition
    let t2 = measure {
        var z = MPComplex(0.0, 0.0, precision: p)
        for _ in 0..<iterations { z = MPComplex.square(z) + c }
        return z
    }

    // 3. In place with reused scratch value: no allocations per iteration
    let t3 = measure {
        var z = MPComplex(0.0, 0.0, precision: p)
        var scratch = MPFloat(precision: p)
        for _ in 0..<iterations { z.formSquareAdd(c, scratch: &scratch) }
        return z
    }

    // Sanity check: all variants must produce the same orbit end point
    precondition(t2.result == t3.result, "formSquareAdd differs from square(z) + c")
    precondition(!t1.result.real.isNaN && !t3.result.real.isNaN, "orbit diverged")

    let cols = [
        "\(p)",
        String(format: "%.3f s", t1.seconds),
        String(format: "%.3f s", t2.seconds),
        String(format: "%.3f s", t3.seconds),
        String(format: "%.1fx", t1.seconds / t3.seconds)
    ]
    print(cols.map { $0.padding(toLength: 15, withPad: " ", startingAt: 0) }.joined())
}

print("\nSwiftMPx benchmark: D = 2·D·Z + 1, Z = Z² + c, \(iterations) iterations\n")

let header2 = ["bits", "operators", "formMandelbrotStep", "speedup"]
print(header2.map { $0.padding(toLength: 20, withPad: " ", startingAt: 0) }.joined())

for p in precisions {
    let c = MPComplex("-0.1", "0.123456789", precision: p)
    let one = MPComplex(1.0, 0.0, precision: p)
    let two = MPFloat(2.0, precision: p)

    // 1. Operators: several new values per iteration
    var dOps = MPComplex(precision: p)
    let t1 = measure {
        var z = MPComplex(0.0, 0.0, precision: p)
        var d = MPComplex(1.0, 0.0, precision: p)
        for _ in 0..<iterations {
            d = two * d * z + one
            z = z * z + c
        }
        dOps = d
        return z
    }

    // 2. In place with reused scratch value
    var dInPlace = MPComplex(precision: p)
    let t2 = measure {
        var z = MPComplex(0.0, 0.0, precision: p)
        var d = MPComplex(1.0, 0.0, precision: p)
        var scratch = MPComplex.makeScratch(precision: p)
        for _ in 0..<iterations {
            MPComplex.formMandelbrotStep(z: &z, d: &d, c: c, scratch: &scratch)
        }
        dInPlace = d
        return z
    }

    // Sanity check: both variants converge to the same values (up to rounding)
    let diff = MPComplex.abs(dOps - dInPlace).toDouble()
    precondition(diff < 1e-30, "formMandelbrotStep differs from operators: \(diff)")
    precondition(!t1.result.real.isNaN && !t2.result.real.isNaN, "orbit diverged")

    let cols = [
        "\(p)",
        String(format: "%.3f s", t1.seconds),
        String(format: "%.3f s", t2.seconds),
        String(format: "%.1fx", t1.seconds / t2.seconds)
    ]
    print(cols.map { $0.padding(toLength: 20, withPad: " ", startingAt: 0) }.joined())
}
