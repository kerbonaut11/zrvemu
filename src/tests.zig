const std = @import("std");
const testing = std.testing;
const Machine = @import("Machine.zig");
const loadElfFromFile = @import("load_elf.zig").loadElfFromFile;

pub const max_cycles = 10_000;
const tests = [_][]const u8{
    "rv32ui-p-add",
    "rv32ui-p-add",
    "rv32ui-p-addi",
    "rv32ui-p-and",
    "rv32ui-p-andi",
    "rv32ui-p-auipc",
    "rv32ui-p-beq",
    "rv32ui-p-bge",
    "rv32ui-p-bgeu",
    "rv32ui-p-blt",
    "rv32ui-p-bltu",
    "rv32ui-p-bne",
    "rv32ui-p-fence_i",
    "rv32ui-p-jal",
    "rv32ui-p-jalr",
    "rv32ui-p-lb",
    "rv32ui-p-lbu",
    "rv32ui-p-ld_st",
    "rv32ui-p-lh",
    "rv32ui-p-lhu",
    "rv32ui-p-lui",
    "rv32ui-p-lw",
    //"rv32ui-p-ma_data",
    "rv32ui-p-or",
    "rv32ui-p-ori",
    "rv32ui-p-sb",
    "rv32ui-p-sh",
    "rv32ui-p-simple",
    "rv32ui-p-sll",
    "rv32ui-p-slli",
    "rv32ui-p-slt",
    "rv32ui-p-slti",
    "rv32ui-p-sltiu",
    "rv32ui-p-sltu",
    "rv32ui-p-sra",
    "rv32ui-p-srai",
    "rv32ui-p-srl",
    "rv32ui-p-srli",
    "rv32ui-p-st_ld",
    "rv32ui-p-sub",
    "rv32ui-p-sw",
    "rv32ui-p-xor",
    "rv32ui-p-xori",

    "rv32um-p-div",
    "rv32um-p-divu",
    "rv32um-p-mul",
    "rv32um-p-mulh",
    "rv32um-p-mulhsu",
    "rv32um-p-mulhu",
    "rv32um-p-rem",
    "rv32um-p-remu",
};

fn runOfficialTest(file: std.fs.File) !void {
    var machine = try Machine.init(testing.allocator, 64);
    defer machine.deinit(testing.allocator);

    try loadElfFromFile(file, &machine);

    try machine.runTest();

    try testing.expectEqual(0, machine.cpu.regs[10]); //a0
    try testing.expectEqual(93, machine.cpu.regs[17]); //a7
}

test {
    var test_dir = try std.fs.cwd().openDir("tests", .{.iterate = true});
    defer test_dir.close();

    for (tests) |test_name| {
        std.debug.print("running {s}\n", .{test_name});

        const file = try test_dir.openFile(test_name, .{});
        defer file.close();

        try runOfficialTest(file);

        std.debug.print("succesful\n", .{});
    }
}
