const std = @import("std");
const Allocator = std.mem.Allocator;
const Cpu = @import("Cpu.zig");
const Machine = @This();
const TuiCtx = @import("tui/app.zig").Ctx;
const exception = @import("exception.zig");
const Exception = exception.Exception;

const max_aling = 64;
const max_aling_log2 = std.mem.Alignment.@"64";

const debug_out = 0x10;

const ram_start = 0x80000000;

cpu: Cpu,
ram: []align(max_aling) u8,

output_to_tui_terminal: bool,
to_host_addr: ?u32,

pub fn init(gpa: Allocator, ram_size_mib: u32) !Machine {
    return .{
        .cpu = .init(),
        .ram = try gpa.alignedAlloc(u8, max_aling_log2, ram_size_mib*1024*1024),
        .output_to_tui_terminal = false,
        .to_host_addr = null,
    };
}

pub fn deinit(machine: *Machine, gpa: Allocator) void {
    gpa.free(machine.ram);
}

pub fn step(machine: *Machine) void {
    machine.cpu.exec() catch |exc| {
        exception.take(&machine.cpu, exc);
    };
}

pub fn runTest(machine: *Machine) !void {
    for (0..@import("tests.zig").max_cycles) |_| {
        machine.step();
        if (machine.cpu.last_read_addres == machine.to_host_addr.?+4) return;
    }

    return error.TestMaxCyclesExceded;
}

pub inline fn getRamSlice(machine: *Machine, addr: u32, len: u32) []u8 {
    std.debug.assert(addr >= ram_start);
    return machine.ram[(addr-ram_start)..][0..len];
}

pub inline fn load(machine: *Machine, comptime T: type, addr: u32) Exception!T {
    machine.cpu.last_read_addres = addr;
    if (!std.mem.isAligned(addr, @alignOf(T))) return error.LoadAddressMisaligned;

    switch (addr) {
        ram_start...std.math.maxInt(u32) => {
            const ptr: *T = @ptrCast(@alignCast(machine.ram.ptr + (addr-ram_start)));
            return ptr.*;  
        },
        
        else => return error.LoadAccessFault,
    }
}

pub inline fn store(machine: *Machine, comptime T: type, val: T, addr: u32) Exception!void {
    machine.cpu.last_read_addres = addr;
    if (!std.mem.isAligned(addr, @alignOf(T))) return error.StoreAddressMisaligned;

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

        else => return error.StoreAccessFault,
    }
}

