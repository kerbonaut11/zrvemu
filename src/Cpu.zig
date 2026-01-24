const std = @import("std");
const instrs = @import("instr.zig");
const Instr = @import("instr.zig").Instr;
const Cpu = @This();
const Machine = @import("Machine.zig");
const bit = @import("bit_manip.zig");
const disam = @import("disasm.zig");

next_pc: u32 align(64),
pc: u32,
regs: [32]u32,

pub const Register = u5;
pub const zero: Register = 0;
pub const ra: Register = 1;

pub fn init() Cpu {
    return .{
        .regs = std.mem.zeroes([32]u32),
        .pc = 0,
        .next_pc = 0,
    };
}

pub fn machine(cpu: *Cpu) *Machine {
    return @fieldParentPtr("cpu", cpu);
}


pub fn exec(cpu: *Cpu) void {
    cpu.next_pc = cpu.pc +% @sizeOf(Instr);
    const instr = cpu.machine().load(Instr, cpu.pc);

    switch (instr.r.opcode) {
        .op_imm => cpu.op(instr, true),
        .op     => cpu.op(instr, false),
        .load   => cpu.load(instr.i),
        .store  => cpu.store(instr.s),
        .auipc  => cpu.auipc(instr.u),
        .lui    => cpu.lui(instr.u),
        .jal    => cpu.jal(instr.u),
        .jalr   => cpu.jalr(instr.i),
        .branch => cpu.branch(instr.s),
        _ => std.debug.panic("{x}:{b:07}\n", .{cpu.pc, @intFromEnum(instr.r.opcode)}),
    }


    cpu.regs[zero] = 0;
    cpu.pc = cpu.next_pc;
}


fn op(cpu: *Cpu, instr: Instr, imm: bool) void {
    const funct3: instrs.funct3.Op = @enumFromInt(instr.r.funct3);
    const funct7_modifier_bit = instr.r.funct7 == 0b0100000;

    const rs1 = cpu.regs[instr.r.rs1];
    const rs1_signed = bit.u2i(rs1);
    const rs2 = if (imm) instr.i.getImm() else cpu.regs[instr.r.rs2];
    const rs2_signed = bit.u2i(rs2);

    const val = switch (funct3) {
        .add    => if (funct7_modifier_bit and !imm) rs1 -% rs2 else rs2 +% rs2,
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
    cpu.regs[instr.rd] = cpu.next_pc;
    cpu.next_pc = cpu.regs[instr.rs1] +% instr.getImm();
    cpu.next_pc |= ~@as(u32, 1);
}

fn branch(cpu: *Cpu, instr: Instr.SType) void {
    const funct3: instrs.funct3.Branch = @bitCast(instr.funct3);

    const rs1 = cpu.regs[instr.rs1];
    const rs2 = cpu.regs[instr.rs2];

    const condition_met = switch (funct3.cond) {
        .eq => rs1 == rs2,
        .lt => bit.u2i(rs1) < bit.u2i(rs2),
        .ltu => rs1 < rs2,
    } != funct3.invert;

    if (condition_met) {
        cpu.next_pc = cpu.pc +% instr.getBTypeOffset();
    }
}

fn load(cpu: *Cpu, instr: Instr.IType) void {
    const funct3: instrs.funct3.Load = @enumFromInt(instr.funct3);
    const addr = cpu.regs[instr.rs1] +% instr.getImm();
    const m= cpu.machine();

    const result: u32 = switch (funct3) {
        .b  => bit.sext(m.load(i8,  addr)),
        .bu => m.load(u8,  addr),
        .h  => bit.sext(m.load(i16, addr)),
        .hu => m.load(u16, addr),
        .w  => m.load(u32, addr),
    };

    cpu.regs[instr.rd] = result;
}

fn store(cpu: *Cpu, instr: Instr.SType) void {
    const funct3: instrs.funct3.Store = @enumFromInt(instr.funct3);
    const addr = cpu.regs[instr.rs1] +% instr.getImm();
    const val = cpu.regs[instr.rs2];
    const m= cpu.machine();

    switch (funct3) {
        .b  => m.store(u8,  @truncate(val), addr),
        .h  => m.store(u16, @truncate(val), addr),
        .w  => m.store(u32, @truncate(val), addr),
    }
}

