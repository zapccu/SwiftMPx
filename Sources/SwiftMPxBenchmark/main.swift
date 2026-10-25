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

    // Sanity check: all variants must produce the same orbit end point
    precondition(t1.result == t2.result, "z = z * z + c differs from square(z) + c")
    precondition(!t1.result.real.isNaN && !t2.result.real.isNaN, "orbit diverged")

    let cols = [
        "\(p)",
        String(format: "%.3f s", t1.seconds),
        String(format: "%.3f s", t2.seconds),
        String(format: "%.1fx", t1.seconds / t2.seconds)
    ]
    print(cols.map { $0.padding(toLength: 15, withPad: " ", startingAt: 0) }.joined())
}
