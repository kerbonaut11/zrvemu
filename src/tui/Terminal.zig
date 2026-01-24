const std = @import("std");
const Ctx = @import("app.zig").Ctx;

const Terminal = @This();

gpa: std.mem.Allocator,
width: u16,
height: u16,
lines: std.ArrayList([]u8),
colum: u16,

pub fn init(width: u16, height: u16, gpa: std.mem.Allocator) !Terminal {
    return .{
        .gpa = gpa,
        .width = width,
        .height = height,
        .lines = .empty,
        .colum = width,
    };
}

pub fn deinit(tty: *Terminal) void {
    for (tty.lines.items) |line| tty.gpa.free(line);
    tty.lines.deinit(tty.gpa);
}


pub fn write(tty: *Terminal, ch: u8) !void {
    if (ch == '\n') {
        try tty.nextLine();
    } else {
        if (tty.colum == tty.width) try tty.nextLine();

        tty.lines.getLast()[tty.colum] = ch;
        tty.colum += 1;
    }
}

fn nextLine(tty: *Terminal) !void {
    const line = try tty.gpa.alloc(u8, tty.width);
    @memset(line, '\n');
    try tty.lines.append(tty.gpa, line);
    tty.colum = 0;
}
