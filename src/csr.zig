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

    pub const Set = std.EnumArray(@This(), u32);

    pub fn isReadOnly(csr: Csr) bool {
        return @intFromEnum(csr) >> 10 == 0b11;
    }

    pub fn read(csr: Csr, cpu: *Cpu) !u32 {
        switch (csr) {
            else => return cpu.csrs.get(csr),
            _ => return error.IllegalInstruction,
        }
    }

    pub fn write(csr: Csr, cpu: *Cpu, val: u32) !void {
        if (csr.isReadOnly()) return error.IllegalInstruction;

        switch (csr) {
            else => cpu.csrs.set(csr, val),
            _ => return error.IllegalInstruction,
        }
    }

    pub fn getMStatus(cpu: *Cpu) *MStatus {
        return @ptrCast(cpu.csrs.getPtr(.mstatus));
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

const testing = std.testing;
test "MStatus Layout" {
    try testing.expectEqual(@bitOffsetOf(MStatus, "mprv"), 17);
    try testing.expectEqual(@bitOffsetOf(MStatus, "mpp"), 11);
}
