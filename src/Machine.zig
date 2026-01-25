const std = @import("std");
const Allocator = std.mem.Allocator;
const Cpu = @import("Cpu.zig");
const Machine = @This();
const TuiCtx = @import("tui/app.zig").Ctx;
const Exception = @import("exception.zig").Exception;

const max_aling = 64;
const max_aling_log2 = std.mem.Alignment.@"64";

const debug_out = 0x10;

const ram_start = 0x80000000;

cpu: Cpu,
ram: []align(max_aling) u8,
output_to_tui_terminal: bool,

pub fn init(gpa: Allocator, ram_size_mib: u32) !Machine {
    return .{
        .cpu = .init(),
        .ram = try gpa.alignedAlloc(u8, max_aling_log2, ram_size_mib*1024*1024),
        .output_to_tui_terminal = false,
    };
}

pub fn deinit(machine: *Machine, gpa: Allocator) void {
    gpa.free(machine.ram);
}

pub fn step(machine: *Machine) void {
    machine.cpu.exec() catch |err| switch (err) {
        else => std.debug.panic("0x{x}", .{machine.cpu.pc}),
    };
}

pub inline fn getRamSlice(machine: *Machine, addr: u32, len: u32) []u8 {
    std.debug.assert(addr >= ram_start);
    return machine.ram[(addr-ram_start)..][0..len];
}

inline fn assertAlign(comptime T: type, addr: u32) Exception!void {
    if (!std.mem.isAligned(addr, @alignOf(T))) return error.LoadAddressMisaligned;
}

pub inline fn load(machine: *Machine, comptime T: type, addr: u32) Exception!T {
    try assertAlign(T, addr);

    switch (addr) {
        ram_start...std.math.maxInt(u32) => {
            const ptr: *T = @ptrCast(@alignCast(machine.ram.ptr + (addr-ram_start)));
            return ptr.*;  
        },
        
        else => return error.LoadAccessFault,
    }
}

pub inline fn store(machine: *Machine, comptime T: type, val: T, addr: u32) Exception!void {
    try assertAlign(T, addr);

    switch (addr) {
        debug_out => {
            const bytes: []const u8 = @ptrCast(&val);
            if (machine.output_to_tui_terminal) {
                const ctx: *TuiCtx = @fieldParentPtr("machine", machine);
                ctx.emulated_terminal.write(bytes[0]) catch {};
            }
        },

        ram_start...std.math.maxInt(u32) => {
            const ptr: *T = @ptrCast(@alignCast(machine.ram.ptr + (addr-ram_start)));
            ptr.* = val;  
        },

        else => return error.LoadAccessFault,
    }
}

