const std = @import("std");
const Cpu = @import("Cpu.zig");
const Exception = @import("exception.zig").Exception;

pub const Mode = enum(u2) {
    user = 0b00,
    supervisor = 0b01,
    machine = 0b11,
    debug = 0b10,
};

pub const Csr = enum(u12) {
    cycle  = 0xc00,
    cycleh = 0xc80,

    sscratch = 0x140,
    sepc,
    scause,
    stval,
    sip,
    scountovf = 0xda0,

    mvendorid = 0xf11,
    marchid,
    mimpid,
    mhartid,
    mconfigptr,

    mstatus = 0x300,
    misa,
    medeleg,
    mideleg,
    mie,
    mtvec,
    mcounteren,
    mstatush = 0x310,
    medelegh = 0x312,

    mscratch = 0x340,
    mepc,
    mcause,
    mtval,
    mip,
    mtinst = 0x34a,
    mtval2,

    mnscratch = 0x740,
    mnepc,
    mncause,
    mnstatus = 0x744,

    satp = 0x180,

    pmpcfg0   = 0x3a0,
    pmpcfg15  = 0x3af,
    pmpaddr0  = 0x3b0,
    pmpaddr6e = 0x3ef,

    sstatus  = 0x100,
    sie = 0x104,
    stvec,
    scounteren,
    _,

    pub const Set = struct {
        vals: [std.math.maxInt(u12)]u32,

        pub inline fn get(csrs: *Set, csr: Csr) *u32 {
            return &csrs.vals[@intFromEnum(csr)];
        }

        pub fn read(csrs: *Set, csr: Csr) !u32 {
            switch (csr) {
                else => return csrs.get(csr).*,
                _ => return error.IllegalInstruction,
            }
        }

        pub fn write(csrs: *Set, csr: Csr, val: u32) !void {
            if (csr.isReadOnly()) return error.IllegalInstruction;

            switch (csr) {
                else => csrs.get(csr).* = val,
                _ => return error.IllegalInstruction,
            }
        }

        pub fn mstatus(csrs: *Set) *MStatus {
            return @ptrCast(csrs.get(.mstatus));
        }

        pub fn mtvec(csrs: *Set) *MTVec {
            return @ptrCast(csrs.get(.mtvec));
        }

        pub fn misa(csrs: *Set) *MISA {
            return @ptrCast(csrs.get(.misa));
        }
    };

    pub fn isReadOnly(csr: Csr) bool {
        return @intFromEnum(csr) >> 10 == 0b11;
    }

};

const MStatus = packed struct(u32) {
    wpri0: u1,
    sie: bool,
    wpri1: u1,
    mie: bool,
    wpri2: u1,
    spie: bool,
    ube: bool,
    mpie: bool,
    spp: bool,
    vs: u2,
    mpp: Mode,
    fs: u2,
    xs: u2,
    mprv: bool,
    sum: bool,
    mxr: bool,
    tvm: bool,
    tw: bool,
    tsr: bool,
    spelp: bool,
    sdt: bool,
    wpri3: u6,
    sd: bool,
};

const MTVec = packed struct(u32) {
    mode: enum(u2) {
        direct   = 0b00,
        vectored = 0b01,
        _,
    },

    addr: u30,
};

const MISA = packed struct(u32) {
    a: bool = false,
    b: bool = false,
    c: bool = false,
    d: bool = false,
    e: bool = false,
    f: bool = false,
    g: bool = false,
    h: bool = false,
    i: bool = true,
    j: bool = false,
    k: bool = false,
    l: bool = false,
    m: bool = true,
    n: bool = false,
    o: bool = false,
    p: bool = false,
    q: bool = false,
    r: bool = false,
    s: bool = false,
    t: bool = false,
    u: bool = false,
    v: bool = false,
    w: bool = false,
    x: bool = false,
    y: bool = false,
    z: bool = false,
    warl: u4 = 0,
    mxl: u2 = 1,
};

const testing = std.testing;
test "Layout" {
    try testing.expectEqual(17, @bitOffsetOf(MStatus, "mprv"));
    try testing.expectEqual(11, @bitOffsetOf(MStatus, "mpp"));
}
