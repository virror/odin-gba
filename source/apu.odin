package main

import "core:fmt"

direct_sound_a_counter: u16
direct_sound_b_counter: u16
direct_sound_a_out: u8
direct_sound_b_out: u8

apu_load_length_counter_square1 :: proc(len: u8) {
    //square1.length_counter = len
}

apu_load_length_counter_square2 :: proc(len: u8) {
    //square2.length_counter = len
}

// void load_length_counter_wave(int len)
// {
//     wave.length_counter = len;
// }

apu_load_length_counter_noise :: proc(len: u8) {
    //noise.length_counter = len
}

apu_trigger_square1 :: proc() {
    //trigger(square1)
}

apu_trigger_square2 :: proc() {
    //trigger(square2)
}

apu_trigger_noise :: proc() {
    //trigger(noise)
}

apu_reset_fifo_a :: proc() {
    direct_sound_a_counter = 0
}

apu_reset_fifo_b :: proc() {
    direct_sound_b_counter = 0
}

apu_load_fifo_a :: proc(data: u8) {
    /*direct_sound_a_buffer[direct_sound_a_counter += 1] = data
    if (direct_sound_a_counter > 15)
        direct_sound_a_counter = 0*/
}

apu_load_fifo_b :: proc(data: u8) {
    /*direct_sound_b_buffer[direct_sound_b_counter++] = data
    if (direct_sound_b_counter > 15)
        direct_sound_b_counter = 0*/
}