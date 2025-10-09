package main

import "core:fmt"

TMCNT :: bit_field u8 {
    prescale: u8    |2,
    count_up: bool  |1,
    na: u8          |3,
    irq: bool       |1,
    enabled: bool   |1,
}

Timer :: struct {
    start_time: u16,
    counter: u32,
    prescale_cnt: u32,
    old_enabled: bool,
    count_up_timer: ^Timer,
    index: u8,
    tmcnt: TMCNT,
}

tmr_init :: proc(timer: ^Timer, index: u8) {
    timer.index = index
    switch(index) {
    case 0:
        timer.count_up_timer = &timer1
    case 1:
        timer.count_up_timer = &timer2
    case 2:
        timer.count_up_timer = &timer3
    }
}

tmr_step :: proc(timer: ^Timer, cycles: u32) {
    if(timer.tmcnt.enabled && !timer.tmcnt.count_up) { //Timer enabled and no count up
        switch(timer.tmcnt.prescale) {
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
    if(timer.tmcnt.enabled) {
        tmr_increment(timer, cycles)
    }
}

tmr_increment :: proc(timer: ^Timer, cycles: u32) {
    timer.counter += cycles
    if(timer.counter > 65535) { //Overflow
        timer.counter -= 65535
        timer.counter += u32(timer.start_time)
        if((timer.count_up_timer != nil) && timer.count_up_timer.tmcnt.count_up) {
            tmr_step_count_up(timer.count_up_timer, 1)
        }
        if(timer.tmcnt.irq) {
            bus_irq_set(timer.index + 3)
        }
        if(apu_a_timer() == timer.index) {
            apu_step_a()
        }
        if(apu_b_timer() == timer.index) {
            apu_step_b()
        }
    }
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
    timer.tmcnt = TMCNT(value)
    if(timer.tmcnt.enabled && (timer.tmcnt.enabled != timer.old_enabled)) {
        timer.counter = u32(timer.start_time)
        timer.old_enabled = timer.tmcnt.enabled
    }
}

tmr_write :: proc(addr: u32, value: u8) {
    switch(addr) {
    case IO_TM0CNT_L:
        timer0.start_time &= 0xFF00
        timer0.start_time |= u16(value)
    case IO_TM0CNT_L + 1:
        timer0.start_time &= 0x00FF
        timer0.start_time |= u16(value) << 8
    case IO_TM0CNT_H:
        tmr_set_control(&timer0, value)
    case IO_TM1CNT_L:
        timer1.start_time &= 0xFF00
        timer1.start_time |= u16(value)
    case IO_TM1CNT_L + 1:
        timer1.start_time &= 0x00FF
        timer1.start_time |= u16(value) << 8
    case IO_TM1CNT_H:
        tmr_set_control(&timer1, value)
    case IO_TM2CNT_L:
        timer2.start_time &= 0xFF00
        timer2.start_time |= u16(value)
    case IO_TM2CNT_L + 1:
        timer2.start_time &= 0x00FF
        timer2.start_time |= u16(value) << 8
    case IO_TM2CNT_H:
        tmr_set_control(&timer2, value)
    case IO_TM3CNT_L:
        timer3.start_time &= 0xFF00
        timer3.start_time |= u16(value)
    case IO_TM3CNT_L + 1:
        timer3.start_time &= 0x00FF
        timer3.start_time |= u16(value) << 8
    case IO_TM3CNT_H:
        tmr_set_control(&timer3, value)
    }
}

tmr_read :: proc(addr: u32) -> u8 {
    switch(addr) {
    case IO_TM0CNT_L:
        return u8(timer0.counter)
    case IO_TM0CNT_L + 1:
        return u8(timer0.counter >> 8)
    case IO_TM0CNT_H:
        return u8(timer0.tmcnt)
    case IO_TM1CNT_L:
        return u8(timer1.counter)
    case IO_TM1CNT_L + 1:
        return u8(timer1.counter >> 8)
    case IO_TM1CNT_H:
        return u8(timer1.tmcnt)
    case IO_TM2CNT_L:
        return u8(timer2.counter)
    case IO_TM2CNT_L + 1:
        return u8(timer2.counter >> 8)
    case IO_TM2CNT_H:
        return u8(timer2.tmcnt)
    case IO_TM3CNT_L:
        return u8(timer3.counter)
    case IO_TM3CNT_L + 1:
        return u8(timer3.counter >> 8)
    case IO_TM3CNT_H:
        return u8(timer3.tmcnt)
    }
    return 0
}