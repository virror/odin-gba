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

key_state :u16= 0x03FF

input_set_key :: proc(key: Keys) {
    key_state = utils_bit_clear16(key_state, u8(key))
    bus_set16(u32(IOs.KEYINPUT), key_state)
    input_handle_irq()
}

input_clear_key :: proc(key: Keys) {
    key_state = utils_bit_set16(key_state, u8(key))
    bus_set16(u32(IOs.KEYINPUT), key_state)
    input_handle_irq()
}

input_handle_irq :: proc() {
    keys := key_state
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