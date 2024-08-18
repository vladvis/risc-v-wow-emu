function float_to_bits(f)
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

    return bit.bor(bit.lshift(sign, 31), bit.lshift(exponent, 23), math.floor(mantissa))
end

function bits_to_float(b)
    local sign = bit.band(bit.rshift(b, 31), 0x1)
    local exponent = bit.band(bit.rshift(b, 23), 0xFF)
    local mantissa = bit.band(b, 0x7FFFFF)

    if exponent == 0 then
        if mantissa == 0 then
            return 0
        else
            mantissa = mantissa / math.ldexp(0.5, 23)
            exponent = -126
        end
    elseif exponent == 255 then
        if mantissa == 0 then
            return (sign == 1) and -math.huge or math.huge
        else
            return 0/0 -- NaN
        end
    else
        mantissa = (mantissa / math.ldexp(0.5, 23)) + 1
        exponent = exponent - 127
    end

    local result = math.ldexp(mantissa, exponent)
    if sign == 1 then
        result = -result
    end

    return result
end

function double_to_bits(d)
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
        mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 52)
        exponent = exponent + 1022
    end

    local lo = mantissa % 0x100000000
    local hi = bit.bor(bit.lshift(sign, 31), bit.lshift(exponent, 20), math.floor(mantissa / 0x100000000))

    return hi, lo
end

function bits_to_double(hi, lo)
    local sign = bit.band(bit.rshift(hi, 31), 0x1)
    local exponent = bit.band(bit.rshift(hi, 20), 0x7FF)
    local mantissa = bit.band(hi, 0xFFFFF) * 0x100000000 + lo

    if exponent == 0 then
        if mantissa == 0 then
            return 0
        else
            mantissa = mantissa / math.ldexp(0.5, 52)
            exponent = -1022
        end
    elseif exponent == 2047 then
        if mantissa == 0 then
            return (sign == 1) and -math.huge or math.huge
        else
            return 0/0 -- NaN
        end
    else
        mantissa = (mantissa / math.ldexp(0.5, 52)) + 1
        exponent = exponent - 1023
    end

    local result = math.ldexp(mantissa, exponent)
    if sign == 1 then
        result = -result
    end

    return result
end