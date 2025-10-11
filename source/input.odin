package main

import "core:fmt"
import sdl "vendor:sdl3"
import "../../odin-libs/emu"

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

@(private="file")
key_state: u16
@(private="file")
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

input_process :: proc(event: ^sdl.Event) {
    emu.input_process(event)
    #partial switch event.type {
    case sdl.EventType.KEY_DOWN:
        switch event.key.key {
        case sdl.K_DOWN:
            input_set_key(Keys.DOWN)
        case sdl.K_UP:
            input_set_key(Keys.UP)
        case sdl.K_LEFT:
            input_set_key(Keys.LEFT)
        case sdl.K_RIGHT:
            input_set_key(Keys.RIGHT)
        case sdl.K_Q:
            input_set_key(Keys.SELECT)
        case sdl.K_W:
            input_set_key(Keys.START)
        case sdl.K_Z:
            input_set_key(Keys.A)
        case sdl.K_X:
            input_set_key(Keys.B)
        case sdl.K_C:
            input_set_key(Keys.L)
        case sdl.K_V:
            input_set_key(Keys.R)
        }
    case sdl.EventType.GAMEPAD_BUTTON_DOWN:
        #partial switch sdl.GamepadButton(event.gbutton.button) {
        case sdl.GamepadButton.DPAD_DOWN:
            input_set_key(Keys.DOWN)
        case sdl.GamepadButton.DPAD_UP:
            input_set_key(Keys.UP)
        case sdl.GamepadButton.DPAD_LEFT:
            input_set_key(Keys.LEFT)
        case sdl.GamepadButton.DPAD_RIGHT:
            input_set_key(Keys.RIGHT)
        case sdl.GamepadButton.BACK:
            input_set_key(Keys.SELECT)
        case sdl.GamepadButton.START:
            input_set_key(Keys.START)
        case sdl.GamepadButton.SOUTH:
            input_set_key(Keys.A)
        case sdl.GamepadButton.EAST:
            input_set_key(Keys.B)
        case sdl.GamepadButton.LEFT_SHOULDER:
            input_set_key(Keys.L)
        case sdl.GamepadButton.RIGHT_SHOULDER:
            input_set_key(Keys.R)
        }
    case sdl.EventType.KEY_UP:
        switch event.key.key {
        case sdl.K_DOWN:
            input_clear_key(Keys.DOWN)
        case sdl.K_UP:
            input_clear_key(Keys.UP)
        case sdl.K_LEFT:
            input_clear_key(Keys.LEFT)
        case sdl.K_RIGHT:
            input_clear_key(Keys.RIGHT)
        case sdl.K_Q:
            input_clear_key(Keys.SELECT)
        case sdl.K_W:
            input_clear_key(Keys.START)
        case sdl.K_Z:
            input_clear_key(Keys.A)
        case sdl.K_X:
            input_clear_key(Keys.B)
        case sdl.K_C:
            input_clear_key(Keys.L)
        case sdl.K_V:
            input_clear_key(Keys.R)
        }
    case sdl.EventType.GAMEPAD_BUTTON_UP:
        #partial switch sdl.GamepadButton(event.gbutton.button) {
        case sdl.GamepadButton.DPAD_DOWN:
            input_clear_key(Keys.DOWN)
        case sdl.GamepadButton.DPAD_UP:
            input_clear_key(Keys.UP)
        case sdl.GamepadButton.DPAD_LEFT:
            input_clear_key(Keys.LEFT)
        case sdl.GamepadButton.DPAD_RIGHT:
            input_clear_key(Keys.RIGHT)
        case sdl.GamepadButton.BACK:
            input_clear_key(Keys.SELECT)
        case sdl.GamepadButton.START:
            input_clear_key(Keys.START)
        case sdl.GamepadButton.SOUTH:
            input_clear_key(Keys.A)
        case sdl.GamepadButton.EAST:
            input_clear_key(Keys.B)
        case sdl.GamepadButton.LEFT_SHOULDER:
            input_clear_key(Keys.L)
        case sdl.GamepadButton.RIGHT_SHOULDER:
            input_clear_key(Keys.R)
        }
    }
}