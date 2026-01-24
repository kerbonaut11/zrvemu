const std = @import("std");
const Cpu = @import("Cpu.zig");
const Register = Cpu.Register;
const bit = @import("bit_manip.zig");
const putBitRange = bit.putBitRange;

pub const Instr = packed union {
    pub const RType = packed struct {
        opcode: Opcode,
        rd: Register,
        funct3: u3,
        rs1: Register,
        rs2: Register,
        funct7: u7,
    };

    pub const IType = packed struct {
        opcode: Opcode,
        rd: Register,
        funct3: u3,
        rs1: Register,
        imm: u12,

        pub fn getImm(instr: @This()) u32 {
            return bit.sext(instr.imm);
        }
    };

    pub const SType = packed struct {
        opcode: Opcode,
        imm_lo: u5,
        funct3: u3,
        rs1: Register,
        rs2: Register,
        imm_hi: u7,

        pub fn getImm(instr: @This()) u32 {
            const imm: u12 = (@as(u12, instr.imm_hi) << 5) | instr.imm_lo;
            return bit.sext(imm);
        }

        pub fn getBTypeOffset(instr: @This()) u32 {
            const bits: u32 = @bitCast(instr);
            var res: u13 = 0;
            res = putBitRange(bits, res, 11, 8,  1);
            res = putBitRange(bits, res, 30, 25, 5);
            res = putBitRange(bits, res, 7,  7,  11);
            res = putBitRange(bits, res, 31, 31, 12);

            return bit.sext(res);
        }
    };

    pub const UType = packed struct {
        opcode: Opcode,
        rd: Register,
        unshifted_imm: u20,

        pub fn getImm(instr: @This()) u32 {
            return @as(u32, instr.unshifted_imm) << 12;
        }

        pub fn getJTypeOffset(instr: @This()) u32 {
            const bits: u32 = @bitCast(instr);
            var res: u21 = 0;
            res = putBitRange(bits, res, 30, 21, 1);
            res = putBitRange(bits, res, 20, 20, 11);
            res = putBitRange(bits, res, 19, 12, 12);
            res = putBitRange(bits, res, 31, 31, 20);

            const signed: i32 = @as(i21, @bitCast(res));
            return @bitCast(signed);
        }
    };

    bits: u32,

    r: RType,
    i: IType,
    s: SType,
    u: UType,
};

pub const Opcode = enum(u7) {
    op_imm  = 0b0010011,
    op      = 0b0110011,
    load    = 0b0000011,
    store   = 0b0100011,
    lui     = 0b0110111,
    auipc   = 0b0010111,
    jal     = 0b1101111,
    jalr    = 0b1100111,
    branch  = 0b1100011,
    _,
};

pub const funct3 = struct {
    pub const Op = enum(u3) {
        add     = 0b000,
        sll     = 0b001,
        slt     = 0b010,
        sltu    = 0b011,
        xor     = 0b100,
        srl     = 0b101,
        @"or"   = 0b110,
        @"and"  = 0b111,
    };

    pub const Load = enum(u3) {
        b  = 0b000,
        h  = 0b001,
        w  = 0b010,
        bu = 0b100,
        hu = 0b101,
    };

    pub const Store = enum(u3) {
        b = 0b000,
        h = 0b001,
        w = 0b010,
    };

    pub const Branch = enum(u3) {
        eq  = 0b000,
        ne  = 0b001,
        lt  = 0b100,
        ge  = 0b101,
        ltu = 0b110,
        geu = 0b111,
    };
};


const testing = std.testing;

test "Instr repr" {
    try testing.expectEqual(4, @sizeOf(Instr));
}

test putBitRange {
    try testing.expectEqual(0b1100, putBitRange(0b011110, 0, 3, 2, 2));
}

test "j-type" {
    const instrs = [_]u32{
        0x0000006f,
        0x0040006f,
        0x0080006f,
        0xffdff06f,
        0xff9ff06f,
    };
    const offsets = [_]i32{
        0,
        4,
        8,
        -4,
        -8,
    };

    for (instrs, offsets) |instr, expected_offset| {
        const offset = (Instr{.bits = instr}).u.getJTypeOffset();
        try testing.expectEqual(expected_offset, @as(i32, @bitCast(offset)));
    }
}

test "b-type" {
    const instrs = [_]u32{
        0x00000063,
        0x00000263,
        0x00000463,
        0xfe000ee3,
        0xfe000ce3,
    };
    const offsets = [_]i32{
        0,
        4,
        8,
        -4,
        -8,
    };

    for (instrs, offsets) |instr, expected_offset| {
        const offset = (Instr{.bits = instr}).s.getBTypeOffset();
        try testing.expectEqual(expected_offset, @as(i32, @bitCast(offset)));
    }
}
