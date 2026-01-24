const std = @import("std");
const Allocator = std.mem.Allocator;
const Cpu = @import("Cpu.zig");
const Machine = @This();

const max_aling = 64;
const max_aling_log2 = std.mem.Alignment.@"64";

const debug_out = 0x10;

const ram_start = 0x80000000;

gpa: Allocator,
cpu: Cpu,
ram: []align(max_aling) u8,

const MemFault = error {
    LoadAddressMisaligned,
    LoadAccessFault,
};

pub fn init(gpa: Allocator, ram_size_mib: u32) !Machine {
    return .{
        .cpu = .init(),
        .ram = try gpa.alignedAlloc(u8, max_aling_log2, ram_size_mib*1024*1024),
        .gpa = gpa,
    };
}

pub fn step(machine: *Machine) void {
    machine.cpu.exec() catch |err| switch (err) {
        else => unreachable,
    };
}

pub inline fn getRamSlice(machine: *Machine, addr: u32, len: u32) []u8 {
    std.debug.assert(addr >= ram_start);
    return machine.ram[(addr-ram_start)..][0..len];
}

inline fn assertAlign(comptime T: type, addr: u32) !void {
    if (!std.mem.isAligned(addr, @alignOf(T))) return error.LoadAddressMisaligned;
}

pub inline fn load(machine: *Machine, comptime T: type, addr: u32) MemFault!T {
    try assertAlign(T, addr);

    switch (addr) {
        ram_start...std.math.maxInt(u32) => {
            const ptr: *T = @ptrCast(@alignCast(machine.ram.ptr + (addr-ram_start)));
            return ptr.*;  
        },
        
        else => return error.LoadAccessFault,
    }
}

pub inline fn store(machine: *Machine, comptime T: type, val: T, addr: u32) MemFault!void {
    try assertAlign(T, addr);

    switch (addr) {
        debug_out => {
            const bytes: []const u8 = @ptrCast(&val);
            std.debug.print("{u}", .{bytes[0]});
        },

        ram_start...std.math.maxInt(u32) => {
            const ptr: *T = @ptrCast(@alignCast(machine.ram.ptr + (addr-ram_start)));
            ptr.* = val;  
        },

        else => return error.LoadAccessFault,
    }
}

pub fn deinit(machine: *Machine) void {
    machine.gpa.free(machine.ram);
}
