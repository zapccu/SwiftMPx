
# MPFloat

## Initializers

```
MPFloat()
MPFloat(Double, precision: Int = 128)
MPFloat(String, precision: Int = 128)

var x: MPFloat = 2.0   // Convert 2.0 (Double) to MPFloat
var y: MPFloat = 2     // Convert 2 (Int) to MPFloat

```


## Overloaded operators

### Negation
```
-MPFloat
```

### Basic mathematical operations
```
MPFloat <Operator> { MPFloat | Double | Int }
{ MPFloat | Double | Int } <Operator> MPFloat
MPFloat <InPlaceOperator> { MPFloat | Double | Int }

Operator := { +, -, *, / }
InPlaceOperator := { +=, -=, *=, /= }
```

### Comparison
```
MPFloat <CompOperator> { MPFloat | Double | Int }
{ MPFloat | Double | Int } <CompOperator> { MPFloat }

CompOperator := { <, >, ==, != }
```

## Functions

```
exp() - Exponential function
log() - Natural logarithm 
log2() - Logarithm with base 2
LOG2() - ln(2) with specified precision
max() - Maximum of two values
min() - Minimum of two values
PI() - pi with specified precision
pow() - Power
square() - Square 
sqrt() - Square root 
```

