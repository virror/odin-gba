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
@(private="file")
screen_buffer: [WIN_WIDTH * WIN_WIDTH]u16
dispcnt: u16
dispstat: u16
vcount: u16
bg0cnt: u16
bg0hofs: u16
bg0vofs: u16
bg1cnt: u16
bg1hofs: u16
bg1vofs: u16
bg2cnt: u16
bg2hofs: u16
bg2vofs: u16
bg3cnt: u16
bg3hofs: u16
bg3vofs: u16

win0h: u16
win1h: u16
win0v: u16
win1v: u16
winin: u16
winout: u16
mosaic: u16
bldcnt: u16
bldalpha: u16
bldy: u16

ppu_step :: proc(cycles: u32) -> bool {
    ready_draw: bool
    cycle_count += cycles

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
            mode := dispcnt & 0x7
            switch(mode) {
            case 0:
                ppu_draw_mode_0()
                break
            case 1:
                ppu_draw_mode_1()
                break
            case 2:
                ppu_draw_mode_2()
                break
            case 3:
                ppu_draw_mode_3()
                break
            case 4:
                ppu_draw_mode_4()
                break
            case 5:
                ppu_draw_mode_5()
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
                bg := bus_get16(BG_PALETTE)
                for i in 0..<len(screen_buffer) {
                    ppu_set_pixel(bg, u32(i))
                }
            } else {
                current_state = Ppu_states.VBLANK_DRAW
                ppu_set_line(line_count + 1)
            }
            dispstat = utils_bit_clear16(dispstat, 1)
        }
        break
    }
    return ready_draw
}

ppu_set_line :: proc(count: u16) {
    line_count = count
    vcnt := (dispstat >> 8)
    if(vcnt == line_count) {
        dispstat = utils_bit_set16(dispstat, 2)
        if(utils_bit_get16(dispstat, 5)) {
            bus_irq_set(2)
        }
    } else {
        dispstat = utils_bit_clear16(dispstat, 2)
    }
    vcount = line_count
}

ppu_draw_mode_0 :: proc() {
    sprites: [4][128]u64
    length: [4]u32
    obj_map_1d := utils_bit_get16(dispcnt, 6)
    obj_on := utils_bit_get16(dispcnt, 12)

    if(obj_on) {
        for k :i32= 127; k >= 0; k -= 1 {
            attr := u64(bus_get32(OAM + u32(k) * 8))
            attr += u64(bus_get32(OAM + u32(k) * 8 + 4)) << 32

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

ppu_draw_mode_1 :: proc() {
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

ppu_draw_mode_2 :: proc() {
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
        ppu_set_pixel(data, pixel)
    }
}

ppu_draw_mode_4 :: proc() {
    start := VRAM
    if(utils_bit_get16(dispcnt, 4)) {
        start += 0xA000
    }
    for i :u32= 0; i < 240; i += 1 {
        pixel := (u32(line_count) * 240) + i
        palette := bus_get8(start + pixel)
        if(palette != 0) {
            data := bus_get16(BG_PALETTE + (u32(palette) * 2))
            ppu_set_pixel(data, pixel)
        }
    }
}

ppu_draw_mode_5 :: proc() {
    //TODO: Implement screen shift?
    start := VRAM
    if(utils_bit_get16(dispcnt, 4)) {
        start += 0xA000
    }
    for i :u32= 0; i < 240; i += 1 {
        pixel := (u32(line_count) * 240) + i
        if(line_count >= 128) {
            continue
        } else if(i >= 160) {
            continue
        } else {
            data := bus_get16(start + (pixel * 2))
            ppu_set_pixel(data, pixel)
        }
    }
}

ppu_is_inside_win :: proc(x: u16, y: u16, winh: u16, winv: u16) -> bool {
    top := winv >> 8
    bot := winv & 0xFF
    left := winh >> 8
    right := winh & 0xFF
    if((x > left) && (x < right) && (y > top) && (y < bot)) {
        return true
    }
    return false
}

ppu_draw_tiles :: proc(bg_index: u8) {
    bgcnt: u16
    bghofs: u16
    bgvofs: u16
    win0_on := utils_bit_get16(dispcnt, 13)
    win1_on := utils_bit_get16(dispcnt, 14)
    switch(bg_index) {
    case 0:
        bgcnt = bg0cnt
        bghofs = bg0hofs
        bgvofs = bg0vofs
        break
    case 1:
        bgcnt = bg1cnt
        bghofs = bg1hofs
        bgvofs = bg1vofs
        break
    case 2:
        bgcnt = bg2cnt
        bghofs = bg2hofs
        bgvofs = bg2vofs
        break
    case 3:
        bgcnt = bg3cnt
        bghofs = bg3hofs
        bgvofs = bg3vofs
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

        if(utils_bit_get16(winout, bg_index)) {
            if(ppu_is_inside_win(x_coord, y_coord, win0h, win0v) || ppu_is_inside_win(x_coord, y_coord, win1h, win1v)) {
                continue
            }
        }
        if(win1_on && utils_bit_get16(winin, bg_index + 8)) {
            if (!ppu_is_inside_win(x_coord, y_coord, win1h, win1v) || ppu_is_inside_win(x_coord, y_coord, win0h, win0v)) {
                continue
            }
        }
        if(win0_on && utils_bit_get16(winin, bg_index)) {
            if(!ppu_is_inside_win(x_coord, y_coord, win0h, win0v)) {
                continue
            }
        }

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
        pixel := u32((line_count * 240) + i)
        if(color != 0x8000) {
            ppu_set_pixel(color, pixel)
        }
    }
}

ppu_draw_tiles_aff :: proc(bg_index: u8) {
    //Not implemented
    fmt.println("af tiles!")
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

ppu_get_sprite_size :: proc(size: u64) -> (u8, u8) {
    switch(size) {
    case 0:
        return 8, 8
    case 1:
        return 16, 16
    case 2:
        return 32, 32
    case 3:
        return 64, 64
    case 4:
        return 16, 8
    case 5:
        return 32, 8
    case 6:
        return 32, 16
    case 7:
        return 64, 32
    case 8:
        return 8, 16
    case 9:
        return 8, 32
    case 10:
        return 16, 32
    case 11:
        return 32, 64
    }
    return 8, 8
}

ppu_draw_sprites :: proc(sprites: [128]u64, length: u32, one_dimensional: bool) {
    //win0_on := utils_bit_get16(dispcnt, 13)
    //win1_on := utils_bit_get16(dispcnt, 14)

    for k :u32= 0; k < length; k += 1 {
        sprite := sprites[k]
        y_coord := i16(sprite & 0xFF)
        if(y_coord > 159) {
            y_coord = i16(utils_sign_extend32(u32(y_coord), 8))
        }
        rot_scale := utils_bit_get64(sprite, 8)
        double_size := utils_bit_get64(sprite, 9)
        //mosaic := utils_bit_get64(sprite, 12)
        palette_256 := utils_bit_get64(sprite, 13)
        if(!rot_scale && double_size) {
            fmt.println("Disabled sprite!")
        }
        if(rot_scale) {
            fmt.println("Aff sprite!")
        }
        if(palette_256) {
            fmt.println("256 sprite!")
        }
        x_coord := u32(sprite & 0x1FF0000) >> 16
        x_coord = utils_sign_extend32(x_coord, 9)
        hflip := utils_bit_get64(sprite, 28)
        vflip := utils_bit_get64(sprite, 29)
        size := (sprite & 0xC0000000) >> 30
        size |= (sprite & 0xC000) >> 12
        sizeX, sizeY := ppu_get_sprite_size(size)
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
                    data = bus_get32(OVRAM + (sprite_index) + u32(x_tile) * 32 + u32((y_in_tile % 8) * 4) + (u32(y_in_tile / 8) * 32 * u32(tile_size_x)))
                } else {
                    data = bus_get32(OVRAM + (sprite_index) + u32(x_tile) * 32 + u32((y_in_tile % 8) * 4) + (u32(y_in_tile / 8) * 1024))
                }
                for i :u32= 0; i < 8; i += 1 {
                    x_in_tile := i
                    if(hflip) { //Flip X
                        x_in_tile = 7 - x_in_tile
                    }
                    x_pixel_offset := u16(x_coord) + (j * 8) + u16(i)

                    /*if(utils_bit_get16(winout, 4)) {
                        if(ppu_is_inside_win(x_pixel_offset, line_count, win0h, win0v) || ppu_is_inside_win(x_pixel_offset, line_count, win1h, win1v)) {
                            continue
                        }
                    }
                    if(win1_on && utils_bit_get16(winin, 12)) {
                        if (!ppu_is_inside_win(x_pixel_offset, line_count, win1h, win1v) || ppu_is_inside_win(x_pixel_offset, line_count, win0h, win0v)) {
                            continue
                        }
                    }
                    if(win0_on && utils_bit_get16(winin, 4)) {
                        if(!ppu_is_inside_win(x_pixel_offset, line_count, win0h, win0v)) {
                            continue
                        }
                    }*/

                    palette_mask :u32= 0x0000000F << (x_in_tile * 4)
                    palette_offset := ((data & palette_mask) >> (x_in_tile * 4)) * 2
                    if(x_pixel_offset < 0) {
                        continue
                    }
                    if(palette_offset != 0) {
                        palette_offset += u32(palette_index)
                        pixel := (u32(line_count * 240) + u32(x_pixel_offset))
                        if(pixel >= 57600) {
                            continue
                        }
                        color := bus_read16(OB_PALETTE + palette_offset)
                        ppu_set_pixel(color, pixel)
                    }
                }
            }
        }
    }
}

ppu_set_pixel :: proc(color: u16, pixel: u32) {
    r := (color & 0x1F) << 10
    g := color & 0x3E0
    b := (color & 0x7C00) >> 10
    new_color := (r | g | b) | 0x8000
    screen_buffer[pixel] = new_color
}

ppu_get_pixels :: proc() -> []u16 {
    return screen_buffer[:]
}

ppu_write :: proc(addr: u32, value: u8) {
    switch(addr) {
    case IO_DISPCNT:
        dispcnt = u16(value)
    case IO_DISPCNT + 1:
        dispcnt |= u16(value) << 8
    case IO_DISPSTAT:
        dispstat = u16(value)
    case IO_DISPSTAT + 1:
        dispstat |= u16(value) << 8
    case IO_BG0CNT:
        bg0cnt = u16(value)
    case IO_BG0CNT + 1:
        bg0cnt |= u16(value) << 8
    case IO_BG1CNT:
        bg1cnt = u16(value)
    case IO_BG1CNT + 1:
        bg1cnt |= u16(value) << 8
    case IO_BG2CNT:
        bg2cnt = u16(value)
    case IO_BG2CNT + 1:
        bg2cnt |= u16(value) << 8
    case IO_BG3CNT:
        bg3cnt = u16(value)
    case IO_BG3CNT + 1:
        bg3cnt |= u16(value) << 8
    case IO_BG0HOFS:
        bg0hofs = u16(value)
    case IO_BG0HOFS + 1:
        bg0hofs |= u16(value) << 8
    case IO_BG0VOFS:
        bg0vofs = u16(value)
    case IO_BG0VOFS + 1:
        bg0vofs |= u16(value) << 8
    case IO_BG1HOFS:
        bg1hofs = u16(value)
    case IO_BG1HOFS + 1:
        bg1hofs |= u16(value) << 8
    case IO_BG1VOFS:
        bg1vofs = u16(value)
    case IO_BG1VOFS + 1:
        bg1vofs |= u16(value) << 8
    case IO_BG2HOFS:
        bg2hofs = u16(value)
    case IO_BG2HOFS + 1:
        bg2hofs |= u16(value) << 8
    case IO_BG2VOFS:
        bg2vofs = u16(value)
    case IO_BG2VOFS + 1:
        bg2vofs |= u16(value) << 8
    case IO_BG3HOFS:
        bg3hofs = u16(value)
    case IO_BG3HOFS + 1:
        bg3hofs |= u16(value) << 8
    case IO_BG3VOFS:
        bg3vofs = u16(value)
    case IO_BG3VOFS + 1:
        bg3vofs |= u16(value) << 8
    case IO_WIN0H:
        win0h = u16(value)
    case IO_WIN0H + 1:
        win0h |= u16(value) << 8
    case IO_WIN1H:
        win1h = u16(value)
    case IO_WIN1H + 1:
        win1h |= u16(value) << 8
    case IO_WIN0V:
        win0v = u16(value)
    case IO_WIN0V + 1:
        win0v |= u16(value) << 8
    case IO_WIN1V:
        win1v = u16(value)
    case IO_WIN1V + 1:
        win1v |= u16(value) << 8
    case IO_WININ:
        winin = u16(value)
    case IO_WININ + 1:
        winin |= u16(value) << 8
    case IO_WINOUT:
        winout = u16(value)
    case IO_WINOUT + 1:
        winout |= u16(value) << 8
    case IO_MOSAIC:
        mosaic = u16(value)
    case IO_MOSAIC + 1:
        mosaic |= u16(value) << 8
    case IO_BLDCNT:
        bldcnt = u16(value)
    case IO_BLDCNT + 1:
        bldcnt |= u16(value) << 8
    case IO_BLDALPHA:
        bldalpha = u16(value)
    case IO_BLDALPHA + 1:
        bldalpha |= u16(value) << 8
    case IO_BLDY:
        bldy = u16(value)
    case IO_BLDY + 1:
        bldy |= u16(value) << 8
    }
}

ppu_read :: proc(addr: u32) -> u8 {
    switch(addr) {
    case IO_DISPCNT:
        return u8(dispcnt)
    case IO_DISPCNT + 1:
        return u8(dispcnt >> 8)
    case IO_DISPSTAT:
         return u8(dispstat)
    case IO_DISPSTAT + 1:
        return u8(dispstat >> 8)
    case IO_VCOUNT:
         return u8(vcount)
    case IO_VCOUNT + 1:
        return u8(vcount >> 8)
    case IO_BG0CNT:
         return u8(bg0cnt)
    case IO_BG0CNT + 1:
        return u8(bg0cnt >> 8) & 0xDF
    case IO_BG1CNT:
         return u8(bg1cnt)
    case IO_BG1CNT + 1:
        return u8(bg1cnt >> 8) & 0xDF
    case IO_BG2CNT:
         return u8(bg2cnt)
    case IO_BG2CNT + 1:
        return u8(bg2cnt >> 8)
    case IO_BG3CNT:
         return u8(bg3cnt)
    case IO_BG3CNT + 1:
        return u8(bg3cnt >> 8)
    case IO_WININ:
         return u8(winin) & 0x3F
    case IO_WININ + 1:
        return u8(winin >> 8) & 0x3F
    case IO_WINOUT:
         return u8(winout) & 0x3F
    case IO_WINOUT + 1:
        return u8(winout >> 8) & 0x3F
    case IO_BLDCNT:
         return u8(bldcnt)
    case IO_BLDCNT + 1:
        return u8(bldcnt >> 8) & 0x3F
    case IO_BLDALPHA:
         return u8(bldalpha) & 0x1F
    case IO_BLDALPHA + 1:
        return u8(bldalpha >> 8) & 0x1F
    }
    if((addr & 1) > 0) {
        return 0xDE
    } else {
        return 0xAD
    }
}