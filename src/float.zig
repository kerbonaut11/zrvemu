const std = @import("std");
pub const c = @cImport({
    @cInclude("fenv.h");
});

pub const Regs = [32]extern union {
    bits32: u32,
    s: f32,
};

pub const FCSR = packed struct(u32) {
    nx: bool,
    uf: bool,
    of: bool,
    dz: bool,
    nv: bool,
    rm: RoundMode,
};

pub const RoundMode = enum(u3) {
    rne,
    rtz,
    rdn,
    rup,
    dyn = 0b111,
    _,
};
