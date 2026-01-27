const std = @import("std");

const Ctx = @import("app.zig").Ctx;
const Instr = @import("../instr.zig").Instr;
const Machine = @import("../Machine.zig");
const disasm = @import("../disasm.zig");
const EmulatedTerminal = @import("Terminal.zig");

const tui = @import("zigtui");
const Buffer = tui.render.Buffer;
const Rect = tui.render.Rect;
const Color = tui.style.Color;
const Style = tui.style.Style;
const Modifier = tui.style.Modifier;
const Block = tui.widgets.Block;
const Borders = tui.widgets.Borders;
const Theme = tui.Theme;
const themes = tui.themes;

pub const disasm_window_width = 48;
pub const cpu_state_window_width = 30;

pub fn render(ctx: *Ctx, buf: *Buffer) !void {
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
    const split1 = inner.splitHorizontal(inner.width-disasm_window_width);
    const split2 = split1.left.splitHorizontal(split1.left.width-cpu_state_window_width);

    try renderDisasm(ctx, buf, split1.right);
    try renderCpuState(ctx, buf, split2.right);
    try renderEmulatedTerminal(ctx, buf, split2.left);

    var command_bar_area = area;
    command_bar_area.y += inner.height+1;
    command_bar_area.x += 2;
    command_bar_area.width -= 4;
    try renderCommandBar(ctx, buf, command_bar_area);
}

fn renderDisasm(ctx: *Ctx, buf: *Buffer, area: Rect) !void {
    const block = Block{
        .title = " Code ",
        .borders = .all(),
        .border_symbols = .rounded(),
        .border_style = ctx.theme.borderFocusedStyle(),
    };
    block.render(area, buf);

    const inner = block.inner(area);

    const pc = ctx.machine.cpu.pc;
    var addr = pc -% inner.height/2*@sizeOf(Instr);

    for (0..inner.height) |row| {
        if (ctx.machine.load(Instr, addr) catch null) |instr| {
            var buffer: [128]u8 = undefined;
            const fmt = try std.fmt.bufPrint(&buffer, "{f}", .{disasm{.addr = addr, .instr = instr}});

            var style = ctx.theme.textStyle();
            if (pc == addr) style.bg = ctx.theme.highlight;

            buf.setStringTruncated(inner.x, inner.y+@as(u16, @intCast(row)), fmt, inner.width,style);
        }

        addr +%= @sizeOf(Instr);
    }
}

fn renderCpuState(ctx: *Ctx, buf: *Buffer, area: Rect) !void {
    const block = Block{
        .title = " CPU ",
        .borders = .all(),
        .border_symbols = .rounded(),
        .border_style = ctx.theme.borderFocusedStyle(),
    };
    block.render(area, buf);

    const inner = block.inner(area);
    if (inner.height < 31) return;

    var buffer: [64]u8 = undefined;

    for (0..31) |row| {
        const reg = row+1;
        const fmt = try std.fmt.bufPrint(&buffer, "{0s: <3} {1d: >12} 0x{1x:08}", .{disasm.xreg_names[reg], ctx.machine.cpu.xregs[reg]});

        buf.setString(inner.x, inner.y+@as(u16, @intCast(row)), fmt, ctx.theme.baseStyle());
    }

    const pc_fmt = try std.fmt.bufPrint(&buffer, "pc               0x{x:08}", .{ctx.machine.cpu.pc});
    buf.setString(inner.x, inner.y+31, pc_fmt, ctx.theme.baseStyle());

    const cycle_fmt = try std.fmt.bufPrint(&buffer, "cycle {d: >21}", .{ctx.machine.cpu.cycle()});
    buf.setString(inner.x, inner.y+32, cycle_fmt, ctx.theme.baseStyle());

    const mode_fmt = try std.fmt.bufPrint(&buffer, "mode {s: >22}", .{@tagName(ctx.machine.cpu.mode)});
    buf.setString(inner.x, inner.y+33, mode_fmt, ctx.theme.baseStyle());
}

fn renderCommandBar(ctx: *Ctx, buf: *Buffer, area: Rect) !void {
    const style = Style{.fg = ctx.theme.background, .bg = ctx.theme.border_focused};
    buf.fillArea(area, ' ', style);
    buf.setString(area.x, area.y, ">", style);
    buf.setString(area.x+2, area.y, ctx.command_buf.items, style);
}

fn renderEmulatedTerminal(ctx: *Ctx, buf: *Buffer, area: Rect) !void {
    const block = Block{
        .title = " Terminal Output ",
        .borders = .all(),
        .border_symbols = .rounded(),
        .border_style = ctx.theme.borderFocusedStyle(),
    };
    block.render(area, buf);

    const inner = block.inner(area);
    const tty = &ctx.emulated_terminal;

    if (tty.width != inner.width or tty.height != inner.height) {
        tty.deinit();
        tty.* = try .init(inner.width, inner.height, ctx.gpa);
        return;
    }

    for (tty.lines.items[tty.lines.items.len-|tty.height..], 0..) |line, row| {
        const end_line = std.mem.indexOf(u8, line, "\n") orelse line.len;

        buf.setString(inner.x, inner.y+@as(u16, @intCast(row)), line[0..end_line], ctx.theme.baseStyle());
    }
}


