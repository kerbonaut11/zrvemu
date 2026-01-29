const std = @import("std");
const Writer = std.io.Writer;
const instrs = @import("instr.zig");
const Instr = instrs.Instr;
const Funct3 = instrs.Funct3;
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
        .load_fp  => loadFP(w, instr.i),
        .store_fp => storeFP(w, instr.s),
        .op_fp    => opFP(w, instr.r),
        .fmadd    => floatFused(w,  "madd", instr.r4),
        .fmsub    => floatFused(w,  "msub", instr.r4),
        .fnmadd   => floatFused(w, "nmadd", instr.r4),
        .fnmsub   => floatFused(w, "nmsub", instr.r4),
        _ => w.print("unimp", .{}),
    };
}

const memnomic_fmt = "{s: <9}";

pub const xreg_names = [32][]const u8{
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

pub const freg_names = [32][]const u8{
    "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12", "f13", "f14", "f15",
    "f16", "f17", "f18", "f19", "f20", "f21", "f22", "f23", "f24", "f25", "f26", "f27", "f28", "f29", "f30", "f31",
};

pub fn printFloatMemnomic(w: *Writer, memnomic: []const u8, instr: anytype) !void {
    const instr_ = Instr{.bits = @bitCast(instr)};
    try w.print("f{s}.{s}", .{memnomic, @tagName(instr_.floatWidth())});
    try w.splatByteAll(' ', 6-memnomic.len);
}

pub fn printFloatMemnomicConv(w: *Writer, memnomic: []const u8, from: []const u8, to: []const u8) !void {
    try w.print("f{s}.{s}.{s}", .{memnomic, from, to});
    try w.splatByteAll(' ', 6-memnomic.len-from.len-to.len);
}

const OffsetReg = struct {
    offset: i32,
    reg: u5,

    pub fn format(f: @This(), w: *Writer) !void {
        if (f.reg != Cpu.zero) {
            try w.print("{s}", .{xreg_names[f.reg]});
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
    if (funct3 == .add and instr.rs1 == Cpu.zero) {
        try w.print(memnomic_fmt ++ "{s}, {}", .{"li", xreg_names[instr.rd], instr.getImm()});
    } else if (funct3 == .add and instr.getImm() == 0) {
        try w.print(memnomic_fmt ++ "{s}, {s}", .{"mv", xreg_names[instr.rd], xreg_names[instr.rs1]});
    } else {
        const memnomic = if (funct7_modifier_bit and funct3 == .srl) "sra" else @tagName(funct3);
        try w.print(memnomic_fmt ++ "{s}, {s}, {}", .{memnomic, xreg_names[instr.rd], xreg_names[instr.rs1], bit.u2i(instr.getImm())});
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

    try w.print(memnomic_fmt ++ "{s}, {s}, {s}", .{memnomic, xreg_names[instr.rd], xreg_names[instr.rs1], xreg_names[instr.rs2]});
}

fn mulDivOp(w: *Writer, instr: Instr.RType) !void {
    try w.print(memnomic_fmt ++ "{s}, {s}, {s}", .{@tagName(instr.funct3.mul_div_op), xreg_names[instr.rd], xreg_names[instr.rs1], xreg_names[instr.rs2]});
}

fn auipc(w: *Writer, instr: Instr.UType) !void {
    try w.print(memnomic_fmt ++ "{s}, 0x{x}", .{"auipc", xreg_names[instr.rd], instr.getImm()});
}

fn lui(w: *Writer, instr: Instr.UType) !void {
    try w.print(memnomic_fmt ++ "{s}, 0x{x}", .{"lui", xreg_names[instr.rd], instr.getImm()});
}

fn jal(w: *Writer, instr: Instr.UType) !void {
    if (instr.rd == Cpu.zero) {
        try w.print(memnomic_fmt ++ "{}", .{"j", bit.u2i(instr.getJTypeOffset())});
    } else {
        try w.print(memnomic_fmt ++ "{s}, {}", .{"jal", xreg_names[instr.rd], bit.u2i(instr.getJTypeOffset())});
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
        try w.print(memnomic_fmt ++ "{s}, {f}", .{"jalr", xreg_names[instr.rd], src});
    }
}

fn branch(w: *Writer, instr: Instr.SType) !void {
    try w.print("b{s: <7} {s}, {s}, {}", .{@tagName(instr.funct3.branch), xreg_names[instr.rs1], xreg_names[instr.rs2], bit.u2i(instr.getBTypeOffset())});
}

fn load(w: *Writer, instr: Instr.IType) !void {
    const addr = OffsetReg{.offset = bit.u2i(instr.getImm()), .reg = instr.rs1};
    const funct3_name = tagName(Funct3.Load, instr.funct3.load)
        orelse return w.print("unimp", .{});
    try w.print("l{s: <7} {s}, {f}", .{funct3_name, xreg_names[instr.rd], addr});
}

fn store(w: *Writer, instr: Instr.SType) !void {
    const addr = OffsetReg{.offset = bit.u2i(instr.getImm()), .reg = instr.rs1};
    const funct3_name = tagName(Funct3.Store, instr.funct3.store)
        orelse return w.print("unimp", .{});
    try w.print("s{s: <7} {s}, {f}", .{funct3_name, xreg_names[instr.rs2], addr});
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
            try w.print(memnomic_fmt ++ "{s}, {s}, {s}", .{@tagName(funct3), xreg_names[instr.rd], csr_name, xreg_names[instr.rs1]});
        },

        .csrrwi, .csrrsi, .csrrci => {
            const non_imm_funct3: Funct3.System = @enumFromInt(@intFromEnum(funct3) & 0b11);
            const csr_name = tagName(Cpu.Csr, @enumFromInt(instr.imm))
                orelse return w.print("unimp", .{});
            try w.print(memnomic_fmt ++ "{s}, {s}, 0b{b}", .{@tagName(non_imm_funct3), xreg_names[instr.rd], csr_name, instr.rs1});
        },

        _ => try w.print("unimp", .{})
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

fn floatFused(w: *Writer, memnomic: []const u8, instr: Instr.R4Type) !void {
    try printFloatMemnomic(w, memnomic, instr);
    try w.print(
        "{s}, {s}, {s}, {s}",
        .{freg_names[instr.rd], freg_names[instr.rs1], freg_names[instr.rs2], freg_names[instr.rs2]}
    );
}

fn fmvFloatType(instr: Instr.RType) []const u8 {
    return switch ((Instr{.bits = @bitCast(instr)}).floatWidth()) {
        .s => "w",
        _ => "?",
    };
}

fn opFP(w: *Writer, instr: Instr.RType) !void {
    const funct5: instrs.FPOpFunct5 = @enumFromInt(instr.funct7 >> 2);
    const memnomic = switch (funct5) {
        .add, .sub, .div, .mul => @tagName(funct5),

        .sign_inject => tagName(Funct3.FloatSignInject, instr.funct3.float_sign_inject)
            orelse return w.print("unimp", .{}),

        .minmax => if (instr.funct3.is_float_max) "max" else "min",

        .compare => tagName(Funct3.FloatCompare, instr.funct3.float_compare)
            orelse return w.print("unimp", .{}),

        .class_or_move_f2x => if (instr.funct3.is_float_class) {
            try printFloatMemnomic(w, "class", instr);
            try w.print("{s}, {s}", .{xreg_names[instr.rd], freg_names[instr.rs1]});
            return;
        } else {
            try printFloatMemnomicConv(w, "mv", "x", fmvFloatType(instr));
            try w.print("{s}, {s}", .{xreg_names[instr.rd], freg_names[instr.rs1]});
            return;
        },

        .move_x2f => {
            try printFloatMemnomicConv(w, "mv", fmvFloatType(instr), "x");
            try w.print("{s}, {s}", .{freg_names[instr.rd], xreg_names[instr.rs1]});
            return;
        },
        
        .float2int, .int2float => {
            const int_type = tagName(instrs.FloatIntConversionMode, @enumFromInt(instr.rs2))
                orelse return w.print("unimp", .{});
            const float_type = tagName(instrs.FloatWidth, (Instr{.bits = @bitCast(instr)}).floatWidth())
                orelse return w.print("unimp", .{});

            if (funct5 == .int2float) {
                try printFloatMemnomicConv(w, "cvt", float_type, int_type);
                try w.print("{s}, {s}", .{freg_names[instr.rd], xreg_names[instr.rs1]});
            } else {
                try printFloatMemnomicConv(w, "cvt", int_type, float_type);
                try w.print("{s}, {s}", .{xreg_names[instr.rd], freg_names[instr.rs1]});
            }

            return;
        },


        .sqrt => {
            try printFloatMemnomic(w, "sqrt", instr);
            try w.print("{s}, {s}", .{freg_names[instr.rd], freg_names[instr.rs1]});
            return;
        },

        _ => return w.print("unimp", .{}),
    };

    try printFloatMemnomic(w, memnomic, instr);
    const rd_is_xreg = funct5 == .compare;
    try w.print("{s}, {s}, {s}", .{(if (rd_is_xreg) xreg_names else freg_names)[instr.rd], freg_names[instr.rs1], freg_names[instr.rs2]});
}

fn loadFP(w: *Writer, instr: Instr.IType) !void {
    const addr = OffsetReg{.offset = bit.u2i(instr.getImm()), .reg = instr.rs1};
    const memnomic = tagName(Funct3.FloatLoadStore, instr.funct3.float_load_store)
        orelse return w.print("unimp", .{});
    try w.print("fl{s: <6} {s}, {f}", .{memnomic, freg_names[instr.rd], addr});
}

fn storeFP(w: *Writer, instr: Instr.SType) !void {
    const addr = OffsetReg{.offset = bit.u2i(instr.getImm()), .reg = instr.rs1};
    const memnomic = tagName(Funct3.FloatLoadStore, instr.funct3.float_load_store)
        orelse return w.print("unimp", .{});
    try w.print("fs{s: <6} {s}, {f}", .{memnomic, freg_names[instr.rs1], addr});
}
