package main

import "core:fmt"

dbg_mul_mla :: proc(opcode: u32) -> cstring {
    op_name :cstring= "Undefined"
    A := utils_bit_get32(opcode, 21)
    Rd := (opcode & 0xF0000) >> 16
    Rn := (opcode & 0xF000) >> 12
    Rs := (opcode & 0xF00) >> 8
    Rm := (opcode & 0xF)
    if(A) {
        op_name = fmt.caprintf("MLA %s, %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rm), dbg_R2reg(Rs), dbg_R2reg(Rn))
    } else {
        op_name = fmt.caprintf("MUL %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rm), dbg_R2reg(Rs))
    }
    return op_name
}

dbg_mull_mlal :: proc(opcode: u32) -> cstring {
    op_name :cstring= "Undefined"
    Op := opcode & 0x600000
    RdHi := (opcode & 0xF0000) >> 16
    RdLo := (opcode & 0xF000) >> 12
    Rs := (opcode & 0xF00) >> 8
    Rm := (opcode & 0xF)

    switch(Op) {
    case 0x000000:
        op_name = fmt.caprintf("UMULL %s, %s, %s, %S", dbg_R2reg(RdLo), dbg_R2reg(RdHi), dbg_R2reg(Rm), dbg_R2reg(Rs))
        break
    case 0x200000:
        op_name = fmt.caprintf("UMLAL %s, %s, %s, %S", dbg_R2reg(RdLo), dbg_R2reg(RdHi), dbg_R2reg(Rm), dbg_R2reg(Rs))
        break
    case 0x400000:
        op_name = fmt.caprintf("SMULL %s, %s, %s, %S", dbg_R2reg(RdLo), dbg_R2reg(RdHi), dbg_R2reg(Rm), dbg_R2reg(Rs))
        break
    case 0x600000:
        op_name = fmt.caprintf("SMLAL %s, %s, %s, %S", dbg_R2reg(RdLo), dbg_R2reg(RdHi), dbg_R2reg(Rm), dbg_R2reg(Rs))
        break
    }
    return op_name
}

dbg_hw_transfer :: proc(opcode: u32) -> cstring {
    op_name :cstring= "Undefined"
    I := utils_bit_get32(opcode, 22)
    L := utils_bit_get32(opcode, 20)
    Rn := (opcode & 0xF0000) >> 16
    Rd := (opcode & 0xF000) >> 12
    Oh := (opcode & 0xF00) >> 8
    Rm := (opcode & 0xF)

    if(L) {
        if(I) {
            op_name = fmt.caprintf("LDRH %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rn), (Oh << 4) + Rm)
        } else {
            op_name = fmt.caprintf("LDRH %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rn), dbg_R2reg(Rm))
        }
    } else {
        if(I) {
            op_name = fmt.caprintf("STRH %s, [%s, %d]", dbg_R2reg(Rd), dbg_R2reg(Rn), (Oh << 4) + Rm)
        } else {
            op_name = fmt.caprintf("STRH %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rn), dbg_R2reg(Rm))
        }
    }
    return op_name
}

dbg_swap :: proc(opcode: u32) -> cstring {
    op_name :cstring= "Undefined"
    B := utils_bit_get32(opcode, 22)
    Rn := (opcode & 0xF0000) >> 16
    Rd := (opcode & 0xF000) >> 12
    Rm := opcode & 0xF

    if(B) {
        op_name = fmt.caprintf("SWPB %s, %s, [%s]", dbg_R2reg(Rd), dbg_R2reg(Rm), dbg_R2reg(Rn))
    } else {
        op_name = fmt.caprintf("SWP %s, %s, [%s]", dbg_R2reg(Rd), dbg_R2reg(Rm), dbg_R2reg(Rn))
    }
    return op_name
}

dbg_bx :: proc(opcode: u32) -> cstring {
    Rn := opcode & 0xF
    return fmt.caprintf("BX %s", dbg_R2reg(Rn))
}

dbg_alu :: proc(opcode: u32, I: bool) -> cstring {
    op_name :cstring= "Undefined"
    op_name2: cstring
    op := opcode & 0x1E00000
    S := utils_bit_get32(opcode, 20)
    Rn := (opcode & 0xF0000) >> 16
    Rd := (opcode & 0xF000) >> 12
    Op2: cstring

    if(I) {
        Op2 = fmt.caprintf("%d", opcode & 0xFF)
    } else {
        Op2 = dbg_R2reg(opcode & 0xF)
    }

    switch(op) {
    case 0x0000000:
        op_name = fmt.caprintf("AND %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x0200000:
        op_name = fmt.caprintf("EOR %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x0400000:
        op_name = fmt.caprintf("SUB %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x0600000:
        op_name = fmt.caprintf("RSB %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x0800000:
        op_name = fmt.caprintf("ADD %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x0A00000:
        op_name = fmt.caprintf("ADC %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x0C00000:
        op_name = fmt.caprintf("SBC %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x0E00000:
        op_name = fmt.caprintf("RSC %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x1000000:
        if(S) {
            op_name = fmt.caprintf("TST %s, %s", dbg_R2reg(Rn), Op2)
        } else {
            op_name = fmt.caprintf("MRS %s, CPSR", dbg_R2reg(Rd))
        }
        break
    case 0x1200000:
        if(S) {
            op_name = fmt.caprintf("TEQ %s, %s", dbg_R2reg(Rn), Op2)
        } else {
            Rm := opcode & 0xF
            op_name = fmt.caprintf("MSR CPSR, %s", dbg_R2reg(Rm))
        }
        break
    case 0x1400000:
        if(S) {
            op_name = fmt.caprintf("CMP %s, %s", dbg_R2reg(Rn), Op2)
        } else {
            op_name = fmt.caprintf("MRS, %s, SPSR", dbg_R2reg(Rd))
        }
        break
    case 0x1600000:
        if(S) {
            op_name = fmt.caprintf("CMN %s, %s", dbg_R2reg(Rn), Op2)
        } else {
            Rm := opcode & 0xF
            op_name = fmt.caprintf("MSR SPSR, %s", dbg_R2reg(Rm))
        }
        break
    case 0x1800000:
        op_name = fmt.caprintf("ORR %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x1A00000:
        op_name = fmt.caprintf("MOV %s, %s", dbg_R2reg(Rd), Op2)
        break
    case 0x1C00000:
        op_name = fmt.caprintf("BIC %s, %s, %s", dbg_R2reg(Rd), dbg_R2reg(Rn), Op2)
        break
    case 0x1E00000:
        op_name = fmt.caprintf("MVN %s, %s", dbg_R2reg(Rd), Op2)
        break
    }
    /*if(S) {
        op_name.insert(op_name.find(" "), "S")
    }*/

    if(I) {
        op_name2 = fmt.caprintf(", ROR %d", opcode & 0xFF)
    } else {
        shift_type := opcode & 0x60
        shift_reg := utils_bit_get32(opcode, 4)
        shift: cstring

        if(shift_reg) {
            Rs := (opcode & 0xF00) >> 8
            shift = dbg_R2reg(Rs)
        } else {
            shift = fmt.caprintf("%d", (opcode & 0xF80) >> 7)
        }
        switch(shift_type) {
        case 0x00: //LSL
            op_name2 = fmt.caprintf(", LSL %s", shift)
            break
        case 0x20: //LSR
            op_name2 = fmt.caprintf(", LSR %s", shift)
            break
        case 0x40: //ASR
            op_name2 = fmt.caprintf(", ASR %s", shift)
            break
        case 0x60: //ROR
            op_name2 = fmt.caprintf(", ROR %s", shift)
            break
        }
    }
    return fmt.caprintf("%s%s,", op_name, op_name2)
}

dbg_ldr :: proc(opcode: u32, I: bool) -> cstring {
    op_name :cstring= "Undefined"
    load := utils_bit_get32(opcode, 20)
    is_byte := utils_bit_get32(opcode, 22)
    Rn := (opcode & 0xF0000) >> 16
    Rd := (opcode & 0xF000) >> 12
    offset: cstring

    if I {
        offset = dbg_R2reg(opcode & 0xF)
    } else {
        offset = fmt.caprintf("%d", (opcode & 0xFFF))
    }

    if load {
        if is_byte {
            op_name = fmt.caprintf("LDRB %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rn), offset)
        } else {
            op_name = fmt.caprintf("LDR %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rn), offset)
        }
    } else {
        if is_byte {
            op_name = fmt.caprintf("STRB %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rn), offset)
        } else {
            op_name = fmt.caprintf("STR %s, [%s, %s]", dbg_R2reg(Rd), dbg_R2reg(Rn), offset)
        }
    }
    return op_name
}

dbg_ldm_stm :: proc(opcode: u32) -> cstring {
    op_name :cstring= "Undefined"

    op := u32(utils_bit_get32(opcode, 20)) << 2
    op += u32(utils_bit_get32(opcode, 24)) << 1
    op += u32(utils_bit_get32(opcode, 23))
    S := utils_bit_get32(opcode, 22)

    Rn := (opcode & 0xF0000) >> 16
    regs := opcode & 0xFFFF
    if(Rn == 13) {
        switch(op) {
        case 0:
            op_name = "STMED "
            break
        case 1:
            op_name = "STMEA "
            break
        case 2:
            op_name = "STMFD "
            break
        case 3:
            op_name = "STMFA "
            break
        case 4:
            op_name = "LDMFA "
            break
        case 5:
            op_name = "LDMFD "
            break
        case 6:
            op_name = "LDMEA "
            break
        case 7:
            op_name = "LDMED "
            break
        }
    } else {
        switch(op) {
        case 0:
            op_name = "STMDA "
            break
        case 1:
            op_name = "STMIA "
            break
        case 2:
            op_name = "STMDB "
            break
        case 3:
            op_name = "STMIB "
            break
        case 4:
            op_name = "LDMDA "
            break
        case 5:
            op_name = "LDMIA "
            break
        case 6:
            op_name = "LDMDB "
            break
        case 7:
            op_name = "LDMIB "
            break
            }
    }
    if(S) {
        op_name = fmt.caprintf("%s %s, %d^", op_name, dbg_R2reg(Rn), regs)
    } else {
        op_name = fmt.caprintf("%s %s, %d", op_name, dbg_R2reg(Rn), regs)
    }
    return op_name
}

dbg_branch :: proc(opcode: u32) -> cstring {
    op_name := "Undefined"
    offset := (opcode & 0xFFFFFF) << 2
    offset = utils_sign_extend32(offset, 26)

    negative := (offset & (1 << 23)) != 0
    if (negative) {
        offset = offset | ~((1 << 18) - u32(1))
    }
    L := utils_bit_get32(opcode, 24)
    if(L) {
        op_name = "BL"
    } else {
        op_name = "B"
    }
    return fmt.caprintf("%s %d", op_name, i32(offset))
}

dbg_R2reg :: proc(R: u32) -> cstring {
    reg: cstring
    if(R <= 12) {
        reg = fmt.caprintf("R%d", R)
    } else if(R == 13) {
        reg = "SP"
    } else if(R == 14) {
        reg = "LR"
    } else if(R == 15) {
        reg = "PC"
    }
    return reg
}