
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


