const std = @import("std");
const Ctx = @import("app.zig").Ctx;
const Instr = @import("../instr.zig").Instr;
const disasm = @import("../disasm.zig");

const ArgIter = struct {
    iter: std.mem.SplitIterator(u8, .scalar),

    fn next(args: *@This()) ?[]const u8 {
        while (args.iter.next()) |arg| {
            if (arg.len != 0) return arg;
        }
        return null;
    }
};

const CommandCallback = *const fn (*Ctx, *ArgIter) void;
const commands = std.static_string_map.StaticStringMap(CommandCallback).initComptime(.{
    .{"q", exit}, .{"quit", exit},
    .{"ru", runUntil}, .{"rununtil", runUntil},
    .{"", step}, .{"s", step}, .{"step", step},
    .{"ms", manyStep},
    .{"goto", goto},
    .{"setreg", setReg},
});

pub fn do(ctx: *Ctx) !void {
    var args: ArgIter = .{.iter = std.mem.splitScalar(u8, ctx.command_buf.items, ' ')};
    const command = args.next() orelse "";

    if (commands.get(command)) |callback| {
        callback(ctx, &args);
    }
}

fn exit(ctx: *Ctx, args: *ArgIter) void {
    _ = args;
    ctx.should_exit = true;
}

fn runUntil(ctx: *Ctx, args: *ArgIter) void {
    const addr_arg = args.next() orelse return;
    const addr = if (std.mem.eql(u8, addr_arg, "next"))
        ctx.machine.cpu.pc + @sizeOf(Instr)
    else
        std.fmt.parseInt(u32, addr_arg, 16) catch return;

    while (ctx.machine.cpu.pc != addr) {
        ctx.machine.step();
    }
}

fn step(ctx: *Ctx, args: *ArgIter) void {
    _ = args;

    ctx.machine.step();
}

fn manyStep(ctx: *Ctx, args: *ArgIter) void {
    const amount_arg = args.next() orelse return;
    const amount = std.fmt.parseInt(u32, amount_arg, 0) catch return;

    for (0..amount) |_| {
        ctx.machine.step();
    }
}

fn goto(ctx: *Ctx, args: *ArgIter) void {
    const addr_arg = args.next() orelse return;
    const addr = std.fmt.parseInt(u32, addr_arg, 16) catch return;

    ctx.machine.cpu.pc = addr;
}

fn setReg(ctx: *Ctx, args: *ArgIter) void {
    const reg_arg = args.next() orelse return;
    const reg = reg: for (disasm.xreg_names, 0..) |reg_name, i| {
        if (std.mem.eql(u8, reg_name, reg_arg)) break :reg i;
    } else return;

    const val_arg = args.next() orelse return;
    const val = std.fmt.parseInt(u32, val_arg, 0) catch return;

    ctx.machine.cpu.xregs[reg] = val;
}
