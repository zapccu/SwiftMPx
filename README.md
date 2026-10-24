
# SwiftMPx

Provide Swift wrapper classes for MPFR

* MPFloat: Class for real numbers
* MPComplex: Class for complex numbers

## How to use this package in your own Swift project

* Install MPFR (i.e. brew install mpfr)
* Clone SwiftMPx from Github
* Add the cloned package as a local package dependency to your project
* Add "/opt/homebrew/lib" as library search path in build settings
* Add "/opt/homebrew/include" as include search path in build settings
 
## Comformity

MPFloat is conform to the following standard protocols:

* ExpressibleByFloatLiteral
* ExpressibleByIntegerLiteral
* Comparable
* CustomStringConvertible
* Sendable

In addition MPFloat implements all functions from Swift Numerics package protocols RealFunctions and ElementaryFunctions.
To make MPFloat conform to these protocols, simply add Numerics as a package dependency and add the following code
to your project:

```
extension MPFloat : RealFunctions {
   // RealFunctions is already conform to ElementaryFunctions
}
```



## Performance

Every arithmetic operator creates a new value, which allocates memory. For hot loops like the
calculation of a reference orbit use the in-place functions of MPComplex with a reused scratch value.
They do not allocate memory per iteration:

```
var z = MPComplex(0.0, 0.0, precision: 256)
var scratch = MPFloat(precision: 256)
for _ in 0..<maxIter {
    z.formSquareAdd(c, scratch: &scratch)   // z = z² + c
}
```

Complex multiplication, division, square and norm use `mpfr_fmma` / `mpfr_fmms`, which compute
expressions like `ac - bd` with a single rounding.

Benchmark (use a release build):

```
swift run -c release SwiftMPxBenchmark [iterations]
```
