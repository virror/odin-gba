package main

import "core:fmt"

Flash_mode :: enum {
    READY,
    ERASE,
    WRITE,
    BANK,
}

flash_bank: u8
id_mode: bool
flash_mode: Flash_mode
command_id: u32

// TODO:
// -Test!
// -128k support

flash_write :: proc(addr: u32, value: u8) {
    addr := addr
    if(flash_mode == Flash_mode.WRITE) {
        if(flash_bank == 1) {
            addr |= 0x10000
        }
        bus_write8(addr, value)
        flash_mode = Flash_mode.READY
    } else if(flash_mode == Flash_mode.BANK) {
        flash_bank = value
        flash_mode = Flash_mode.READY
    } else {
        if(command_id == 0 && value == 0xAA) {
            command_id = 1
        } else if(command_id == 1 && value == 0x55) {
            command_id = 2
        } else if (command_id == 2) {
            switch(value) {
            case 0x10: //Erase chip
                if(flash_mode == Flash_mode.ERASE) {
                    flash_erase()
                    flash_mode = Flash_mode.READY
                }
                break
            case 0x30: //Erase 4k sector
                if(flash_mode == Flash_mode.ERASE) {
                    flash_erase_sector(addr)
                    flash_mode = Flash_mode.READY
                }
                break
            case 0x80: //Prepare for erase
                flash_mode = Flash_mode.ERASE
                break
            case 0x90: //Enter id mode
                id_mode = true
                break
            case 0xA0: //Prepare write
                flash_mode = Flash_mode.WRITE
                break
            case 0xB0: //Set memory bank
                flash_mode = Flash_mode.BANK
                break
            case 0xF0: //Leave id mode
                id_mode = false
                break
            }
            command_id = 0
        } else {
            command_id = 0
        }
    }
}

flash_read :: proc(addr: u32) -> u8 {
    addr := addr
    if(flash_bank == 1) {
        addr |= 0x10000
    }
    if(id_mode) {
        if(addr == 0x0E000000) {
            return 0x62
        } else if(addr == 0x0E000001) {
            return 0x13
        }
    }
    return 0xFF//memory_ptr->read8(addr);
}

flash_erase :: proc() {
    for i :u32= 0xE000000; i <= 0xE00FFFF; i += 1 {
        bus_set8(i, 0xFF)
    }
}

flash_erase_sector :: proc(addr: u32) {
    addr_end := addr + 0xFFF
    for i :u32= addr; i <= addr_end; i += 1{
        bus_set8(i, 0xFF)
    }
}