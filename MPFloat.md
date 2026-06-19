
# MPFloat

## Initializers

```
MPFloat(precision: Int = 128)
MPFloat(Double, precision: Int = 128)
MPFloat(String, precision: Int = 128)

var x: MPFloat = 2.0   // Convert 2.0 (Double) to MPFloat
var y: MPFloat = 2     // Convert 2 (Int) to MPFloat

```


## Overloaded operators

### Negation
```
- MPFloat
```

### Basic mathematical operations
```
MPFloat <*Operator*> { MPFloat | Double | Int }
{ MPFloat | Double | Int } <*Operator*> MPFloat
MPFloat <*InPlaceOperator*> { MPFloat | Double | Int }

Operator := { +, -, *, / }
InPlaceOperator := { +=, -=, *=, /= }
```

### Comparison

MPFloat *CompOperator* { MPFloat | Double | Int }
{ MPFloat | Double | Int } *CompOperator* { MPFloat }

*CompOperator* := { <, <=, >, >=, ==, != }


## Functions
### Precision handling
#### MPFloat.getPrecision(real: String, scale: Int = 1, safetyBits: Int = 8) -> (isDbl: Bool, precision: Int)?
Returns a tuple (isDbl, precision). If isDbl is true, MPFR is not needed and one can use Swifts Double type for calculation.

### Conversions
```
toDouble() - Convert MPFloat to Double
toString(digits: Int = 32) - Convert MPFloat to String
Double(_ x: MPFloat) - Cast MPFloat to Double
```

Using *toDouble* or *Double* with MPFloat values with a precision of >64 bit could result in 0.
Check precision before converting MPFloat values!

### Mathematic functions
```
MPFloat.abs(_ x: MPFloat) - Absolute value
MPFloat.acos(_ x: MPFloat) - Inverse cosine
MPFloat.acosh(_ x: MPFloat) - Inverse hyperbolic cosine
MPFloat.asin(_ x: MPFloat) - Inverse sine
MPFloat.asinh(_ x: MPFloat) - Inverse hyperbolic sine
MPFloat.atan(_ x: MPFloat) - Inverse tangent
MPFloat.atanh(_ x: MPFloat) - Inverse hyperbolic tangent
MPFloat.atan2(y: MPFloat, x: MPFloat)
MPFloat.cos(_ x: MPFloat) - Cosine
MPFloat.cosh(_ x: MPFloat) - Hyperbolic cosine
MPFloat.erf(_ x: MPFloat) - 
MPFloat.erfc(_ x: MPFloat) -
MPFloat.exp(_ x: MPFloat) - Exponential function
MPFloat.expMinusOne(_ x: MPFloat) - exp(x)-1 for small x
MPFloat.fmod(_ x: MPFloat, _ y: MPFloat) - Floating point modulo division
MPFloat.gamma(_ x: MPFloat) - Gamma
MPFloat.hypot(_ x: MPFloat, _ y: MPFloat)
MPFloat.log(_ x: MPFloat) - Natural logarithm 
MPFloat.log(onePlus x: MPFloat) - Natural logarithm of (1 + x)
MPFloat.log2(_ x: MPFloat) - Logarithm with base 2
MPFloat.log10(_ x: MPFloat) - Logarithm with base 10
MPFloat.logGamma(_ x: MPFloat) - Logarithm of absolute value of gamma
MPFloat.LOG2() - ln(2) with specified precision
MPFloat.max(_ x: MPFloat, _ y: MPFloat) - Maximum of two values
MPFloat.min(_ x: MPFloat, _ y: MPFloat) - Minimum of two values
MPFloat.PI() - pi with specified precision
MPFloat.pow(_ x: MPFloat, _ y: MPFloat) - Power
MPFloat.pow(_ x: MPFloat, _ y: Int) - Power
MPFloat.root(_ x: MPFloat, _ n: Int) - nth root of x
MPFloat.signGamma(_ x: MPFloat) -> FloatingPointSign
MPFloat.sin(_ x: MPFloat) - Sine
MPFloat.sinh(_ x: MPFloat) - Hyperbolic sine
MPFloat.square(_ x: MPFloat) - Square 
MPFloat.sqrt(_ x: MPFloat) - Square root 
MPFloat.tan(_ x: MPFloat) - Tangent
MPFloat.tanh(_ x: MPFloat) - Hyperbolic tangent
```

