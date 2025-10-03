package main

import "core:fmt"
import "core:os"

 Save_type :: enum {
    UNDEFINED,
    SRAM,
    FLASH,
}

mem: [0xE010000]u8
ram_write: bool
save_type: Save_type

bus_load_bios :: proc() {
    file, err := os.open("gba_bios.bin", os.O_RDONLY)
    assert(err == nil, "Failed to open bios")
    _, err2 := os.read(file, mem[:])
    assert(err2 == nil, "Failed to read bios data")
    os.close(file)
}

bus_load_rom :: proc(path: string) {
    file, err := os.open(path, os.O_RDONLY)
    assert(err == nil, "Failed to open rom")
    _, err2 := os.read(file, mem[0x08000000:])
    assert(err2 == nil, "Failed to read rom data")
    os.close(file)
}

bus_get8 :: proc(addr: u32) -> u8 {
    return mem[addr]
}

bus_set8 :: proc(addr: u32, value: u8) {
    mem[addr] = value
}

bus_read8 :: proc(addr: u32) -> u8 {
    when TEST_ENABLE {
        return u8(test_read32(addr))
    } else {
        addr := addr
        addr_id := addr & 0xF000000
        switch(addr_id) {
        case 0x0000000: //BIOS
            // BIOS is read protected, when trying to read from BIOS, the last read value will be returned.
            //return last_bios_value
            if((addr >= 0x00004000 && addr < 0x02000000) || addr >= 0x10000000) {
                //TODO: Return whats on the bus, e.g recently fetched opcode for ARM, more complicated for THUMB
                fmt.println("Fix read of out bounds")
                return 0x0
            }
            break
        case 0x2000000: //WRAM
            addr &= 0x303FFFF
            break
        case 0x3000000: //WRAM
            addr &= 0x3007FFF
            break
        //case 0x4000000: //IO
        //    break
        case 0x5000000: //Palette RAM
            addr &= 0x50003FF
            break
        case 0x6000000: //VRAM
            addr &= 0x601FFFF
            if(addr >= 0x6018000) {
                addr -= 0x8000
            }
            break
        case 0x7000000: //OBJ RAM
            addr &= 0x70003FF
            break
        case 0xE000000:
            addr &= 0xE00FFFF
            switch(save_type) {
            case Save_type.UNDEFINED:
                save_type = Save_type.SRAM
                break
            case Save_type.FLASH:
                return flash_read(addr)
            case Save_type.SRAM:
                break
            }
            break
        }
        return mem[addr]
    }
}

bus_write8 :: proc(addr: u32, value: u8) {
    when TEST_ENABLE {
        test_write32(addr, u32(value))
    } else {
        addr := addr
        addr_id := addr & 0xF000000
        switch(addr_id) {
        case 0x0000000: //BIOS
            return //Read only
        case 0x2000000: //WRAM
            addr &= 0x303FFFF
            break
        case 0x3000000: //WRAM
            addr &= 0x3007FFF
            break
        case 0x4000000: //IO
            if(!bus_handle_io(addr, value)) {
                return
            }
            break
        case 0x5000000: //Palette RAM
            addr &= 0x50003FF
            break
        case 0x6000000: //VRAM
            addr &= 0x601FFFF
            if(addr >= 0x6018000) {
                addr -= 0x8000
            }
            break
        case 0x7000000: //OBJ RAM
            addr &= 0x70003FF
            break
        case 0x8000000, //ROM
             0x9000000,
             0xA000000,
             0xB000000,
             0xC000000,
             0xD000000:
            return //Read only
        case 0xE000000:
            addr &= 0xE00FFFF
            switch(save_type) {
            case Save_type.UNDEFINED:
                if(addr == 0xE005555 && value == 0xAA) {
                    save_type = Save_type.FLASH
                    flash_write(addr, value)
                }
                break
            case Save_type.FLASH:
                flash_write(addr, value)
                return
            case Save_type.SRAM:
                break
            }
            ram_write = true
            break
        }
        mem[addr] = value
    }
}

bus_get16 :: proc(addr: u32) -> u16 {
    when TEST_ENABLE {
        return u16(test_read32(addr))
    } else {
        return (cast(^u16)&mem[addr])^
    }
}

bus_set16 :: proc(addr: u32, value: u16) {
    (cast(^u16)&mem[addr])^ = value
}

bus_read16 :: proc(addr: u32) -> u16 {
    when TEST_ENABLE {
        return u16(test_read32(addr))
    } else {
        addr := addr
        addr &= 0xFFFFFFFE
        value := u16(bus_read8(addr))
        value |= (u16(bus_read8(addr + 1))) << 8
        return value
    }
}

bus_write16 :: proc(addr: u32, value: u16) {
    when TEST_ENABLE {
        test_write32(addr, u32(value))
    } else {
        addr := addr
        addr &= 0xFFFFFFFE
        bus_write8(addr, u8(value & 0x00FF))
        bus_write8(addr + 1, u8((value & 0xFF00) >> 8))
    }
}

bus_get32 :: proc(addr: u32) -> u32 {
    addr := addr
    addr &= 0xFFFFFFFC
    when TEST_ENABLE {
        return test_read32(addr)
    } else {
        return (cast(^u32)&mem[addr])^
    }
}

bus_set32 :: proc(addr: u32, value: u32) {
    when TEST_ENABLE {
        test_write32(addr, value)
    } else {
        (cast(^u32)&mem[addr])^ = value
    }
}

bus_read32 :: proc(addr: u32) -> u32 {
    when TEST_ENABLE {
        return test_read32(addr)
    } else {
        addr := addr
        addr &= 0xFFFFFFFC
        value := u32(bus_read8(addr))
        value |= (u32(bus_read8(addr + 1)) << 8)
        value |= (u32(bus_read8(addr + 2)) << 16)
        value |= (u32(bus_read8(addr + 3)) << 24)
        return value
    }
}

bus_write32 :: proc(addr: u32, value: u32) {
    when TEST_ENABLE {
        test_write32(addr, value)
    } else {
        addr := addr
        addr &= 0xFFFFFFFC
        bus_write8(addr, u8(value & 0x000000FF))
        bus_write8(addr + 1, u8((value & 0x0000FF00) >> 8))
        bus_write8(addr + 2, u8((value & 0x00FF0000) >> 16))
        bus_write8(addr + 3, u8((value & 0xFF000000) >> 24))
    }
}

bus_irq_set :: proc(bit: u8) {
    mem[IO_IF] = utils_bit_set8(mem[IO_IF], bit)
}

bus_save_ram :: proc() {
    if(ram_write) {
        /*//std::filesystem::create_directory("saves")
        std::ofstream myfile (ram_save_filename, std::ios::binary)
        if (myfile.is_open()) {
            for(int i = 0xE000000 i < 0xE00FFFF i++) {
                myfile << mem[i]
            }
            myfile.close()
        }
        else {
            std::cout << "Unable to save RAM"
        }*/
    }
}

bus_load_ram :: proc() {
    /*std::ifstream ram_file (ram_save_filename, std::ios::binary)
    if (ram_file.is_open()) {
        for(int i = 0xE000000 i < 0xE00FFFF i++) {
            ram_file.read((char *)&mem[i], sizeof(uint8_t))
        }
        ram_file.close()
    }*/
}

bus_handle_io :: proc(addr: u32, value: u8) -> bool {
    switch(addr) {
    //Interrupts - Writing one resets the flag
    case IO_IF, IO_IF + 1:
        mem[addr] = (~value) & mem[addr]
        return false
    //Timers
    case IO_TM0CNT_L:
        tmr_set_start_time(&timer0, value, false)
        return false
    case IO_TM0CNT_L + 1:
        tmr_set_start_time(&timer0, value, true)
        return false
    case IO_TM0CNT_H:
        tmr_set_control(&timer0, value)
        break
    case IO_TM1CNT_L:
        tmr_set_start_time(&timer1, value, false)
        return false
    case IO_TM1CNT_L + 1:
        tmr_set_start_time(&timer1, value, true)
        return false
    case IO_TM1CNT_H:
        tmr_set_control(&timer1, value)
        break
    case IO_TM2CNT_L:
        tmr_set_start_time(&timer2, value, false)
        return false
    case IO_TM2CNT_L + 1:
        tmr_set_start_time(&timer2, value, true)
        return false
    case IO_TM2CNT_H:
        tmr_set_control(&timer2, value)
        break
    case IO_TM3CNT_L:
        tmr_set_start_time(&timer3, value, false)
        return false
    case IO_TM3CNT_L + 1:
        tmr_set_start_time(&timer3, value, true)
        return false
    case IO_TM3CNT_H:
        tmr_set_control(&timer3, value)
        break
    case IO_DMA0CNT_H + 1:
        mem[addr] = value
        dma_set_data(&dma0)
        return false
    case IO_DMA1CNT_H + 1:
        mem[addr] = value
        dma_set_data(&dma1)
        return false
    case IO_DMA2CNT_H + 1:
        mem[addr] = value
        dma_set_data(&dma2)
        return false
    case IO_DMA3CNT_H + 1:
        mem[addr] = value
        dma_set_data(&dma3)
        return false
    case IO_HALTCNT:
        if(utils_bit_get16(u16(value), 7)) {
            stop = true
        } else {
            halt = true
        }
        return false
    case IO_SOUND1CNT_H: // -> length
        apu_load_length_counter_square1(value & 0x3f)
        mem[addr] = value // TODO: remove?
        break
    case IO_SOUND1CNT_X + 1: // -> trigger
        if (value & 0x80) > 1 {
            apu_trigger_square1()
        }
        mem[addr] = value
        break
    case IO_SOUND2CNT_L: // -> length
        apu_load_length_counter_square2(value & 0x3f)
        // TODO: read ones?
        break
    case IO_SOUND2CNT_H + 1: // -> trigger
        if (value & 0x80) > 1 {
            apu_trigger_square2()
        }
        break
    case IO_SOUND4CNT_L: // -> length
        apu_load_length_counter_noise(value & 0x3f)
        // TODO: read ones?
        break
    case IO_SOUND4CNT_H + 1: // -> trigger
        if (value & 0x80) > 0 {
            apu_trigger_noise()
        }
        break
    case IO_DISPSTAT:
        dispstat := mem[IO_DISPSTAT]
        dispstat &= 0x07
        value1 := value & 0xF8
        dispstat |= value1
        //TODO: Should save value and return 0?
        break
    case IO_SOUNDCNT_H:
        // FIFO A reset
        if (value & 0x08) > 1 {
            apu_reset_fifo_a()
        }
        // FIFO B reset
        if (value & 0x80) > 1 {
            apu_reset_fifo_b()
        }
        break
    // Last byte of FIFO A
    case IO_FIFO_A_H + 1:
        apu_load_fifo_a(mem[IO_FIFO_A_L])
        apu_load_fifo_a(mem[IO_FIFO_A_L + 1])
        apu_load_fifo_a(mem[IO_FIFO_A_H])
        apu_load_fifo_a(mem[IO_FIFO_A_H + 1])
        break
    // Last byte of FIFO B
    case IO_FIFO_B_H + 1:
        apu_load_fifo_b(mem[IO_FIFO_B_L])
        apu_load_fifo_b(mem[IO_FIFO_B_L + 1])
        apu_load_fifo_b(mem[IO_FIFO_B_H])
        apu_load_fifo_b(mem[IO_FIFO_B_H + 1])
        break
    case IO_KEYINPUT,
         IO_KEYINPUT + 1,
         IO_VCOUNT:
        return false // Read only
    }
    return true
}