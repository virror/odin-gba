package main

import "core:fmt"

shift :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    op := opcode & 0x1800
    imm := (opcode & 0x07C0) >> 6
    Rs := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    switch(op) {
    case 0x0000:
        op_name = fmt.caprintf("LSL %s, %s, %d", dbg_R2reg(Rd), dbg_R2reg(Rs), imm)
        break
    case 0x0800:
        op_name = fmt.caprintf("LSR %s, %s, %d", dbg_R2reg(Rd), dbg_R2reg(Rs), imm)
        break
    case 0x1000:
        op_name = fmt.caprintf("ASR %s, %s, %d", dbg_R2reg(Rd), dbg_R2reg(Rs), imm)
        break
    }
    return op_name
}

add_sub :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    Op := (opcode & 0x0600) >> 9
    Rn := u32((opcode & 0x01C0) >> 6)
    Rs := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    switch(Op) {
    case 0:
        op_name = fmt.caprintf("ADD %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs), dbg_R2reg(Rn))
        break
    case 1:
        op_name = fmt.caprintf("SUB %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs), dbg_R2reg(Rn))
        break
    case 2:
        op_name = fmt.caprintf("ADD %s, %s, %d", dbg_R2reg(Rd), dbg_R2reg(Rs), Rn)
        break
    case 3:
        op_name = fmt.caprintf("SUB %s, %s, %d", dbg_R2reg(Rd), dbg_R2reg(Rs), Rn)
        break
    }
    return op_name
}

mcas_imm :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    op := opcode & 0x1800
    Rd := u32((opcode & 0x0700) >> 8)
    nn := opcode & 0x00FF

    switch(op) {
    case 0x0000:
        op_name = fmt.caprintf("MOV %s, %d", dbg_R2reg(Rd), nn)
        break
    case 0x0800:
        op_name = fmt.caprintf("CMP %s, %d", dbg_R2reg(Rd), nn)
        break
    case 0x1000:
        op_name = fmt.caprintf("ADD %s, %d", dbg_R2reg(Rd), nn)
        break
    case 0x1800:
        op_name = fmt.caprintf("SUB %s, %d", dbg_R2reg(Rd), nn)
        break
    }
    return op_name
}

ld_pc :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    L := utils_bit_get16(opcode, 11)
    Rd := u32((opcode & 0x0700) >> 8)
    imm := (opcode & 0x00FF) << 2

    if(L) {
        op_name = fmt.caprintf("LDR %s, [PC, %d]", dbg_R2reg(Rd), imm)
    } else {
        op_name = fmt.caprintf("STR %s, [PC, %d]", dbg_R2reg(Rd), imm)
    }
    return op_name
}

hi_reg :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    Op := (opcode & 0x03C0) >> 6
    Rs := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    switch(Op) {
    case 1:
        op_name = fmt.caprintf("ADD %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs + 8))
        break
    case 2:
        op_name = fmt.caprintf("ADD %s, %s", dbg_R2reg(Rd + 8), dbg_R2reg(Rs))
        break
    case 3:
        op_name = fmt.caprintf("ADD %s, %s", dbg_R2reg(Rd + 8), dbg_R2reg(Rs + 8))
        break
    case 5:
        op_name = fmt.caprintf("CMP %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs + 8))
        break
    case 6:
        op_name = fmt.caprintf("CMP %s, %s", dbg_R2reg(Rd + 8), dbg_R2reg(Rs))
        break
    case 7:
        op_name = fmt.caprintf("CMP %s, %s", dbg_R2reg(Rd + 8), dbg_R2reg(Rs + 8))
        break
    case 9:
        op_name = fmt.caprintf("MOV %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs + 8))
        break
    case 10:
        op_name = fmt.caprintf("MOV %s, %s", dbg_R2reg(Rd + 8), dbg_R2reg(Rs))
        break
    case 11:
        op_name = fmt.caprintf("MOV %s, %s", dbg_R2reg(Rd + 8), dbg_R2reg(Rs + 8))
        break
    case 12:
        op_name = fmt.caprintf("BX %s", dbg_R2reg(Rs))
        break
    case 13:
        op_name = fmt.caprintf("BX %s", dbg_R2reg(Rs + 8))
        break
    case:
        op_name = "Invalid!"
        break
    }
    return op_name
}

alu :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    Op := (opcode & 0x03C0) >> 6
    Rs := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    switch(Op) {
    case 0:
        op_name = fmt.caprintf("AND %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 1:
        op_name = fmt.caprintf("EOR %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 2:
        op_name = fmt.caprintf("LSL %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 3:
        op_name = fmt.caprintf("LSR %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 4:
        op_name = fmt.caprintf("ASR %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 5:
        op_name = fmt.caprintf("ADC %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 6:
        op_name = fmt.caprintf("SBC %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 7:
        op_name = fmt.caprintf("ROR %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 8:
        op_name = fmt.caprintf("TST %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 9:
        op_name = fmt.caprintf("NEG %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 10:
        op_name = fmt.caprintf("CMP %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 11:
        op_name = fmt.caprintf("CMN %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 12:
        op_name = fmt.caprintf("ORR %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 13:
        op_name = fmt.caprintf("MUL %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 14:
        op_name = fmt.caprintf("BIC %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    case 15:
        op_name = fmt.caprintf("MVN %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rs))
        break
    }
    return op_name
}

ls_ext :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    Op := (opcode & 0x0C00)
    Ro := u32((opcode & 0x01C0) >> 6)
    Rb := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    switch(Op) {
    case 0x000:
        op_name = fmt.caprintf("STRH %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    case 0x400:
        op_name = fmt.caprintf("LDSB %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    case 0x800:
        op_name = fmt.caprintf("LDRH %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    case 0xC00:
        op_name = fmt.caprintf("LDSH %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    }
    return op_name
}

ls_reg :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    Op := opcode & 0x0C00
    Ro := u32((opcode & 0x01C0) >> 6)
    Rb := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    switch(Op) {
    case 0x0000:
        op_name = fmt.caprintf("STR %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    case 0x0400:
        op_name = fmt.caprintf("STRB %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    case 0x0800:
        op_name = fmt.caprintf("LDR %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    case 0x0C00:
        op_name = fmt.caprintf("LDRB %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rb), dbg_R2reg(Ro))
        break
    }
    return op_name
}

ls_imm :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    Op := opcode & 0x1800
    imm := (opcode & 0x07C0) >> 6
    Rb := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    switch(Op) {
    case 0x0000:
        op_name = fmt.caprintf("STR %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rb), (imm << 2))
        break
    case 0x0800:
        op_name = fmt.caprintf("LDR %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rb), (imm << 2))
        break
    case 0x1000:
        op_name = fmt.caprintf("STRB %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rb), imm)
        break
    case 0x1800:
        op_name = fmt.caprintf("LDRB %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rb), imm)
        break
    }
    return op_name
}

ls_hw :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    L := utils_bit_get16(opcode, 11)
    imm := ((opcode & 0x07C0) >> 6) << 1
    Rb := u32((opcode & 0x0038) >> 3)
    Rd := u32(opcode & 0x0007)

    if(L) {
        op_name = fmt.caprintf("LDRH %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rb), imm)
    } else {
        op_name = fmt.caprintf("STRH %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rb), imm)
    }
    return op_name
}

ls_sp :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    L := utils_bit_get16(opcode, 11)
    Rd := u32((opcode & 0x0700) >> 8)
    imm := u32((opcode & 0x00FF) << 2)

    if(L) {
        op_name = fmt.caprintf("LDR %s, [SP, %d]", dbg_R2reg(Rd), imm)
    } else {
        op_name = fmt.caprintf("STR %s, [SP, %d]", dbg_R2reg(Rd), imm)
    }
    return op_name
}

ld :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    SP := utils_bit_get16(opcode, 11)
    Rd := u32((opcode & 0x0700) >> 8)
    imm := (opcode & 0x00FF) << 2

    if(SP) {
        op_name = fmt.caprintf("SUB %s, SP, %d", dbg_R2reg(Rd), imm)
        
    } else {
        op_name = fmt.caprintf("ADD %s, PC, %d", dbg_R2reg(Rd), imm)
    }
    return op_name
}

push_pop :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    L := utils_bit_get16(opcode, 11)
    R := utils_bit_get16(opcode, 8)
    imm := opcode & 0x00FF

    if(L) {
        if(R) {
            op_name = fmt.caprintf("POP {%d, PC}", imm)
        } else {
            op_name = fmt.caprintf("POP {%d}", imm)
        }
    } else {
        if(R) {
            op_name = fmt.caprintf("PUSH {%d, LR}", imm)
        } else {
            op_name = fmt.caprintf("PUSH {%d}", imm)
        }
    }
    return op_name
}

sp_ofs :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    S := utils_bit_get16(opcode, 7)
    offset := i32((opcode & 0x007F) << 2)

    if(S) {
        offset *= -1
    }
    op_name = fmt.caprintf("ADD SP, %d", offset)
    return op_name
}

ls_mp :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    L := utils_bit_get16(opcode, 11)
    Rb := u32((opcode & 0x0700) >> 8)
    imm := opcode & 0x00FF

    if(L) {
        op_name = fmt.caprintf("LDMIA %s!, {%d}", dbg_R2reg(Rb), imm)
    } else {
        op_name = fmt.caprintf("STMIA %s!, {%d}", dbg_R2reg(Rb), imm)
    }
    return op_name
}

b_cond :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    Op := (opcode & 0x0F00) >> 8
    offset := u32((opcode & 0x00FF) << 1)
    offset = utils_sign_extend32(offset, 9)

    switch(Op) {
    case 0:
        op_name = fmt.caprintf("BEQ %d", i32(offset))
        break
    case 1:
        op_name = fmt.caprintf("BNE %d", i32(offset))
        break
    case 2:
        op_name = fmt.caprintf("BCS %d", i32(offset))
        break
    case 3:
        op_name = fmt.caprintf("BCC %d", i32(offset))
        break
    case 4:
        op_name = fmt.caprintf("BMI %d", i32(offset))
        break
    case 5:
        op_name = fmt.caprintf("BPL %d", i32(offset))
        break
    case 6:
        op_name = fmt.caprintf("BVS %d", i32(offset))
        break
    case 7:
        op_name = fmt.caprintf("BVC %d", i32(offset))
        break
    case 8:
        op_name = fmt.caprintf("BHI %d", i32(offset))
        break
    case 9:
        op_name = fmt.caprintf("BLS %d", i32(offset))
        break
    case 10:
        op_name = fmt.caprintf("BGE %d", i32(offset))
        break
    case 11:
        op_name = fmt.caprintf("BLT %d", i32(offset))
        break
    case 12:
        op_name = fmt.caprintf("BGT %d", i32(offset))
        break
    case 13:
        op_name = fmt.caprintf("BLE %d", i32(offset))
        break
    case 15:
        op_name = "SWI"
        break
    }
    return op_name
}

b_uncond :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    offset := u32((opcode & 0x7FF) << 1)
    offset = utils_sign_extend32(offset, 12)

    op_name = fmt.caprintf("B %d", i32(offset))
    return op_name
}

bl :: proc(opcode: u16) -> cstring {
    op_name :cstring= "Undefined"
    imm := u32(opcode & 0x7FF) << 12
    opcode2 := bus_read16(cpu_reg_get(Regs.PC) + 2)
    imm2 := u32(opcode2 & 0x7FF) << 1
    pc := i32(cpu_reg_get(Regs.PC))
    offset := utils_sign_extend32(imm + imm2, 23)
    op_name = fmt.caprintf("BL %d", i32(offset) + pc)
    return op_name
}
