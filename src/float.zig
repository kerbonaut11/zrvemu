const std = @import("std");
const math = std.math;
pub const c = @cImport({
    @cInclude("softfloat.h");
    @cInclude("softfloat_types.h");
});

const Cpu = @import("Cpu.zig");

pub const S = c.float32_t;
pub const D = c.float64_t;

pub const Reg = extern union {
    nanbox: extern struct {
        _base: u32,
        fill32: u32,

        inline fn fillS(reg: *@This()) void {
            reg.fill32 = math.maxInt(u32);
        }
    },

    w: u32,
    s: S,
    l: u64,
    d: D,
};

pub const Regs = struct {
    vals: [32]Reg,

    pub fn set(regs: *Regs, comptime T: type, reg: Cpu.Register, val: T) void {
        switch (T) {
            u32, S => {
                regs.vals[reg].nanbox.fillS();
                regs.vals[reg].s = @bitCast(val);
            },
            u64, D => @compileError("todo"),
            else => @compileError("invalid type"),
        }
    }

    pub fn get(regs: *Regs, comptime T: type, reg: Cpu.Register) T {
        return switch (T) {
            u32, S => @bitCast(regs.vals[reg].s),
            u64, D => @compileError("todo"),
            else => @compileError("invalid type"),
        };
    }

    pub fn binOp(regs: *Regs, comptime T: type, comptime name: []const u8, rd: Cpu.Register, rs1: Cpu.Register, rs2: Cpu.Register) void {
        const res = @field(c, softfloatName(T) ++ "_" ++ name)(regs.get(T, rs1), regs.get(T, rs2));
        regs.set(T, rd, canonicalizeNan(T, res));
    }

    pub fn sqrt(regs: *Regs, comptime T: type, rd: Cpu.Register, rs1: Cpu.Register) void {
        const res = @field(c, softfloatName(T) ++ "_sqrt")(regs.get(T, rs1));
        regs.set(T, rd, canonicalizeNan(T, res));
    }

    pub fn minmax(regs: *Regs, comptime T: type, max: bool, rd: Cpu.Register, rs1: Cpu.Register, rs2: Cpu.Register) void {
        const rs1_val = toHardware(T, regs.get(T, rs1));
        const rs1_repr = repr(T, regs.get(T, rs1));
        const rs2_val = toHardware(T, regs.get(T, rs2));
        const rs2_repr = repr(T, regs.get(T, rs2));

        var res_bits: intType(T) = @bitCast(if (!max) @min(rs1_val, rs2_val) else @max(rs1_val, rs2_val));
        const neg_zero: intType(T) = 1 << @bitSizeOf(T)-1;

        if (res_bits == 0 and (rs1_repr.sign == .negative or rs2_repr.sign == .negative) and !max) {
            res_bits = neg_zero;
        }

        if (res_bits == neg_zero and (rs1_repr.sign == .positive or rs2_repr.sign == .positive) and max) {
            res_bits = 0;
        }

        if (math.isSignalNan(rs1_val) or std.math.isSignalNan(rs2_val)) c.softfloat_exceptionFlags |= c.softfloat_flag_invalid;

        regs.set(T, rd, canonicalizeNan(T, @bitCast(res_bits)));
    }

    pub fn compare(regs: *Regs, comptime T: type, comptime name: []const u8, rs1: Cpu.Register, rs2: Cpu.Register) bool {
        return @field(c, softfloatName(T) ++ "_" ++ name)(regs.get(T, rs1), regs.get(T, rs2));
    }

    pub fn class(regs: *Regs, comptime T: type, rs1: Cpu.Register) u4 {
        const val = toHardware(T, regs.get(T, rs1));
        const val_repr = repr(T, regs.get(T, rs1));
        
        if (math.isSignalNan(val)) return 8;
        if (math.isNan(val)) return 9;

        if (math.isInf(val)) return if (val_repr.sign == .negative) 0 else 7;
        if (val == 0) return if (val_repr.sign == .negative) 3 else 4;
        if (math.isNormal(val)) return if (val_repr.sign == .negative) 1 else 6;
        return if (val_repr.sign == .negative) 2 else 5;
    }

    pub fn float2int(regs: *Regs, comptime F: type, comptime I: type, rs1: Cpu.Register) I {
        const func = @field(c, softfloatName(F) ++ "_to_" ++ softfloatIntName(I));
        const val = regs.get(F, rs1);

        var res: I = @truncate(func(val, c.softfloat_roundingMode, true));

        if (c.softfloat_exceptionFlags & c.softfloat_flag_invalid != 0) {
            res = if (toHardware(F, val) < 0.0) std.math.minInt(I) else std.math.maxInt(I);
        }

        return res;
    }

    pub fn int2float(regs: *Regs, comptime F: type, comptime I: type, rd: Cpu.Register, val: *const I) void {
        const res = @field(c, softfloatIntName(I) ++ "_to_" ++ softfloatName(F))(val.*);
        regs.set(F, rd, res);
    }

    pub fn signInject(regs: *Regs, comptime T: type, rd: Cpu.Register, rs1: Cpu.Register, rs2: Cpu.Register, comptime op: fn(u1, u1) u1) void {
        const rs1_repr = repr(T, regs.get(T, rs1));
        const rs2_repr = repr(T, regs.get(T, rs2));

        var res = rs1_repr;
        res.sign = @enumFromInt(op(@intFromEnum(rs1_repr.sign), @intFromEnum(rs2_repr.sign)));
        regs.set(T, rd, @bitCast(res));
    }

    pub fn fusedMulAdd(regs: *Regs, comptime T: type, rd: Cpu.Register, rs1: Cpu.Register, rs2: Cpu.Register, rs3: Cpu.Register, neg: bool, sub: bool) void {
        const mul = @field(c, softfloatName(T) ++ "_mul")(regs.get(T, rs1), regs.get(T, rs2));
        var mul_repr = repr(T, mul);
        if (neg) mul_repr.sign = if (mul_repr.sign == .negative) .positive else .negative;
        const func = if (sub) &@field(c, softfloatName(T) ++ "_sub") else &@field(c, softfloatName(T) ++ "_add");
        regs.set(T, rd, func(@bitCast(mul_repr), regs.get(T, rs3)));
    }
};

fn softfloatName(comptime T: type) []const u8 {
    return switch (T) {
        S => "f32",
        D => "f64",
        else => @compileError("invalid type"),
    };
}

fn softfloatIntName(comptime T: type) []const u8 {
    return std.fmt.comptimePrint("{s}{d}", .{if (@typeInfo(T).int.signedness == .signed) "i" else "ui", @bitSizeOf(T)});
}

fn hardwareType(comptime T: type) type {
    return switch (T) {
        S => f32,
        D => f64,
        else => @compileError("invalid type"),
    };
}

fn intType(comptime T: type) type {
    return switch (T) {
        S => u32,
        D => u64,
        else => @compileError("invalid type"),
    };
}

fn toHardware(comptime T: type, val: T) hardwareType(T) {
    return @bitCast(val);
}

fn repr(comptime T: type, val: T) math.FloatRepr(hardwareType(T)) {
    return @bitCast(val);
}

fn isNan(comptime T: type, val: T) bool {
    return math.isNan(toHardware(T, val));
}

fn canonicalizeNan(comptime T: type, val: T) T {
    return if (isNan(T, val)) 
        switch (T) {
            S => @bitCast(@as(u32, 0x7fc00000)),
            else => @compileError("invalid type"),
        }
    else
        val;
}

pub const Csr = packed struct {
    nx: bool,
    uf: bool,
    of: bool,
    dz: bool,
    nv: bool,
    rm: RoundMode,
};

pub const RoundMode = enum(u3) {
    rne = 0,
    rtz,
    rdn,
    rup,
    rmm,
    dyn = 0b111,
    _,

    pub fn enable(mode: RoundMode, cpu: *Cpu) void {
        switch (mode) {
            .rne => c.softfloat_roundingMode = c.softfloat_round_near_even,
            .rtz => c.softfloat_roundingMode = c.softfloat_round_minMag,
            .rdn => c.softfloat_roundingMode = c.softfloat_round_min,
            .rup => c.softfloat_roundingMode = c.softfloat_round_max,
            .rmm => c.softfloat_roundingMode = c.softfloat_round_near_maxMag,
            .dyn => cpu.csrs.fcsr().rm.enable(cpu),
            _ => @panic(""),
        }
    }
};

pub fn setFlags(cpu: *Cpu) void {
    const fflags: *u5 = @ptrCast(cpu.csr(.fcsr));
    fflags.* |= @truncate(c.softfloat_exceptionFlags);
    c.softfloat_exceptionFlags = 0;
}
