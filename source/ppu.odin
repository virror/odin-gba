package main

import "core:fmt"

OAM :u32: 0x07000000
BG_PALETTE :u32: 0x05000000
OB_PALETTE :u32: 0x05000200
VRAM :u32: 0x06000000
OVRAM :u32: 0x06010000

Ppu_states :: enum {
    DRAW,
    HBLANK,
    VBLANK_DRAW,
    VBLANK_HBLANK,
}

cycle_count: u32
line_count: u16
current_state: Ppu_states
dispstat: u16
screen_buffer: [WIN_WIDTH * WIN_WIDTH]u16

ppu_step :: proc(cycles: u32) -> bool {
    ready_draw: bool
    cycle_count += cycles
    dispstat = bus_get16(IO_DISPSTAT)

    if(stop) {
        return false
    }

    switch(current_state) {
    case .DRAW:
        if(cycle_count > 960) { // Go to H-BLANK
            current_state = Ppu_states.HBLANK
            cycle_count -= 960
            dispstat = utils_bit_set16(dispstat, 1)
            dma_transfer_h_blank(&dma0)
            dma_transfer_h_blank(&dma1)
            dma_transfer_h_blank(&dma2)
            dma_transfer_h_blank(&dma3)
            if(utils_bit_get16(dispstat, 4)) {
                bus_irq_set(1)
            }
            dispcnt := bus_get16(IO_DISPCNT)
            mode := dispcnt & 0x7
            switch(mode) {
            case 0:
                ppu_draw_mode_0(dispcnt)
                break
            case 1:
                ppu_draw_mode_1(dispcnt)
                break
            case 2:
                ppu_draw_mode_2(dispcnt)
                break
            case 3:
                ppu_draw_mode_3()
                break
            case 4:
                ppu_draw_mode_4(dispcnt)
                break
            case 5:
                ppu_draw_mode_5(dispcnt)
                break
            }
        }
        break
    case .HBLANK:
        if(cycle_count > 272) {
            cycle_count -= 272
            if(line_count >= 159) { //End of draw, go to VBLANK
                current_state = Ppu_states.VBLANK_DRAW
                dispstat = utils_bit_set16(dispstat, 0)
                ready_draw = true //Signal to draw screen
                dma_transfer_v_blank(&dma0)
                dma_transfer_v_blank(&dma1)
                dma_transfer_v_blank(&dma2)
                dma_transfer_v_blank(&dma3)
                if(utils_bit_get16(dispstat, 3)) {
                    bus_irq_set(0)
                }
            } else { //Go and draw next line
                current_state = Ppu_states.DRAW
            }
            ppu_set_line(line_count + 1)
            dispstat = utils_bit_clear16(dispstat, 1)
        }
        break
    case .VBLANK_DRAW:
        if(cycle_count > 960) { //End of VBLANK, loop back
            current_state = Ppu_states.VBLANK_HBLANK
            cycle_count -= 960
            dispstat = utils_bit_set16(dispstat, 1)
        }
        break
    case .VBLANK_HBLANK:
        if(line_count == 227) {
            dispstat = utils_bit_clear16(dispstat, 0)
        }
        if(cycle_count > 272) {
            cycle_count -= 272
            if(line_count >= 227) { //End of VBLANK, loop back
                current_state = Ppu_states.DRAW
                ppu_set_line(0)
            } else {
                current_state = Ppu_states.VBLANK_DRAW
                ppu_set_line(line_count + 1)
            }
            dispstat = utils_bit_clear16(dispstat, 1)
        }
        break
    }
    bus_set16(IO_DISPSTAT, dispstat)
    return ready_draw
}

ppu_set_line :: proc(count: u16) {
    line_count = count
    vcount := (dispstat >> 8)
    if(vcount == line_count) {
        dispstat = utils_bit_set16(dispstat, 2)
        if(utils_bit_get16(dispstat, 5)) {
            bus_irq_set(2)
        }
    } else {
        dispstat = utils_bit_clear16(dispstat, 2)
    }
    bus_set16(IO_VCOUNT, line_count)
}

ppu_draw_mode_0 :: proc(dispcnt: u16) {
    sprites: [4][128]u64
    length: [4]u32
    obj_map_1d := utils_bit_get16(dispcnt, 6)
    obj_on := utils_bit_get16(dispcnt, 12)

    if(obj_on) {
        for k :u32= 127; k == 0; k -= 1 {
            attr := u64(bus_get32(OAM + k * 8))
            attr += (u64(bus_get32(OAM + k * 8 + 4))) << 32

            if(attr == 0) {
                continue
            }

            priority := u16((attr & 0xC0000000000) >> 42)
            sprites[priority][length[priority]] = attr
            length[priority] += 1
        }
    }

    if(utils_bit_get16(dispcnt, 11)) {
        ppu_draw_tiles(3)
    }
    if(obj_on) {
        ppu_draw_sprites(sprites[3], length[3], obj_map_1d)
    }
    if(utils_bit_get16(dispcnt, 10)) {
        ppu_draw_tiles(2)
    }
    if(obj_on) {
        ppu_draw_sprites(sprites[2], length[2], obj_map_1d)
    }
    if(utils_bit_get16(dispcnt, 9)) {
        ppu_draw_tiles(1)
    }
    if(obj_on) {
        ppu_draw_sprites(sprites[1], length[1], obj_map_1d)
    }
    if(utils_bit_get16(dispcnt, 8)) {
        ppu_draw_tiles(0)
    }
    if(obj_on) {
        ppu_draw_sprites(sprites[0], length[0], obj_map_1d)
    }
}

ppu_draw_mode_1 :: proc(dispcnt: u16) {
    if(utils_bit_get16(dispcnt, 10)) {
        ppu_draw_tiles_aff(2)
    }
    if(utils_bit_get16(dispcnt, 9)) {
        ppu_draw_tiles(1)
    }
    if(utils_bit_get16(dispcnt, 8)) {
        ppu_draw_tiles(0)
    }
}

ppu_draw_mode_2 :: proc(dispcnt: u16) {
    if(utils_bit_get16(dispcnt, 11)) {
        ppu_draw_tiles_aff(3)
    }
    if(utils_bit_get16(dispcnt, 10)) {
        ppu_draw_tiles_aff(2)
    }
}

ppu_draw_mode_3 :: proc() {
    for i :u32= 0; i < 240; i += 1 {
        pixel := (u32(line_count) * 240) + i
        data := bus_get16(VRAM + pixel * 2)
        screen_buffer[pixel] = data
    }
}

ppu_draw_mode_4 :: proc(dispcnt: u16) {
    start := VRAM
    if(utils_bit_get16(dispcnt, 4)) {
        start += 0xA000
    }
    for i :u32= 0; i < 240; i += 1 {
        pixel := (u32(line_count) * 240) + i
        palette := bus_get8(start + pixel)
        if(palette != 0) {
            data := bus_get16(BG_PALETTE + (u32(palette) * 2))
            screen_buffer[pixel] = data
        } else {
            screen_buffer[pixel] = bus_get16(BG_PALETTE)
        }
    }
}

ppu_draw_mode_5 :: proc(dispcnt: u16) {
    //TODO: Implement screen shift?
    start := VRAM
    if(utils_bit_get16(dispcnt, 4)) {
        start += 0xA000
    }
    for i :u32= 0; i < 240; i += 1 {
        pixel := (u32(line_count) * 240) + i
        if(line_count >= 128) {
            screen_buffer[pixel] = bus_get16(BG_PALETTE)
            continue
        } else if(i >= 160) {
            screen_buffer[pixel] = bus_get16(BG_PALETTE)
            continue
        } else {
            data := bus_get16(start + (pixel * 2))
            screen_buffer[pixel] = data
        }
    }
}

ppu_draw_tiles :: proc(bg_index: u32) {
    bgcnt: u16
    bghofs: u16
    bgvofs: u16
    switch(bg_index) {
    case 0:
        bgcnt = bus_get16(IO_BG0CNT)
        bghofs = bus_get16(IO_BG0HOFS)
        bgvofs = bus_get16(IO_BG0VOFS)
        break
    case 1:
        bgcnt = bus_get16(IO_BG1CNT)
        bghofs = bus_get16(IO_BG1HOFS)
        bgvofs = bus_get16(IO_BG1VOFS)
        break
    case 2:
        bgcnt = bus_get16(IO_BG2CNT)
        bghofs = bus_get16(IO_BG2HOFS)
        bgvofs = bus_get16(IO_BG2VOFS)
        break
    case 3:
        bgcnt = bus_get16(IO_BG3CNT)
        bghofs = bus_get16(IO_BG3HOFS)
        bgvofs = bus_get16(IO_BG3VOFS)
        break
    }

    screen_size := (bgcnt & 0xC000) >> 14
    palette_256 := utils_bit_get16(bgcnt, 7)
    tile_data := VRAM + ((u32(bgcnt & 0x000C) >> 2) * 0x4000)
    map_data := VRAM + ((u32(bgcnt & 0x1F00) >> 8) * 0x800)
    hofs_mask: u16
    vofs_mask: u16

    switch(screen_size) {
    case 0:
        hofs_mask = 0x0FF
        vofs_mask = 0x0FF
        break
    case 1:
        hofs_mask = 0x1FF
        vofs_mask = 0x0FF
        break
    case 2:
        hofs_mask = 0x0FF
        vofs_mask = 0x1FF
        break
    case 3:
        hofs_mask = 0x1FF
        vofs_mask = 0x1FF
        break
    }

    bghofs = bghofs & hofs_mask
    bgvofs = bgvofs & vofs_mask
    y_coord := (line_count + bgvofs) & vofs_mask
    y_tile := y_coord / 8

    for i :u16= 0; i < 240; i += 1 {
        y_in_tile := y_coord % 8
        x_coord := (i + bghofs) & hofs_mask
        x_tile := x_coord / 8
        x_in_tile := u32(x_coord % 8)
        tile: u16

        if(x_coord >= 256 && y_coord >= 256) {
            tile = bus_get16(map_data + u32((x_tile - 32) + ((y_tile - 32) * 32) + 3072) * 2)
        } else if(x_coord >= 256) {
            tile = bus_get16(map_data + u32((x_tile - 32) + (y_tile * 32) + 1024) * 2)
        } else if(y_coord >= 256) {
            tile = bus_get16(map_data + u32(x_tile + ((y_tile - 32) * 32) + 2048) * 2)
        } else {
            tile = bus_get16(map_data + u32(x_tile + (y_tile * 32)) * 2)
        }

        if(utils_bit_get16(tile, 10)) { //Flip X
            x_in_tile = 7 - x_in_tile
        }
        if(utils_bit_get16(tile, 11)) { //Flip Y
            y_in_tile = 7 - y_in_tile
        }

        color: u16
        if(palette_256) {
            color = ppu_draw_256_1(tile, tile_data, y_in_tile, x_in_tile)
        } else {
            color = ppu_draw_16_16(tile, tile_data, y_in_tile, x_in_tile)
        }
        pixel := ((line_count * 240) + i)
        if(color != 0x8000) {
            screen_buffer[pixel] = color
        }
    }
}

ppu_draw_tiles_aff :: proc(bg_index: u32) {
    //Not implemented
}

ppu_draw_256_1 :: proc(tile: u16, tile_data: u32, y_in_tile: u16, x_in_tile: u32) -> u16 {
    tile_num := u32(tile & 0x03FF) * 64 //64 -> 8-bits per pixel and 8 rows per tile = 8 * 8 = 64
    data_addr := tile_data + tile_num + u32(y_in_tile * 8)
    data := u64(bus_get32(data_addr))
    data += u64(bus_get32(data_addr + 4)) << 32
    palette_mask := 0x00000000000000FF << u64(x_in_tile * 8)
    palette_offset := u32(((data & u64(palette_mask)) >> u64(x_in_tile * 8)) * 2)
    if(palette_offset != 0) {
        return bus_read16(BG_PALETTE + palette_offset)
    }
    return 0x8000
}

ppu_draw_16_16 :: proc(tile: u16, tile_data: u32, y_in_tile: u16, x_in_tile: u32) -> u16{
    tile_num := (tile & 0x03FF) * 32 //32 -> 4-bits per pixel and 8 rows per tile = 4 * 8 = 32
    data_addr := tile_data + u32(tile_num) + u32(y_in_tile) * 4
    data := bus_get32(data_addr)
    palette_mask := u32(0x0000000F << (x_in_tile * 4))
    palette_offset := ((data & palette_mask) >> (x_in_tile * 4)) * 2
    if(palette_offset != 0) {
        palette_num := ((tile & 0xF000) >> 12) * 32
        palette_offset += u32(palette_num)
        return bus_read16(BG_PALETTE + palette_offset)
    }
    return 0x8000
}

ppu_draw_sprites :: proc(sprites: [128]u64, length: u32, one_dimensional: bool) {
    for k :u32= 0; k < length; k += 1 {
        sprite := sprites[k]
        y_coord := i16(sprite & 0xFF)
        if(y_coord > 159) {
            y_coord = i16(utils_sign_extend32(u32(y_coord), 8))
        }
        //bool rot_scale = bit_get(sprite, 8);
        //bool double_size = bit_get(sprite, 9);
        //bool mosaic = bit_get(sprite, 12);
        //bool palette_256 = bit_get(sprite, 13);
        x_coord := u32(sprite & 0x1FF0000) >> 16
        x_coord = utils_sign_extend32(x_coord, 9)
        hflip := utils_bit_get64(sprite, 28)
        vflip := utils_bit_get64(sprite, 29)
        size := (sprite & 0xC0000000) >> 30
        size |= (sprite & 0xC000) >> 12
        sizeX: u8
        sizeY: u8
        switch(size) {
        case 0:
            sizeX = 8
            sizeY = 8
            break
        case 1:
            sizeX = 16
            sizeY = 16
            break
        case 2:
            sizeX = 32
            sizeY = 32
            break
        case 3:
            sizeX = 64
            sizeY = 64
            break
        case 4:
            sizeX = 16
            sizeY = 8
            break
        case 5:
            sizeX = 32
            sizeY = 8
            break
        case 6:
            sizeX = 32
            sizeY = 16
            break
        case 7:
            sizeX = 64
            sizeY = 32
            break
        case 8:
            sizeX = 8
            sizeY = 16
            break
        case 9:
            sizeX = 8
            sizeY = 32
            break
        case 10:
            sizeX = 16
            sizeY = 32
            break
        case 11:
            sizeX = 32
            sizeY = 64
            break
        }
        sprite_index := u32((sprite & 0x3FF00000000) >> 32) * 32
        palette_index := u32((sprite & 0xF00000000000) >> 44) * 32

        if((y_coord <= i16(line_count)) && (y_coord + i16(sizeY) > i16(line_count))) {
            y_in_tile := u16(i16(line_count) - y_coord)
            tile_size_x := u16(sizeX / 8)

            if(vflip) { //Flip Y
                y_in_tile = u16(sizeY - 1) - y_in_tile
            }

            for j :u16= 0; j < tile_size_x; j += 1 {
                data: u32
                x_tile := j

                if(hflip) { //Flip X
                    x_tile = tile_size_x - 1 - x_tile
                }

                if(one_dimensional) {
                    data = bus_get32(OVRAM + sprite_index + u32(x_tile * 32) + u32((y_in_tile % 8) * 4) + u32((y_in_tile / 8) * 32 * tile_size_x))
                } else {
                    data = bus_get32(OVRAM + sprite_index + u32(x_tile * 32) + u32((y_in_tile % 8) * 4) + u32((y_in_tile / 8) * 1024))
                }

                for i :u32= 0; i < 8; i += 1 {
                    x_in_tile := i
                    if(hflip) { //Flip X
                        x_in_tile = 7 - x_in_tile
                    }

                    palette_mask :u32= 0x0000000F << (x_in_tile * 4)
                    palette_offset := ((data & palette_mask) >> (x_in_tile * 4)) * 2
                    x_pixel_offset := x_coord + (u32(j) * 8) + i
                    if(x_pixel_offset < 0) {
                        continue
                    }
                    if(palette_offset != 0) {
                        palette_offset += u32(palette_index)
                        pixel := (u32(line_count * 240) + x_pixel_offset)
                        screen_buffer[pixel] = bus_read16(OB_PALETTE + palette_offset)
                    }
                }
            }
        }
    }
}

ppu_get_pixels :: proc() -> []u16 {
    return screen_buffer[:]
}