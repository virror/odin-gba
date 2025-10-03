package main

import "core:fmt"
import "core:os"
import "core:encoding/json"

TEST_ENABLE :: false
TEST_ALL :: false
TEST_FILE :: "tests/json/arm_mrs.json"
TEST_BREAK_ERROR :: true

Transaction :: struct {
    kind: u32,
    size: u32,
    addr: u32,
    data: u32,
    cycle: u32,
    access: u32,
}

@(private="file")
Registers :: struct {
    R: [16]u32,
    R_fiq: [7]u32,
    R_svc: [2]u32,
    R_abt: [2]u32,
    R_irq: [2]u32,
    R_und: [2]u32,
    CPSR: u32,
    SPSR: [5]u32,
    pipeline: [2]u32,
    access: u32,
}

@(private="file")
Json_data :: struct {
    initial: Registers,
    final: Registers,
    transactions: []Transaction,
    opcode: u32,
    base_addr: u32,
}

@(private="file")
test_fail: bool
@(private="file")
fail_cnt: int
@(private="file")
ram_mem: [0x1000000]u8
@(private="file")
test_count: int
@(private="file")
transaction_cnt: u32
@(private="file")
transactions: []Transaction
@(private="file")
error_string: string

test_all :: proc() {
    when TEST_ALL {
        fd: os.Handle
        err: os.Errno
        info: []os.File_Info
        fd, err = os.open("tests/json")
        info, err = os.read_dir(fd, -1)
        length := len(info)
        for i := 0; i < length; i += 1 {
            test_fail = false
            fail_cnt = 0
            fmt.println(info[i].fullpath)
            test_file(info[i].fullpath)
            if test_fail == true {
                break
            }
        }
    } else {
        fmt.println(TEST_FILE)
        test_file(TEST_FILE)
    }
}

test_file :: proc(filename: string) {
    //Setup
    data, err := os.read_entire_file_from_filename(filename)
    assert(err == true, "Could not load test file")
    json_data: [dynamic]Json_data
    error := json.unmarshal(data, &json_data)
    if error != nil {
        fmt.println(error)
        return
    }
    delete(data)
    test_length := len(json_data)
    for i:= 0; i < test_length; i += 1 {
        test_count = i
        if !test_fail {
            test_run(json_data[i])
        }
    }
    fmt.printf("Failed: %d\n", fail_cnt)
}
/*
M_USER = 0,
M_FIQ = 1,
M_IRQ = 2,
M_SUPERVISOR = 3,
M_ABORT = 7,
M_UNDEFINED = 11,
M_SYSTEM = 15,
*/
@(private="file")
test_run :: proc(json_data: Json_data) {
    error_string = ""
    for i in 0..=14 {
        regs[i][0] = json_data.initial.R[i]
    }
    PC = json_data.initial.R[15]

    for i in 8..=14 {
        regs[i][1] = json_data.initial.R_fiq[i - 8]
    }

    regs[13][7] = json_data.initial.R_abt[0]
    regs[14][7] = json_data.initial.R_abt[1]

    regs[13][2] = json_data.initial.R_irq[0]
    regs[14][2] = json_data.initial.R_irq[1]

    regs[13][3] = json_data.initial.R_svc[0]
    regs[14][3] = json_data.initial.R_svc[1]

    regs[13][11] = json_data.initial.R_und[0]
    regs[14][11] = json_data.initial.R_und[1]

    CPSR = Flags(json_data.initial.CPSR)
    regs[17][1] = json_data.initial.SPSR[0]
    regs[17][3] = json_data.initial.SPSR[1]
    regs[17][7] = json_data.initial.SPSR[2]
    regs[17][2] = json_data.initial.SPSR[3]
    regs[17][11] = json_data.initial.SPSR[4]

    pipeline[0] = json_data.initial.pipeline[0]
    pipeline[1] = json_data.initial.pipeline[1]
    transaction_cnt = 0
    transactions = json_data.transactions
    opcode := pipeline[0]

    //Execute instruction
    cpu_step()

    //Compare results
    for i in 0..=7 {
        if regs[i][0] != json_data.final.R[i] {
            error_string = fmt.aprintf("Fail: R%d is %d, should be %d", i, regs[i][0], json_data.final.R[i])
        }
    }
    for i in 8..=12 {
        if regs[i][0] != json_data.final.R[i] {
            error_string = fmt.aprintf("Fail: R%d(0) is %d, should be %d", i, regs[i][0], json_data.final.R[i])
        }
        if regs[i][1] != json_data.final.R_fiq[i - 8] {
            error_string = fmt.aprintf("Fail: R%d(1) is %d, should be %d", i, regs[i][1], json_data.final.R_fiq[i - 8])
        }
    }
    if regs[13][0] != json_data.final.R[13] {
        error_string = fmt.aprintf("Fail: SP(0) is %d, should be %d", regs[13][0], json_data.final.R[13])
    }
    if regs[13][1] != json_data.final.R_fiq[5] {
        error_string = fmt.aprintf("Fail: SP(1) is %d, should be %d", regs[13][1], json_data.final.R_fiq[5])
    }
    if regs[13][2] != json_data.final.R_irq[0] {
        error_string = fmt.aprintf("Fail: SP(2) is %d, should be %d", regs[13][2], json_data.final.R_irq[0])
    }
    if regs[13][3] != json_data.final.R_svc[0] {
        error_string = fmt.aprintf("Fail: SP(3) is %d, should be %d", regs[13][3], json_data.final.R_svc[0])
    }
    if regs[13][7] != json_data.final.R_abt[0] {
        error_string = fmt.aprintf("Fail: SP(7) is %d, should be %d", regs[13][7], json_data.final.R_abt[0])
    }
    if regs[13][11] != json_data.final.R_und[0] {
        error_string = fmt.aprintf("Fail: SP(11) is %d, should be %d", regs[13][11], json_data.final.R_und[0])
    }
    if regs[14][0] != json_data.final.R[14] {
        error_string = fmt.aprintf("Fail: LR(0) is %d, should be %d", regs[14][0], json_data.final.R[14])
    }
    if regs[14][1] != json_data.final.R_fiq[6] {
        error_string = fmt.aprintf("Fail: LR(1) is %d, should be %d", regs[14][1], json_data.final.R_fiq[6])
    }
    if regs[14][2] != json_data.final.R_irq[1] {
        error_string = fmt.aprintf("Fail: LR(2) is %d, should be %d", regs[14][2], json_data.final.R_irq[1])
    }
    if regs[14][3] != json_data.final.R_svc[1] {
        error_string = fmt.aprintf("Fail: LR(3) is %d, should be %d", regs[14][3], json_data.final.R_svc[1])
    }
    if regs[14][7] != json_data.final.R_abt[1] {
        error_string = fmt.aprintf("Fail: LR(7) is %d, should be %d", regs[14][7], json_data.final.R_abt[1])
    }
    if regs[14][11] != json_data.final.R_und[1] {
        error_string = fmt.aprintf("Fail: LR(11) is %d, should be %d", regs[14][11], json_data.final.R_und[1])
    }
    if PC != json_data.final.R[15] {
        error_string = fmt.aprintf("Fail: PC is %d, should be %d", PC, json_data.final.R[15])
    }
    if(!test_get_mul(opcode)) {
        if u32(CPSR) != json_data.final.CPSR {
            error_string = fmt.aprintf("Fail: CPSR is %d\n, should be %d", CPSR, Flags(json_data.final.CPSR))
        }
    }
    if regs[17][1] != json_data.final.SPSR[0] {
        error_string = fmt.aprintf("Fail: SPSR(1) is %d\n,      should be %d", Flags(regs[17][1]), Flags(json_data.final.SPSR[0]))
    }
    if regs[17][3] != json_data.final.SPSR[1] {
        error_string = fmt.aprintf("Fail: SPSR(3) is %d\n,      should be %d", Flags(regs[17][3]), Flags(json_data.final.SPSR[1]))
    }
    if regs[17][7] != json_data.final.SPSR[2] {
        error_string = fmt.aprintf("Fail: SPSR(7) is %d\n,      should be %d", Flags(regs[17][7]), Flags(json_data.final.SPSR[2]))
    }
    if regs[17][2] != json_data.final.SPSR[3] {
        error_string = fmt.aprintf("Fail: SPSR(2) is %d\n,      should be %d", Flags(regs[17][2]), Flags(json_data.final.SPSR[3]))
    }
    if regs[17][11] != json_data.final.SPSR[4] {
        error_string = fmt.aprintf("Fail: SPSR(11) is %d\n,      should be %d", Flags(regs[17][11]), Flags(json_data.final.SPSR[4]))
    }
    if pipeline[0] != json_data.final.pipeline[0] {
        error_string = fmt.aprintf("Fail: pipeline 0 is %d,      should be %d", pipeline[0], json_data.final.pipeline[0])
    }
    /*if cycle != transactions[transaction_cnt-1].cycle {
        error_string = fmt.aprintf("Fail: cycle is %d, should be %d", cycle, transactions[transaction_cnt-1].cycle)
    }*/
    if error_string != "" {
        when TEST_BREAK_ERROR {
            fmt.println(json_data)
            fmt.print("Test #: ")
            fmt.println(test_count)
            fmt.println(error_string)
            test_fail = true
            quit = true
        }
        fail_cnt += 1
    }
    quit = true
}

test_read32 :: proc(addr: u32) -> u32 {
    if addr != transactions[transaction_cnt].addr {
        error_string = fmt.aprintf("Fail: r transaction %d is %d, should be %d", transaction_cnt, addr, transactions[transaction_cnt].addr)
    }
    tmp := transactions[transaction_cnt].data
    transaction_cnt += 1
    return tmp
}

test_write32 :: proc(addr: u32, value: u32) {
    if addr != transactions[transaction_cnt].addr {
        error_string = fmt.aprintf("Fail: w transaction %d is %d, should be %d", transaction_cnt, addr, transactions[transaction_cnt].addr)
    }
    if value != transactions[transaction_cnt].data {
        error_string = fmt.aprintf("Fail: w data %d is %d, should be %d", transaction_cnt, value, transactions[transaction_cnt].data)
    }
    transaction_cnt += 1
}

test_get_mul :: proc(opcode: u32) -> bool {
    if(CPSR.Thumb) {
        opcode := u16(opcode)
        id := opcode & 0xF800
        if(id == 0x4000) {
            if(!utils_bit_get16(opcode, 10)) {
                Op := (opcode & 0x03C0) >> 6
                if(Op == 13) {
                    return true
                }
            }
        }
    } else {
        id := opcode & 0xE000000
        if(id == 0x00000000) {
            if((opcode & 0x10000F0) == 0x0000090) {
                return true
            }
        }
    }
    return false
}