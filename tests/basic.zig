const std = @import("std");

const debug_out: *volatile u8 = @ptrFromInt(0x10);

var debug_writer = std.io.Writer{
    .buffer = &.{},
    .end = 0,
    .vtable = &.{
        .drain = debugWriterDrain,
    },
};

fn debugWriterDrain(_: *std.io.Writer, data: []const []const u8, splat: usize) std.io.Writer.Error!usize {
    var total_bytes: usize = 0;
    for (data[0..data.len-1]) |bytes| {
        total_bytes += data.len;
        for (bytes) |byte| debug_out.* = byte;
    }


    const splat_data = data[data.len-1];
    total_bytes += splat_data.len*splat;
    for (0..splat) |_| {
        for (splat_data) |byte| debug_out.* = byte;
    }

    return total_bytes;
}

pub export fn main() callconv(.c) noreturn {
    debug_writer.print("Hello, World!", .{}) catch {};

    while (true) {}
}
