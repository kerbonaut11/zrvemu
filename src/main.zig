const std = @import("std");

pub fn main() !void {
    var args = std.process.args();
    const exe_path = args.next().?;
    _ = exe_path;
    const file_arg = args.next();

    try @import("tui/app.zig").run(file_arg);
}

test {
    _ = @import("Cpu.zig");
    _ = @import("instr.zig");
    _ = @import("load_elf.zig");
    _ = @import("bit_manip.zig");
}
