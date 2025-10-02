package main

import "core:fmt"

Timer :: struct {
    start_time: u16,
    counter: u32,
    prescale: u16,
    prescale_cnt: u32,
    count_up: bool,
    irq: bool,
    enabled: bool,
    old_enabled: bool,
    count_up_timer: ^Timer,
    index: u8,
}

tmr_init :: proc(timer: ^Timer, index: u8) {
    timer.index = index
}

tmr_step :: proc(timer: ^Timer, cycles: u32) {
    if(timer.enabled && !timer.count_up) { //Timer enabled and no count up
        switch(timer.prescale) {
        case 0:
            tmr_increment(timer, cycles)
            break
        case 1:
            timer.prescale_cnt += cycles
            if(timer.prescale_cnt > 64) {
                timer.prescale_cnt -= 64
                tmr_increment(timer, 1)
            }
            break
        case 2:
            timer.prescale_cnt += cycles
            if(timer.prescale_cnt > 256) {
                timer.prescale_cnt -= 256
                tmr_increment(timer, 1)
            }
            break
        case 3:
            timer.prescale_cnt += cycles
            if(timer.prescale_cnt > 1024) {
                timer.prescale_cnt -= 1024
                tmr_increment(timer, 1)
            }
            break
        }
    }
}

tmr_step_count_up :: proc(timer: ^Timer, cycles: u32) {
    if(timer.enabled) {
        tmr_increment(timer, cycles)
    }
}

tmr_increment :: proc(timer: ^Timer, cycles: u32) {
    timer.counter += cycles
    if(timer.counter > 65535) { //Overflow
        timer.counter -= 65535
        timer.counter += u32(timer.start_time)
        if((timer.count_up_timer != nil) && timer.count_up_timer.count_up) {
            tmr_step_count_up(timer.count_up_timer, 1)
        }
        if(timer.irq) {
            iflags := bus_get16(IO_IF)
            iflags = utils_bit_set16(iflags, timer.index + 3)
            bus_set16(IO_IF, iflags)
        }
        if(apu_a_timer() == timer.index) {
            apu_step_a()
        }
        if(apu_b_timer() == timer.index) {
            apu_step_b()
        }
    }
    //*(uint16_t *)memory = (uint16_t)counter //TMxCNT_L
    bus_set16(IO_TM0CNT_L + u32(timer.index * 4), u16(timer.counter))
}

tmr_set_start_time :: proc(timer: ^Timer, value: u8, high_byte: bool) {
    if(high_byte) {
        timer.start_time &= 0xFF
        timer.start_time |= u16(value) << 8
    } else {
        timer.start_time &= 0xFF00
        timer.start_time |= u16(value)
    }
}

tmr_set_control :: proc(timer: ^Timer, value: u8) {
    timer.prescale = u16(value) & 0x3
    timer.count_up = utils_bit_get16(u16(value), 2)
    timer.irq = utils_bit_get16(u16(value), 6)
    timer.enabled = utils_bit_get16(u16(value), 7)
    if(timer.enabled && (timer.enabled != timer.old_enabled)) {
        timer.counter = u32(timer.start_time)
        //*(uint16_t *)memory = timer.start_time //TMxCNT_L
        timer.old_enabled = timer.enabled
    }
}