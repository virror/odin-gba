package main

utils_bit_get16 :: proc(value: u16, bit: u8) -> bool {
    return bool((value >> bit) & 1)
}

utils_bit_get32 :: proc(value: u32, bit: u8) -> bool {
    return bool((value >> bit) & 1)
}

utils_bit_get64 :: proc(value: u64, bit: u8) -> bool {
    return bool((value >> bit) & 1)
}

utils_bit_set8 :: proc(value: u8, bit: u8) -> u8 {
    return value | (1 << bit)
}

utils_bit_set16 :: proc(value: u16, bit: u8) -> u16 {
    return value | (1 << bit)
}

utils_bit_set32 :: proc(value: u32, bit: u8) -> u32 {
    return value | (1 << bit)
}

utils_bit_clear16 :: proc(value: u16, bit: u8) -> u16 {
    return value & ~(1 << bit)
}

utils_bit_clear32 :: proc(value: u32, bit: u8) -> u32 {
    return value & ~(1 << bit)
}

utils_sign_extend32 :: proc(data: u32, bits: u32) -> u32 {
    m := u32(1) << (bits - 1)
    return (data ~ m) - m
}