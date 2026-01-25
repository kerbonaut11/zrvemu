const std = @import("std");
const testing = std.testing;
const Machine = @import("Machine.zig");
const loadElfFromFile = @import("load_elf.zig").loadElfFromFile;

pub const max_cycles = 10_000;

fn runOfficialTest(file: std.fs.File) !void {
    var machine = try Machine.init(testing.allocator, 64);
    defer machine.deinit(testing.allocator);

    try loadElfFromFile(file, &machine);

    try machine.runTest();

    try testing.expectEqual(0, machine.cpu.regs[10]); //a0
    try testing.expectEqual(93, machine.cpu.regs[17]); //a7
}

test {
    const test_dir = "official-tests-bin/isa";
    const tests = try std.fs.cwd().openDir(test_dir, .{.iterate = true});
    var file_iter = tests.iterateAssumeFirstIteration();

    while (try file_iter.next()) |entry| {
        if (std.fs.path.extension(entry.name).len != 0) continue;

        const base_isa_prefix = "rv32ui-p";
        if (!std.mem.eql(u8, base_isa_prefix, entry.name[0..base_isa_prefix.len])) continue;

        const file = try tests.openFile(entry.name, .{});
        defer file.close();

        std.debug.print("{s}\n", .{entry.name});

        try runOfficialTest(file);
    }
}
