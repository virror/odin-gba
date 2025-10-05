package main

import "core:fmt"

Keys :: enum {
    A,
    B,
    SELECT,
    START,
    RIGHT,
    LEFT,
    UP,
    DOWN,
    R,
    L,
}

key_state: u16
key_cnt: u16

input_init :: proc() {
    key_state = 0x03FF
}

input_set_key :: proc(key: Keys) {
    key_state = utils_bit_clear16(key_state, u8(key))
    input_handle_irq()
}

input_clear_key :: proc(key: Keys) {
    key_state = utils_bit_set16(key_state, u8(key))
    input_handle_irq()
}

input_handle_irq :: proc() {
    keys := key_state
    if(utils_bit_get16(key_cnt, 14)) {
        key_int := key_cnt & 0x03FF
        keys = (~keys) & 0x03FF
        if(utils_bit_get16(key_cnt, 15)) { //AND mode
            if(key_int == keys) {
                bus_irq_set(12)
            }
        } else { //OR mode
            if((key_int & keys) > 0) {
                bus_irq_set(12)
            }
        }
    }
}

input_read :: proc(addr: u32) -> u8 {
    switch(addr) {
    case IO_KEYINPUT:
        return u8(key_state)
    case IO_KEYINPUT + 1:
        return u8(key_state >> 8)
    case IO_KEYCNT:
        return u8(key_cnt)
    case IO_KEYCNT + 1:
        return u8(key_cnt >> 8)
    }
    return 0
}

input_write :: proc(addr: u32, value: u8) {
    switch(addr) {
    case IO_KEYCNT:
        key_cnt &= 0xFF00
        key_cnt |= u16(value)
    case IO_KEYCNT + 1:
        key_cnt &= 0x00FF
        key_cnt |= u16(value) << 8
    }
}