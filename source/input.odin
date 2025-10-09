package main

import "core:fmt"
import "core:math"
import "core:strings"
import sdl "vendor:sdl3"

Mouse_button :: enum {
    left = 1,
    middle = 2,
    right = 3,
}

Mouse_state :: struct {
    position: Vector2f,
    button: map[Mouse_button]bool,
    prev_button: map[Mouse_button]bool,
}

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
@(private="file")
ui_blocking: bool
@(private="file")
window: ^sdl.Window
@(private="file")
input_string: string
@(private="file")
input_idx: int
@(private="file")
input_cursor: ^Ui_element
@(private="file")
input_text: ^Ui_element
@(private="file")
input_timer: f32

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

mouse_down :: proc(i: Mouse_button) -> bool {
    return mouse_state.button[i] && mouse_state.prev_button[i]
}

mouse_pressed_raw :: proc(i: Mouse_button) -> bool {
    return mouse_state.button[i] && !mouse_state.prev_button[i]
}

mouse_released_raw :: proc(i: Mouse_button) -> bool {
    return !mouse_state.button[i] && mouse_state.prev_button[i]
}

mouse_pressed :: proc(i: Mouse_button) -> bool {
    return mouse_state.button[i] && !mouse_state.prev_button[i] && !ui_blocking
}

mouse_released :: proc(i: Mouse_button) -> bool {
    return !mouse_state.button[i] && mouse_state.prev_button[i] && !ui_blocking
}

set_blocking :: proc(blocking: bool) {
    ui_blocking = blocking
}

input_reset :: proc() {
    clear(&mouse_state.prev_button)
    for k, v in mouse_state.button {
        mouse_state.prev_button[k] = v
    }
}

text_input_click :: proc(element: ^Ui_element) {
    if input_text == nil || element._input != input_text {
        text_input_stop()
        text_input_start(element)
    } else {
        posX: f32
        ratio := resolution.y / WIN_HEIGHT

        switch element.anchor {
        case .top_left, .middle_left, .bottom_left:
            posX = mouse_state.position.x / ratio
        case .top_center, .middle_center, .bottom_center:
            posX = (mouse_state.position.x - (resolution.x / 2)) / ratio
        case .top_right, .middle_right, .bottom_right:
            posX = (mouse_state.position.x - resolution.x) / ratio
        }
        posX = posX - input_text.position.x
        text_pos := f32(len(input_string)) * input_text.size.x
        if posX > text_pos {
            input_cursor.position.x = input_text.position.x + text_pos - (input_text.size.x / 2)
        } else {
            posX = math.round(posX / input_text.size.x) * input_text.size.x
            input_cursor.position.x = input_text.position.x + posX - (input_text.size.x / 2)
            input_idx = int(posX / input_text.size.x)
        }
    }
}

text_input_start :: proc(element: ^Ui_element) {
    if sdl.StartTextInput(window) {
        input_text = element._input
        if input_cursor == nil {
            input_cursor = ui_text({-3, 10}, 10, "|", .middle_left, element)
        }
        input_cursor.disabled = false
        input_cursor.size = element._input.size.y
        posX := -(element._input.size.x / 2) + f32(len(element._input.text)) * element._input.size.x
        input_cursor.position = element._input.position + {posX, 0}
        input_cursor.anchor = element._input.anchor
        input_string = element._input.text
        input_idx = len(element._input.text)
    }
}

text_input_stop :: proc() {
    if sdl.StopTextInput(window) {
        if input_cursor != nil {
            input_cursor.disabled = true
        }
        input_text = nil
    }
}

text_input_active :: proc() -> bool {
    return sdl.TextInputActive(window)
}

@(private="file")
text_input_add :: proc(sub_str: string) {
    if input_idx == 0 {
        a := []string { sub_str, input_string}
        input_string = strings.concatenate(a)
    } else if len(input_string) != input_idx {
        string1, _ := strings.substring(input_string, 0, input_idx)
        string2, _ := strings.substring(input_string, input_idx, len(input_string))
        a := []string { string1, sub_str, string2}
        input_string = strings.concatenate(a)
    } else {
        a := []string { input_string, sub_str}
        input_string = strings.concatenate(a)
    }
    input_text.text = input_string
    text_input_cursor(true)
}

@(private="file")
text_input_remove :: proc() {
    if input_idx == 0 {
        return
    } else if len(input_string) != input_idx {
        string1, _ := strings.substring(input_string, 0, input_idx - 1)
        string2, _ := strings.substring(input_string, input_idx, len(input_string))
        a := []string { string1, string2}
        input_string = strings.concatenate(a)
    } else {
        string1, _ := strings.substring(input_string, 0, input_idx - 1)
        input_string = string1
    }
    input_text.text = input_string
    text_input_cursor(false)
}

@(private="file")
text_input_move :: proc(left: bool) {
    if left {
        if input_idx > 0 {
            text_input_cursor(false)
        }
    } else {
        if input_idx < len(input_string) {
            text_input_cursor(true)
        }
    }
}

@(private="file")
text_input_home :: proc() {
    input_idx = 0
    input_cursor.position.x = input_text.position.x + -(input_text.size.x / 2)
    input_timer = 0
    input_cursor.disabled = false
}

@(private="file")
text_input_end :: proc() {
    input_idx = len(input_string)
    posX := -(input_text.size.x / 2) + f32(len(input_text.text)) * input_text.size.x
    input_cursor.position.x = input_text.position.x + posX
    input_timer = 0
    input_cursor.disabled = false
}

@(private="file")
text_input_cursor :: proc(add: bool) {
    if add {
        input_idx += 1
        input_cursor.position.x += input_text.size.x
    } else {
        input_idx -= 1
        input_cursor.position.x -= input_text.size.x
    }
    input_timer = 0
    input_cursor.disabled = false
}