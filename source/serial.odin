package main

import "core:fmt"

sri_Mode :: enum {
  bit8,
  bit32,
  multiplay,
  uart,
  general,
  joybus,
}

sri_get_mode :: proc() -> sri_Mode {
    rcnt := bus_get16(IO_RCNT) & 0xC000
    siocnt := bus_get16(IO_SIOCNT) & 0x3000

    switch((rcnt | siocnt) >> 12) {
    case 0, 4:
        return .bit8
    case 1, 5:
        return .bit32
    case 2, 6:
        return .multiplay
    case 3, 7:
        return .uart
    case 8, 9, 10, 11:
        return .general
    case 12, 13, 14, 15:
        return .joybus
    }
    return .bit8
}

srl_write :: proc(addr: u32, value: u8) {
    bus_set8(addr, value)
}

srl_read :: proc(addr: u32) -> u8 {
    switch(addr) {
    case IO_SIOCNT:
        if(sri_get_mode() == .uart) {
            return bus_get8(addr) & 0xAF
        } else {
            return bus_get8(addr) & 0x8F
        }
    case IO_SIOCNT + 1:
        switch(sri_get_mode()) {
        case .multiplay:
            return bus_get8(addr) & 0x6F
        case .joybus,
             .general,
             .bit8:
            return bus_get8(addr) & 0x4F
        case .bit32:
            return bus_get8(addr) & 0x5F
        case .uart:
            return bus_get8(addr) & 0x7F
        }
    case IO_SIOMLT_SEND,
         IO_SIOMLT_SEND + 1:
        if(sri_get_mode() == .uart) {
            return 0
        } else {
            return bus_get8(addr)
        }
    case IO_RCNT:
        switch(sri_get_mode()) {
        case .bit8,
             .bit32:
            return bus_get8(addr) & 0xF5
        case .multiplay,
             .uart,
             .general:
            return bus_get8(addr)
        case .joybus:
            return bus_get8(addr) & 0xFC
        }
    case IO_RCNT + 1:
        switch(sri_get_mode()) {
        case .bit8,
             .bit32,
             .multiplay,
             .uart:
            return bus_get8(addr) & 0x01
        case .general:
            return bus_get8(addr) & 0x81
        case .joybus:
            return bus_get8(addr) & 0xC1
        }
    case IO_JOYCNT:
        return bus_get8(addr) & 0x40
    case IO_JOYCNT + 1:
        return 0
    case IO_SIOMULTI0,
         IO_SIOMULTI0 + 1,
         IO_SIOMULTI1,
         IO_SIOMULTI1 + 1:
        if(sri_get_mode() == .bit32) {
            return bus_get8(addr)
        } else {
            return 0
        }
    }
    return 0
}