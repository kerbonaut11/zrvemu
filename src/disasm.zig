const std = @import("std");
const instrs = @import("instr.zig");
const Instr = instrs.Instr;
const bit = @import("bit_manip.zig");

pub fn printWithAddr(instr: Instr, addr: u32, w: *std.Io.Writer) !void {
    try w.print("{x:08}:{x:08}  ", .{addr, instr.bits});
    try print(instr, w);
}

pub fn print(instr: Instr, w: *std.Io.Writer) !void {
    try switch (instr.r.opcode) {
        .op_imm => opImm(instr.i, w),
        .op     => op(instr.r, w),
        .load   => load(instr.i, w),
        .store  => store(instr.s, w),
        .auipc  => auipc(instr.u, w),
        .lui    => lui(instr.u, w),
        .jal    => jal(instr.u, w),
        .jalr   => unreachable,
        .branch => unreachable,
        _ => w.print("unimp", .{}),
    };
}

pub const reg_names = [32][]const u8{
    "zero",
    "ra",
    "sp",
    "gp",
    "tp",
    "t0","t1","t2",
    "s0","s1",
    "a0","a1","a2","a3","a4","a5","a6","a7",
    "s2","s3","s4","s5","s6","s7","s8","s9","s10","s11",
    "t3","t4","t5","pc",
};

fn opImm(instr: Instr.IType, w: *std.Io.Writer) !void {
    const funct3: instrs.funct3.Op = @enumFromInt(instr.funct3);
    const funct7_modifier_bit = @as(Instr.RType, @bitCast(instr)).funct7 == 0b0100000;

    const memnomic = if (funct7_modifier_bit and funct3 == .srl) "sra" else @tagName(funct3);
    try writeMemnomicPost(memnomic, 'i', w);
    try w.print("{s}, {s}, {}", .{reg_names[instr.rd], reg_names[instr.rs1], bit.u2i(instr.getImm())});
}

fn op(instr: Instr.RType, w: *std.Io.Writer) !void {
    const funct3: instrs.funct3.Op = @enumFromInt(instr.funct3);
    const funct7_modifier_bit = instr.funct7 == 0b0100000;

    const memnomic = 
    if (funct7_modifier_bit and funct3 == .srl)
        "sra"
    else if (funct7_modifier_bit and funct3 == .add)
        "sub"
    else
        @tagName(funct3);
    try writeMemnomic(memnomic, w);

    try w.print("{s}, {s}, {s}", .{reg_names[instr.rd], reg_names[instr.rs1], reg_names[instr.rs2]});
}

fn auipc(instr: Instr.UType, w: *std.Io.Writer) !void {
    try writeMemnomic("auipc", w);
    try w.print("0x{x}", .{instr.getImm()});
}

fn lui(instr: Instr.UType, w: *std.Io.Writer) !void {
    try writeMemnomic("lui", w);
    try w.print("0x{x}", .{instr.getImm()});
}

fn jal(instr: Instr.UType, w: *std.Io.Writer) !void {
    try writeMemnomic(if (instr.rd == 0) "j" else "jal", w);
    try w.print("{}", .{bit.u2i(instr.getJTypeOffset())});
}

fn load(instr: Instr.IType, w: *std.Io.Writer) !void {
    const funct3: instrs.funct3.Load = @enumFromInt(instr.funct3);
    try writeMemnomicPre('l', @tagName(funct3), w);

    const imm = bit.u2i(instr.getImm());
    try w.print("{s}, {s}{s}{d}", .{reg_names[instr.rd], reg_names[instr.rs1], if (imm < 0) "-" else "+", imm});
}

fn store(instr: Instr.SType, w: *std.Io.Writer) !void {
    const funct3: instrs.funct3.Store = @enumFromInt(instr.funct3);

    try writeMemnomicPre('s', @tagName(funct3), w);

    const imm = bit.u2i(instr.getImm());
    try w.print("{s}, {s}{s}{d}", .{reg_names[instr.rs2], reg_names[instr.rs1], if (imm < 0) "-" else "+", imm});
}


fn writeMemnomic(memnomic: []const u8, w: *std.io.Writer) !void {
    try writeMemnomicInner(null, memnomic, null, w);
}

fn writeMemnomicPre(pre: u8, memnomic: []const u8, w: *std.io.Writer) !void {
    try writeMemnomicInner(pre, memnomic, null, w);
}

fn writeMemnomicPost(memnomic: []const u8, post: u8, w: *std.io.Writer) !void {
    try writeMemnomicInner(null, memnomic, post, w);
}


fn writeMemnomicInner(prefix: ?u8, memnomic: []const u8, postfix: ?u8, w: *std.io.Writer) !void {
    var memnomic_align: usize = 8;

    if (prefix)  |ch| {try w.writeByte(ch); memnomic_align -= 1;}

    try w.writeAll(memnomic);
    memnomic_align -= memnomic.len;

    if (postfix) |ch| {try w.writeByte(ch); memnomic_align -= 1;}

    try w.splatByteAll(' ', memnomic_align);
}

