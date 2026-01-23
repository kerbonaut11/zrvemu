const std = @import("std");
const File = std.fs.File;

const Cpu = @import("Cpu.zig");
const Instr = @import("instr.zig").Instr;
const Machine = @import("Machine.zig");
const disasm = @import("disasm.zig");

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

const Ctx = struct {
    theme: Theme,
    disasm_window_width: u16,
    cpu_state_window_width: u16,

    machine: Machine,
};

fn render(ctx: *Ctx, buf: *tui.render.Buffer) !void {
    const area = buf.getArea();
    buf.fillArea(area, ' ', ctx.theme.baseStyle());

    const main_block = Block{
        .title = " RISCV-32 Emulator ",
        .borders = .all(),
        .border_symbols = .rounded(),
        .border_style = ctx.theme.borderFocusedStyle(),
    };
    main_block.render(area, buf);

    const inner = main_block.inner(buf.getArea());
    const split1 = inner.splitHorizontal(inner.width-ctx.disasm_window_width);
    const split2 = split1.left.splitHorizontal(split1.left.width-ctx.cpu_state_window_width);

    try renderDisasm(ctx, buf, split1.right);
    try renderCpuState(ctx, buf, split2.right);
}

fn renderDisasm(ctx: *Ctx, buf: *tui.render.Buffer, area: Rect) !void {
    const block = Block{
        .title = " Code ",
        .borders = .all(),
        .border_symbols = .rounded(),
        .border_style = ctx.theme.borderFocusedStyle(),
    };
    block.render(area, buf);

    const inner = block.inner(area);

    const pc = ctx.machine.cpu.regs[Cpu.pc];
    var addr = pc -% inner.height/2*@sizeOf(Instr);

    for (0..inner.height) |colum| {
        if (!(addr +| @sizeOf(Instr) > ctx.machine.ram.len)) {
            const instr = ctx.machine.load(Instr, addr);

            var buffer: [64]u8 = undefined;
            @memset(&buffer, ' ');

            var writer = std.io.Writer.fixed(&buffer);
            try disasm.printWithAddr(instr, addr, &writer);

            var style = ctx.theme.textStyle();
            if (pc == addr) style.bg = ctx.theme.highlight;

            buf.setString(inner.x, inner.y+@as(u16, @intCast(colum)), buffer[0..inner.width], style);
        }

        addr +%= @sizeOf(Instr);
    }
}

fn renderCpuState(ctx: *Ctx, buf: *tui.render.Buffer, area: Rect) !void {
    const block = Block{
        .title = " CPU ",
        .borders = .all(),
        .border_symbols = .rounded(),
        .border_style = ctx.theme.borderFocusedStyle(),
    };
    block.render(area, buf);

    const inner = block.inner(area);
    if (inner.height < 31) return;

    for (0..31) |colum| {
        const reg = colum+1;
        var buffer: [64]u8 = undefined;
        const fmt = try std.fmt.bufPrint(
            &buffer,
            "{0s: <3} {1d: >12} 0x{1x:08}",
            .{disasm.reg_names[reg], ctx.machine.cpu.regs[reg]}
        );
        
        buf.setString(inner.x, inner.y+@as(u16, @intCast(colum)), fmt, ctx.theme.baseStyle());
    }
}

pub fn main(elf_file: ?[]const u8) !void {
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
        .theme = tui.themes.tokyo_night,
        .machine = try Machine.init(gpa, 124),
        .disasm_window_width = 48,
        .cpu_state_window_width = 30,
    };
    defer ctx.machine.deinit();

    if (elf_file) |path| {
        try @import("load_elf.zig").loadElfFromPath(path, &ctx.machine);
    }

    var running = true;
    while (running) {
        const event = try backend.interface().pollEvent(100);
        if (event == .key) {
            if (event.key.code == .esc or (event.key.code == .char and event.key.code.char == 'q'))
                running = false;

            if (event.key.code.char == 's') {
                ctx.machine.step();
            }
        }

        try terminal.draw(&ctx, render);
    }
}

