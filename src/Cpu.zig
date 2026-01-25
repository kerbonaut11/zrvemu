const std = @import("std");
const instrs = @import("instr.zig");
const Instr = @import("instr.zig").Instr;
const Cpu = @This();
const Machine = @import("Machine.zig");
const bit = @import("bit_manip.zig");
const disam = @import("disasm.zig");
const exception = @import("exception.zig");
const Exception = exception.Exception;
pub const Csr = @import("csr.zig").Csr;
pub const Mode = @import("csr.zig").Mode;

next_pc: u32 align(64),
pc: u32,

regs: [32]u32,

mode: Mode,
csrs: Csr.Set,

pub const Register = u5;
pub const zero: Register = 0;
pub const ra: Register = 1;

pub fn init() Cpu {
    var cpu =  Cpu{
        .regs = std.mem.zeroes([32]u32),
        .pc = 0,
        .next_pc = 0,
        .mode = .machine,
        .csrs = std.mem.zeroes(Csr.Set),
    };

    cpu.csrs.set(.mhartid, 0);

    return cpu;
}

pub fn machine(cpu: *Cpu) *Machine {
    return @fieldParentPtr("cpu", cpu);
}


pub fn exec(cpu: *Cpu) Exception!void {
    cpu.next_pc = cpu.pc +% @sizeOf(Instr);
    const instr = cpu.machine().load(Instr, cpu.pc)
        catch |err| return exception.loadToInstrFault(err);

    try switch (instr.r.opcode) {
        .op_imm   => cpu.op(instr, true),
        .op       => cpu.op(instr, false),
        .load     => cpu.load(instr.i),
        .store    => cpu.store(instr.s),
        .auipc    => cpu.auipc(instr.u),
        .lui      => cpu.lui(instr.u),
        .jal      => cpu.jal(instr.u),
        .jalr     => cpu.jalr(instr.i),
        .branch   => cpu.branch(instr.s),
        .misc_mem => cpu.miscMem(instr.i),
        .system   => cpu.system(instr.i),
        _ => return error.IllegalInstruction,
    };


    cpu.regs[zero] = 0;
    cpu.pc = cpu.next_pc;
    cpu.csrs.getPtr(.cycle).*  +%= 1;
    cpu.csrs.getPtr(.cycleh).* +%= @intFromBool(cpu.csrs.get(.cycle) == 0);
}

pub fn cycle(cpu: *Cpu) u64 {
    return (@as(u64, cpu.csrs.get(.cycleh)) << 32) | cpu.csrs.get(.cycle);
}

fn op(cpu: *Cpu, instr: Instr, imm: bool) void {
    const funct7_modifier_bit = instr.r.funct7 == 0b0100000;

    const rs1 = cpu.regs[instr.r.rs1];
    const rs1_signed = bit.u2i(rs1);
    const rs2 = if (imm) instr.i.getImm() else cpu.regs[instr.r.rs2];
    const rs2_signed = bit.u2i(rs2);

    const val = switch (instr.r.funct3.op) {
        .add    => if (funct7_modifier_bit and !imm) rs1 -% rs2 else rs1 +% rs2,
        .sltu   => @intFromBool(rs1 < rs2),
        .slt    => @intFromBool(rs1_signed < rs2_signed),
        .@"and" => rs1 & rs2,
        .xor    => rs1 ^ rs2,
        .@"or"  => rs1 | rs2,
        .sll    => rs1 << @truncate(rs2),
        .srl    => bit.arithShift(rs1_signed < 0 and funct7_modifier_bit, rs1, @truncate(rs2)),
    };

    cpu.regs[instr.r.rd] = val;
}

fn lui(cpu: *Cpu, instr: Instr.UType) void {
    cpu.regs[instr.rd] = instr.getImm();
}

fn auipc(cpu: *Cpu, instr: Instr.UType) void {
    cpu.regs[instr.rd] = cpu.pc +% instr.getImm();
}

fn jal(cpu: *Cpu, instr: Instr.UType) void {
    cpu.regs[instr.rd] = cpu.next_pc;
    cpu.next_pc = cpu.pc +% instr.getJTypeOffset();
}

fn jalr(cpu: *Cpu, instr: Instr.IType) void {
    const target_addr = cpu.regs[instr.rs1] +% instr.getImm();
    cpu.regs[instr.rd] = cpu.next_pc;
    cpu.next_pc = target_addr;
    cpu.next_pc &= ~@as(u32, 1);
}

fn branch(cpu: *Cpu, instr: Instr.SType) void {
    const rs1 = cpu.regs[instr.rs1];
    const rs2 = cpu.regs[instr.rs2];

    const condition_met = switch (instr.funct3.branch) {
        .eq  => rs1 == rs2,
        .ne  => rs1 != rs2,
        .lt  => bit.u2i(rs1) < bit.u2i(rs2),
        .ge  => bit.u2i(rs1) >= bit.u2i(rs2),
        .ltu => rs1 < rs2,
        .geu => rs1 >= rs2,
    };

    if (condition_met) {
        cpu.next_pc = cpu.pc +% instr.getBTypeOffset();
    }
}

fn load(cpu: *Cpu, instr: Instr.IType) !void {
    const addr = cpu.regs[instr.rs1] +% instr.getImm();
    const m= cpu.machine();

    const result: u32 = switch (instr.funct3.load) {
        .b  => bit.sext(try m.load(i8,  addr)),
        .bu => try m.load(u8,  addr),
        .h  => bit.sext(try m.load(i16, addr)),
        .hu => try m.load(u16, addr),
        .w  => try m.load(u32, addr),
        _ => return error.IllegalInstruction,
    };

    cpu.regs[instr.rd] = result;
}

fn store(cpu: *Cpu, instr: Instr.SType) !void {
    const addr = cpu.regs[instr.rs1] +% instr.getImm();
    const val = cpu.regs[instr.rs2];
    const m= cpu.machine();

    switch (instr.funct3.store) {
        .b  => try m.store(u8,  @truncate(val), addr),
        .h  => try m.store(u16, @truncate(val), addr),
        .w  => try m.store(u32, @truncate(val), addr),
        _ => return error.IllegalInstruction,
    }
}


fn miscMem(cpu: *Cpu, instr: Instr.IType) !void {
    _ = cpu;
    switch (instr.funct3.misc_mem) {
        .fence   => {},
        .fence_i => {},
        _ => return error.IllegalInstruction,
    }
}

fn system(cpu: *Cpu, instr: Instr.IType) !void {
    const funct3 = instr.funct3.system;
    switch (funct3) {
        .priv => {
            const imm: instrs.SystemPrivImm = @enumFromInt(instr.imm);
            switch (imm) {
                .ecall => return switch (cpu.mode) {
                    .user       => error.ECallFromUMode,
                    .supervisor => error.ECallFromSMode,
                    .machine    => error.ECallFromMMode,
                    .debug      => error.IllegalInstruction,
                },
                .ebreak => return error.BreakPoint,

                .sret => @panic("todo"),

                .mret => {
                    const mstatus = Csr.getMStatus(cpu);
                    cpu.next_pc = cpu.csrs.get(.mepc);
                    cpu.mode = mstatus.mpp;
                    if (cpu.mode == .machine or cpu.mode == .supervisor) mstatus.mprv = false;
                    mstatus.mie = mstatus.mpie;
                    mstatus.mpie = true;
                    mstatus.mpp = .user;

                },
                _ => return error.IllegalInstruction,
            }
        },

        .csrrw, .csrrwi => {
            const csr: Csr = @enumFromInt(instr.imm);

            if (instr.rd != zero) cpu.regs[instr.rd] = try csr.read(cpu);

            const rs1 = if (funct3 == .csrrw) cpu.regs[instr.rs1] else instr.rs1;
            try csr.write(cpu, rs1);
        },

        .csrrs, .csrrsi, .csrrc, .csrrci => {
            const csr: Csr = @enumFromInt(instr.imm);

            cpu.regs[instr.rd] = try csr.read(cpu);

            if (instr.rs1 == 0) return;
            const rs1 = if (funct3 == .csrrc or funct3 == .csrrs) cpu.regs[instr.rs1] else instr.rs1;
            const prev = cpu.csrs.get(csr);
            try csr.write(cpu, if (funct3 == .csrrs or funct3 == .csrrsi) prev | rs1 else prev & ~rs1);
        },

        _ => return error.IllegalInstruction,
    }
}

