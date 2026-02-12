# Integer Math (ulmath_*)

UniLib provides basic integer math operations for 8-bit and 16-bit values, filling in gaps not covered by the KERNAL's floating-point routines.

## 8-bit Operations

### ulmath_abs_8

Absolute value of a signed 8-bit integer.

```
Input:  A     = signed value (-128 to 127)
Output: A     = |A| (0 to 128)
```

### ulmath_negate_8

Negate a signed 8-bit integer (two's complement).

```
Input:  A     = value
Output: A     = -A
```

### ulmath_scmp8_8

Signed comparison of two 8-bit values.

```
Input:  A     = first value
        X     = second value
Output: carry = clear if A < X (signed), set if A >= X (signed)
```

## Unsigned Division

### ulmath_udiv8_8

Unsigned 8-bit division.

```
Input:  X     = dividend
        A     = divisor
Output: X     = quotient (X / A)
        A     = remainder (X mod A)
```

### ulmath_udiv16_8

Unsigned 16-bit by 8-bit division.

```
Input:  YX    = 16-bit dividend (Y = high, X = low)
        A     = 8-bit divisor
Output: YX    = 16-bit quotient
        A     = 8-bit remainder
```

## Unsigned Multiplication

### ulmath_umul8_8

Unsigned 8-bit multiplication.

```
Input:  X     = multiplicand
        A     = multiplier
Output: YX    = 16-bit product (Y = high, X = low)
```

### ulmath_umul16_8

Unsigned 16-bit by 8-bit multiplication.

```
Input:  YX    = 16-bit multiplicand
        A     = 8-bit multiplier
Output: AYX   = 24-bit product (A = high, Y = mid, X = low)
```
