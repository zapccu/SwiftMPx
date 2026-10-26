
# MPComplex

## Precision

MPComplex is using the precision rules and function from MPFloat.

* Operators returning a new value (+, -, *, /) use the result precision mode of MPFloat
  (see MPFloat.setPrecisions), also for mixed operations with MPFloat.
* In-place operators (+=, -=, *=, /=) do not use the result precision mode: they keep the
  precision of the left operand (see MPFloat.md).
* `MPComplex.zero` has the default precision, `MPComplex.zero(precision: p)` the specified one.
* Functions with one argument (square, normSquare, abs, arg) use the precision of the argument.

## Initializers

```
MPComplex(precision: Int = MPFloat.defaultPrecision)
```
Creates an empty MPComplex value (NaN).

```
MPComplex(_ real: Double, _ imaginary: Double, precision: Int = MPFloat.defaultPrecision)
```
Initialize MPComplex value with Double values.

```
MPComplex(_ real: MPFloat, _ imaginary: MPFloat)
```
Initialize MPComplex value with MPFloat values using maximum precision of *real* and *imaginary*.

```
MPComplex(_ real: MPFloat, _ imaginary: MPFloat, precision: Int)
```
Initialize MPComplex value with MPFloat values using specified precision.

```
MPComplex(_ real: String, _ imaginary: String = "0", precision: Int = MPFloat.detectPrecision)
```
Initialize MPComplex Value with numeric Strings for real and imaginary part. With MPFloat.detectPrecision the precision is
derived from the number of significant digits and the magnitude of the value. Invalid strings
result in (NaN, NaN).

```
MPComplex?(validatingReal: String, validatingImaginary: String, precision: Int = MPFloat.detectPrecision)
```
Like above, but returns nil if one of the strings is not a valid number.

Special values are converted to and from strings as "@NaN@", "@Inf@", "-@Inf@" and "-0".
Comparisons follow IEEE 754: every comparison with NaN is false, except !=.


## Overloaded operators

### Negation
```
- MPFloat
```

### Basic mathematical operations
```
Complex <Operator> { MPComplex | MPFloat }
{ MPComplex | MPFloat } <Operator> MPComplex
MPComplex <InPlaceOperator> { MPComplex | MPFloat }

Operator := { +, -, *, / }
InPlaceOperator := { +=, -=, *=, /= }
```

### Comparison

MPComplex *CompOperator* MPComplex
*CompOperator* := { ==, != }


## Functions
### Properties

```swift
isNan           // true if either real or imaginary is NaN
length          // Norm of complex value
lengthSquared   // Squared norm of complex value
max             // Maximum of real and imaginary part
min             // Minimum of real and imaginary part
squared         // Square of complex value
```

### Mathematic functions

```swift
MPComplex.arg(_ x: MPComplex)          // atan2(imaginary, real)
MPComplex.norm(_ x: MPComplex)         // Norm of complex value
MPComplex.normSquared(_ x: MPComplex)  // Squared norm of complex value
MPComplex.square(_ x: MPComplex)       // Square of complex value

```


