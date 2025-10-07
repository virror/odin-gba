package main

import "core:fmt"

Dma :: struct {
    enabled: bool,
    old_enabled: bool,
    mode: u16,
    src_ctrl: u16,
    dst_ctrl: u16,
    dst_mod: u16,
    src_reg: u32,
    dst_reg: u32,
    cnt_reg: u32,
    ctrl_reg: u32,
    int_dst_reg: u32,
    int_src_reg: u32,
    dma_32: bool,
    repeat: bool,
    drq: bool,
    irq: bool,
    idx: u32,
}

dma_init :: proc(dma: ^Dma, index: u32) {
    dma.src_reg = IO_DMA0SAD + index * 12
    dma.dst_reg = IO_DMA0DAD + index * 12
    dma.cnt_reg = IO_DMA0CNT_L + index * 12
    dma.ctrl_reg = IO_DMA0CNT_H + index * 12
    dma.idx = index
}

dma_set_data :: proc(dma: ^Dma) {
    ctrl := bus_get16(dma.ctrl_reg)

    dma.dst_ctrl = (ctrl & 0x60) >> 5
    dma.src_ctrl = (ctrl & 0x180) >> 7
    dma.repeat = utils_bit_get16(ctrl, 9)
    dma.dma_32 = utils_bit_get16(ctrl, 10)
    dma.drq = utils_bit_get16(ctrl, 11)
    dma.mode = (ctrl & 0x3000) >> 12
    dma.irq = utils_bit_get16(ctrl, 14)
    dma.enabled = utils_bit_get16(ctrl, 15)

    if(dma.enabled && (dma.enabled != dma.old_enabled)) {
        dma.old_enabled = dma.enabled
        dma.int_src_reg = bus_read32(dma.src_reg)
        dma.int_dst_reg = bus_read32(dma.dst_reg)
        if(dma.mode == 0) {
            dma_single_transfer(dma)
        }
    } else if(!dma.enabled && (dma.enabled != dma.old_enabled)) {
        dma_stop(dma)
    }
}

dma_stop :: proc(dma: ^Dma) {
    ctrl := bus_get16(dma.ctrl_reg)
    dma.enabled = false
    dma.old_enabled = false
    ctrl = utils_bit_clear16(ctrl, 15)
    bus_set16(dma.ctrl_reg, ctrl)
}

dma_single_transfer :: proc(dma: ^Dma) {
    // src/dst are 16 bit values
    dst := dma.int_dst_reg
    src := dma.int_src_reg
    dst_mod :i16= 2
    switch(dma.dst_ctrl) {
    case 1:
        dst_mod = -2
        break
    case 2:
        dst_mod = 0
        break
    case:
        dst_mod = 2
    }
    src_mod :i16= 2
    switch(dma.src_ctrl) {
    case 1:
        src_mod = -2
        break
    case 2:
        src_mod = 0
        break
    case:
        src_mod = 2
    }
    if (dma.dma_32) {
        dst_mod *= 2
        src_mod *= 2
        dst &= 0xFFFFFFFC
        src &= 0xFFFFFFFC
    } else {
        dst &= 0xFFFFFFFE
        src &= 0xFFFFFFFE
    }

    cnt := u32(bus_get16(dma.cnt_reg))
    if(dma.idx == 0) {
        src &= 0x7FFFFFF
        cnt = min(cnt, 0x4000)
    } else {
        cnt = min(cnt, 0x10000)
    }
    if(dma.idx != 3) {
        dst &= 0x7FFFFFF
    }

    for i :u32= 0; i < cnt; i += 1 {
        if(dma.dma_32) {
            bus_write32(dst, bus_read32(src))
        } else {
            bus_write16(dst, bus_read16(src))
        }

        dst = u32(i32(dst) + i32(dst_mod))
        dma.int_dst_reg = u32(i32(dma.int_dst_reg) + i32(dst_mod))

        src = u32(i32(src) + i32(src_mod))
        dma.int_src_reg = u32(i32(dma.int_src_reg) + i32(src_mod))
    }
    if(dma.repeat) {
        if(dma.dst_ctrl == 3) {
            dma.int_dst_reg = u32(bus_get16(dma.dst_reg))
        }
    } else {
        dma_stop(dma)
    }
}

dma_request_fifo_data :: proc(dma: ^Dma) {
    if(dma.enabled && dma.mode == 3) { // Audio FIFO mode
        dma.dst_ctrl = 2
        dma_single_transfer(dma)
    }
}

dma_transfer_v_blank :: proc(dma: ^Dma) {
    if(dma.enabled && dma.mode == 1) {
        dma_single_transfer(dma)
    }
}

dma_transfer_h_blank :: proc(dma: ^Dma) {
    if(dma.enabled && dma.mode == 2) {
        dma_single_transfer(dma)
    }
}