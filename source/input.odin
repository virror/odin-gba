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

input_set_key :: proc(key: Keys) {
    keys := bus_get16(u32(IOs.KEYINPUT))
    keys = utils_bit_clear16(keys, u8(key))
    bus_set16(u32(IOs.KEYINPUT), keys)
    input_handle_irq(keys)
}

input_clear_key :: proc(key: Keys) {
    keys := bus_get16(u32(IOs.KEYINPUT))
    keys = utils_bit_set16(keys, u8(key))
    bus_set16(u32(IOs.KEYINPUT), keys)
    input_handle_irq(keys)
}

input_handle_irq :: proc(keys: u16) {
    keys := keys
    key_cnt := bus_get16(u32(IOs.KEYCNT))
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