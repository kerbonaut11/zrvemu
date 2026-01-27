const std = @import("std");
const Writer = std.io.Writer;
const instrs = @import("instr.zig");
const Instr = instrs.Instr;
const bit = @import("bit_manip.zig");
const Cpu = @import("Cpu.zig");
const tagName = std.enums.tagName;

instr: Instr,
addr: ?u32,

pub fn format(disasm: @This(), w: *Writer) !void {
    if (disasm.addr) |addr| {
        try w.print("{x:08}:{x:08}  ", .{addr, disasm.instr.bits});
    }

    const instr = disasm.instr;

    if (instr.bits == 0x00000013) return w.print("nop", .{});

    try switch (instr.r.opcode) {
        .op_imm   => opImm(w, instr.i),
        .op       => op(w, instr.r),
        .load     => load(w, instr.i),
        .store    => store(w, instr.s),
        .auipc    => auipc(w, instr.u),
        .lui      => lui(w, instr.u),
        .jal      => jal(w, instr.u),
        .jalr     => jalr(w, instr.i),
        .branch   => branch(w, instr.s),
        .system   => system(w, instr.i),
        .misc_mem => miscMem(w, instr.i),
        _ => w.print("unimp", .{}),
    };
}

const memnomic_fmt = "{s: <8}";

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
    "t3","t4","t5","t6",
};

const OffsetReg = struct {
    offset: i32,
    reg: u5,

    pub fn format(f: @This(), w: *Writer) !void {
        if (f.reg != Cpu.zero) {
            try w.print("{s}", .{reg_names[f.reg]});
            if (f.offset == 0) return;
            try w.print("{s}{}", .{if (f.offset > 0) "+" else "-", @abs(f.offset)});
        } else {
            try w.print("{}", .{f.offset});
        }
    }
};

fn opImm(w: *Writer, instr: Instr.IType) !void {
    const funct3 = instr.funct3.op;
    const funct7_modifier_bit = @as(Instr.RType, @bitCast(instr)).funct7 == 0b0100000;

    if (funct3 == .add and instr.getImm() == 0) {
        try w.print(memnomic_fmt ++ "{s}, {s}", .{"mv", reg_names[instr.rd], reg_names[instr.rs1]});
    } else {
        const memnomic = if (funct7_modifier_bit and funct3 == .srl) "sra" else @tagName(funct3);
        try w.print(memnomic_fmt ++ "{s}, {s}, {}", .{memnomic, reg_names[instr.rd], reg_names[instr.rs1], bit.u2i(instr.getImm())});
    }
}

fn op(w: *Writer, instr: Instr.RType) !void {
    if (instr.funct7 == 1) return mulDivOp(w, instr);
    const funct3 = instr.funct3.op;
    const funct7_modifier_bit = instr.funct7 == 0b0100000;

    const memnomic = 
    if (funct7_modifier_bit and funct3 == .srl)
        "sra"
    else if (funct7_modifier_bit and funct3 == .add)
        "sub"
    else
        @tagName(funct3);

    try w.print(memnomic_fmt ++ "{s}, {s}, {s}", .{memnomic, reg_names[instr.rd], reg_names[instr.rs1], reg_names[instr.rs2]});
}

fn mulDivOp(w: *Writer, instr: Instr.RType) !void {
    try w.print(memnomic_fmt ++ "{s}, {s}, {s}", .{@tagName(instr.funct3.mul_div_op), reg_names[instr.rd], reg_names[instr.rs1], reg_names[instr.rs2]});
}

fn auipc(w: *Writer, instr: Instr.UType) !void {
    try w.print(memnomic_fmt ++ "{s}, 0x{x}", .{"auipc", reg_names[instr.rd], instr.getImm()});
}

fn lui(w: *Writer, instr: Instr.UType) !void {
    try w.print(memnomic_fmt ++ "{s}, 0x{x}", .{"lui", reg_names[instr.rd], instr.getImm()});
}

fn jal(w: *Writer, instr: Instr.UType) !void {
    if (instr.rd == Cpu.zero) {
        try w.print(memnomic_fmt ++ "{}", .{"j", bit.u2i(instr.getJTypeOffset())});
    } else {
        try w.print(memnomic_fmt ++ "{s}, {}", .{"jal", reg_names[instr.rd], bit.u2i(instr.getJTypeOffset())});
    }
}

fn jalr(w: *Writer, instr: Instr.IType) !void {
    const src = OffsetReg{.offset = bit.u2i(instr.getImm()), .reg = instr.rs1};

    if (instr.rd == Cpu.zero) {
        if (instr.rs1 == Cpu.ra) {
            try w.print(memnomic_fmt, .{"ret"});
        } else {
            try w.print(memnomic_fmt ++ "{f}", .{"jr", src});
        }
    } else {
        try w.print(memnomic_fmt ++ "{s}, {f}", .{"jalr", reg_names[instr.rd], src});
    }
}

fn branch(w: *Writer, instr: Instr.SType) !void {
    try w.print("b{s: <6} {s}, {s}, {}", .{@tagName(instr.funct3.branch), reg_names[instr.rs1], reg_names[instr.rs2], bit.u2i(instr.getBTypeOffset())});
}

fn load(w: *Writer, instr: Instr.IType) !void {
    const addr = OffsetReg{.offset = bit.u2i(instr.getImm()), .reg = instr.rs1};
    const funct3_name = tagName(instrs.Funct3.Load, instr.funct3.load)
        orelse return w.print("unimp", .{});
    try w.print("l{s: <6} {s}, {f}", .{funct3_name, reg_names[instr.rd], addr});
}

fn store(w: *Writer, instr: Instr.SType) !void {
    const addr = OffsetReg{.offset = bit.u2i(instr.getImm()), .reg = instr.rs1};
    const funct3_name = tagName(instrs.Funct3.Store, instr.funct3.store)
        orelse return w.print("unimp", .{});
    try w.print("s{s: <6} {s}, {f}", .{funct3_name, reg_names[instr.rs2], addr});
}

fn system(w: *Writer, instr: Instr.IType) !void {
    const funct3 = instr.funct3.system;

    switch (funct3) {
        .priv => {
            const imm = tagName(instrs.SystemPrivImm, @enumFromInt(instr.imm))
                orelse return w.print("unimp", .{});
            try w.print(memnomic_fmt, .{imm});
        },

        .csrrw, .csrrs, .csrrc => {
            const csr_name = tagName(Cpu.Csr, @enumFromInt(instr.imm))
                orelse return w.print("unimp", .{});
            try w.print(memnomic_fmt ++ "{s}, {s}, {s}", .{@tagName(funct3), csr_name, reg_names[instr.rd], reg_names[instr.rs1]});
        },

        .csrrwi, .csrrsi, .csrrci => {
            const non_imm_funct3: instrs.Funct3.System = @enumFromInt(@intFromEnum(funct3) & 0b11);
            const csr_name = tagName(Cpu.Csr, @enumFromInt(instr.imm))
                orelse return w.print("unimp", .{});
            try w.print(memnomic_fmt ++ "{s}, {s}, 0b{b}", .{@tagName(non_imm_funct3), csr_name, reg_names[instr.rd], instr.rs1});
        },

        _ => try w.print(memnomic_fmt, .{"unimp"})
    }
}

fn miscMem(w: *Writer, instr: Instr.IType) !void {
    const memnomic = switch (instr.funct3.misc_mem) {
        .fence   => "fence",
        .fence_i => "fence.i",
        _ => "unimp"
    };

    try w.print(memnomic_fmt, .{memnomic});
}


