const std = @import("std");
const Allocator = std.mem.Allocator;
const Cpu = @import("Cpu.zig");
const Machine = @This();

const max_aling = 64;
const max_aling_log2 = std.mem.Alignment.@"64";

gpa: Allocator,
cpu: Cpu,
ram: []align(max_aling) u8,

pub fn init(gpa: Allocator, ram_size_mib: u32) !Machine {
    return .{
        .cpu = .init(),
        .ram = try gpa.alignedAlloc(u8, max_aling_log2, ram_size_mib*1024*1024),
        .gpa = gpa,
    };
}

pub inline fn getPtr(machine: *Machine, comptime T: type, addr: u32) *T {
    if (addr + @sizeOf(T) > machine.ram.len) unreachable;
    if (!std.mem.isAligned(addr, @alignOf(T))) unreachable;

    return @ptrCast(@alignCast(machine.ram.ptr + addr));
}

pub inline fn load(machine: *Machine, comptime T: type, addr: u32) T {
    return machine.getPtr(T, addr).*;
}

pub inline fn store(machine: *Machine, comptime T: type, val: T, addr: u32) void {
    machine.getPtr(T, addr).* = val;
}

pub fn deinit(machine: *Machine) void {
    machine.gpa.free(machine.ram);
}
