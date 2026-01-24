const std = @import("std");
const File = std.fs.File;

const Cpu = @import("../Cpu.zig");
const Instr = @import("../instr.zig").Instr;
const Machine = @import("../Machine.zig");
const disasm = @import("../disasm.zig");
const loadElfFromPath = @import("../load_elf.zig").loadElfFromPath;
const EmulatedTerminal = @import("Terminal.zig");

const disasm_width = 64;
const cpu_state_width = 32;

const tui = @import("zigtui");
const Terminal = tui.terminal.Terminal;
const Buffer = tui.render.Buffer;
const Rect = tui.render.Rect;
const Color = tui.style.Color;
const Style = tui.style.Style;
const Modifier = tui.style.Modifier;
const Block = tui.widgets.Block;
const Borders = tui.widgets.Borders;
const Theme = tui.Theme;
const themes = tui.themes;

pub const Ctx = struct {
    gpa: std.mem.Allocator,

    theme: Theme,
    disasm_window_width: u16,
    cpu_state_window_width: u16,

    should_exit: bool,
    elf_file_name: ?[]const u8,
    command_buf: std.ArrayList(u8),

    emulated_terminal:EmulatedTerminal,

    machine: Machine,

};

fn handleKeyEvent(ctx: *Ctx, key: tui.events.KeyEvent) !void {
    switch (key.code) {
        .char => |ch| {
            if (ctx.command_buf.items.len == 0 and ch == 's') {
                ctx.machine.step();
            } else if (ch <= 0x7f) {
                try ctx.command_buf.append(ctx.gpa, @intCast(ch));
            }
        },

        .enter => {
            try @import("command.zig").do(ctx);
            ctx.command_buf.items.len = 0;
        },

        .backspace => ctx.command_buf.items.len -|= 1,

        else => {},
    }
}

const ArgIter = struct {
    iter: std.mem.SplitIterator(u8, .scalar),

    fn next(args: *@This()) ?[]const u8 {
        while (args.iter.next()) |arg| {
            if (arg.len != 0) return arg;
        }
        return null;
    }
};

pub fn run(elf_file: ?[]const u8) !void {
    var gpa_inst = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_inst.deinit();
    const gpa = gpa_inst.allocator();

    var backend = try tui.backend.init(gpa);
    defer backend.deinit();

    var terminal = try tui.terminal.Terminal.init(gpa, backend.interface());
    defer terminal.deinit();

    try terminal.hideCursor();
    defer terminal.showCursor() catch {};

    var ctx = Ctx{
        .gpa = gpa,

        .theme = tui.themes.tokyo_night,
        .disasm_window_width = 48,
        .cpu_state_window_width = 30,

        .emulated_terminal = try .init(0, 0, gpa),

        .should_exit = false,
        .elf_file_name = null,
        .command_buf = .empty,

        .machine = try Machine.init(gpa, 124),
    };
    ctx.machine.output_to_tui_terminal = true;


    defer ctx.machine.deinit(ctx.gpa);
    defer ctx.command_buf.deinit(ctx.gpa);
    defer ctx.emulated_terminal.deinit();
    defer if (ctx.elf_file_name) |mem| ctx.gpa.free(mem);


    if (elf_file) |path| {
        const alloc = try gpa.alloc(u8, path.len);
        @memcpy(alloc, path);
        ctx.elf_file_name = alloc;
        try loadElfFromPath(ctx.elf_file_name.?, &ctx.machine);
    }

    while (!ctx.should_exit) {
        const event = try backend.interface().pollEvent(100);
        switch (event) {
            .key => |key| try handleKeyEvent(&ctx, key),
            .resize => |size| try terminal.resize(.{.height = size.height, .width = size.width}),
            else => {},
        }

        try terminal.draw(&ctx, @import("render.zig").render);
    }
}
