-- Converts a floating-point number to its IEEE 754 binary representation.
-- @param f The floating-point number to convert.
-- @return The binary representation of the floating-point number.
function RVEMU_float_to_bits(f)
    if f == 1/0 then
        return 0x7f800000
    end
    local sign = 0
    if f < 0 then
        sign = 1
        f = -f
    end

    local mantissa, exponent = math.frexp(f)
    if f == 0 then
        mantissa = 0
        exponent = 0
    else
        mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 24)
        exponent = exponent + 126
    end

    return bit.bor((sign * 0x80000000) --[[% 0x100000000]], (exponent * 0x800000)--[[% 0x100000000]], math.floor(mantissa))
end

-- Converts an IEEE 754 binary representation to a floating-point number.
-- @param b The binary representation to convert.
-- @return The floating-point number.
function RVEMU_bits_to_float(b)
    local sign = bit.rshift(b, 31) % 2
    local exponent = bit.rshift(b, 23) % 0x100
    local mantissa = b % 0x800000

    if exponent == 0 then
        if mantissa == 0 then
            return 0.0
        else
            mantissa = mantissa / math.ldexp(1.0, 23)
            return math.ldexp(mantissa, -126) * (sign == 1 and -1 or 1)
        end
    elseif exponent == 255 then
        if mantissa == 0 then
            return (sign == 1) and -1/0 or 1/0
        else
            return 0/0
        end
    else
        mantissa = 1.0 + mantissa / math.ldexp(1.0, 23)
        return math.ldexp(mantissa, exponent - 127) * (sign == 1 and -1 or 1)
    end
end

-- Converts a double-precision floating-point number to its IEEE 754 binary representation.
-- @param d The double-precision floating-point number to convert.
-- @return The high and low parts of the binary representation.
function RVEMU_double_to_bits(d)
    local sign = 0
    if d < 0 then
        sign = 1
        d = -d
    end

    local mantissa, exponent = math.frexp(d)
    if d == 0 then
        mantissa = 0
        exponent = 0
    else
        mantissa = (mantissa * 2 - 1) * (2^52)
        exponent = exponent + 1022
    end

    local lo = mantissa % (2^32)
    local hi = bit.bor((sign * 0x80000000) % 100000000, (exponent * 0x100000) % 100000000, math.floor(mantissa / (0x100000000)))

    return hi, lo
end

-- Converts an IEEE 754 binary representation to a double-precision floating-point number.
-- @param hi The high part of the binary representation.
-- @param lo The low part of the binary representation.
-- @return The double-precision floating-point number.
function RVEMU_bits_to_double(hi, lo)
    local sign = bit.rshift(hi, 31) % 2
    local exponent = bit.rshift(hi, 20) % 0x800
    local mantissa_hi = hi % 0x100000
    local mantissa_lo = lo
    
    local mantissa = mantissa_hi * (2^32) + mantissa_lo
    
    if exponent == 0 then
       if mantissa == 0 then
          return 0.0
       else
          exponent = 1
          mantissa = mantissa / (2^52)
       end
    elseif exponent == 0x7FF then
       if mantissa == 0 then
          return sign == 1 and -1/0 or 1/0
       else
          return 0/0  -- NaN
       end
    else
       mantissa = 1 + mantissa / (2^52)
    end
    
    local result = math.ldexp(mantissa, exponent - 1023)
    if sign == 1 then
       result = -result
    end
    
    return result
 end
