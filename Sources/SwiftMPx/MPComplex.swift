//
//  MPComplex.swift
//  SwiftMPx
//
//  Created by Dirk Braner on 14.02.26.
//

class MPComplex {
    var real: mpfr_t
    var imaginary: mpfr_t
    
    // Precision (default is 128 bit)
    public let precision: Int32

    init(prec: Int32 = 128) {
        precision = prec
        real = mpfr_t()
        mpfr_init2(&real, mpfr_prec_t(prec))
        imaginary = mpfr_t()
        mpfr_init2(&imaginary, mpfr_prec_t(prec))
    }
    
    public init(_ real: Double = 0.0, _ imaginary: Double = 0.0, precision: Int32 = 128) {
        self.precision = precision

        self.real = mpfr_t()
        mpfr_init2(&self.real, mpfr_prec_t(precision))
        mpfr_set_d(&self.real, dval, MPFR_RNDN)

        self.imaginary = mpfr_t()
        mpfr_init2(&self.imaginary, mpfr_prec_t(precision))
        mpfr_set_d(&self.imaginary, dval, MPFR_RNDN)
    }
    
    public init(_ real: String = "0", _ imaginary: String = "0", precision: Int32 = 128) {
        self.precision = precision

        self.real = mpfr_t()
        mpfr_init2(&self.real, mpfr_prec_t(precision))
        mpfr_set_str(&self.real, real, 10, MPFR_RNDN)
        
        self.imaginary = mpfr_t()
        mpfr_init2(&self.imaginary, mpfr_prec_t(precision))
        mpfr_set_str(&self.imaginary, real, 10, MPFR_RNDN)
    }
    
    /// Free memory
    deinit {
        mpfr_clear(&self.real)
        mpfr_clear(&self.imaginary)
    }
    
    /// Return a copy of a value
    /// Use y = x.copy() instead of y = x
    public func copy() -> MPComplex {
        let newObj = MPComplex(prec: self.precision)
        mpfr_set(&newObj.real, &self.real, MPFR_RNDN)
        mpfr_set(&newObj.imaginary, &self.imaginary, MPFR_RNDN)
        return newObj
    }
    
    /// Set value to String
    public func set(_ real: String, _ imaginary: String = "0") {
        mpfr_set_str(&self.real, real, 10, MPFR_RNDN)
        mpfr_set_str(&self.imaginary, imaginary, 10, MPFR_RNDN)
    }
    
    /// Set value to Double
    public func set(_ real: Double, _ imaginary: Double = 0.0) {
        mpfr_set_d(&self.real, real, MPFR_RNDN)
        mpfr_set_d(&self.imaginary, imaginary, MPFR_RNDN)
    }
    
    /// Set value to value of MPFloat (deep copy)
    public func set(_ real: MPFloat, _ imaginary: MPFloat) {
        mpfr_set(&self.real, &real.value, MPFR_RNDN)
        mpfr_set(&self.imaginary, &imaginary.value, MPFR_RNDN)
    }
    
    /// Set value to value of MPComplex (deep copy)
    public func set(_ cval: MPComplex) {
        mpfr_set(&self.real, &cval.real, MPFR_RNDN)
        mpfr_set(&self.imaginary, &cval.imaginary, MPFR_RNDN)
    }
    
    #if canImport(Numerics)

    /// Set value to Complex<Double>
    public func set(_ cval: Complex<Double>) {
        mpfr_set_d(&self.real, cval.real, MPFR_RNDN)
        mpfr_set_d(&self.imaginary, cval.imaginary, MPFR_RNDN)
    }
    
    /// Convert value to Complex<Double>
    func toComplex() -> Complex<Double> {
        return Complex<Double>(mpfr_get_d(&self.real, MPFR_RNDN), mpfr_get_d(&self.imaginary, MPFR_RNDN)
    }
    
    #endif
    
    //
    // Addition
    //
}
