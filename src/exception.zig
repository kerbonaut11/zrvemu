const std = @import("std");
const Cpu = @import("Cpu.zig");

pub const Exception = error {
    SupervisorSoftwareInterrupt,
    MachineSoftwareInterrupt,

    SupervisorTimerInterrupt,
    MachineTimerInterrupt,

    SupervisorExternalInterrupt,
    MachineExternalInterrupt,

    CounterOverflowInterrupt,

    InstructionAddressMisaligned,
    InstructionAccessFault,
    IllegalInstruction,

    BreakPoint,

    LoadAddressMisaligned,
    LoadAccessFault,
    StoreAddressMisaligned,
    StoreAccessFault,

    ECallFromUMode,
    ECallFromSMode,
    ECallFromMMode,

    InstructionPageFault,
    LoadPageFault,
    StorePageFault,

    DoubleTrap,
    SoftwareCheck,
    HardwareError,
};

pub fn loadToInstrFault(exc: Exception) Exception {
    return switch (exc) {
        error.LoadAccessFault => error.InstructionAccessFault,
        error.LoadAddressMisaligned => error.LoadAddressMisaligned,
        else => exc,
    };
}

pub fn isInterrupt(exc: Exception) bool {
    return switch (exc) {
        error.SupervisorSoftwareInterrupt,
        error.MachineSoftwareInterrupt,
        error.SupervisorTimerInterrupt,
        error.MachineTimerInterrupt,
        error.SupervisorExternalInterrupt,
        error.MachineExternalInterrupt,
        error.CounterOverflowInterrupt => true,

        else => false,
    };
}

pub fn code(exc: Exception) u32 {
    return switch (exc) {
        error.SupervisorSoftwareInterrupt => 1,
        error.MachineSoftwareInterrupt => 3,

        error.SupervisorTimerInterrupt => 5,
        error.MachineTimerInterrupt => 7,

        error.SupervisorExternalInterrupt => 9,
        error.MachineExternalInterrupt => 11,

        error.CounterOverflowInterrupt => 13,

        error.InstructionAddressMisaligned => 0,
        error.InstructionAccessFault => 1,
        error.IllegalInstruction => 2,

        error.BreakPoint => 3,

        error.LoadAddressMisaligned => 4,
        error.LoadAccessFault => 5,
        error.StoreAddressMisaligned => 6,
        error.StoreAccessFault => 7,

        error.ECallFromUMode => 8,
        error.ECallFromSMode => 9,
        error.ECallFromMMode => 11,

        error.InstructionPageFault => 12,
        error.LoadPageFault => 13,
        error.StorePageFault => 15,

        error.DoubleTrap => 16,
        error.SoftwareCheck => 18,
        error.HardwareError => 19,
    };
}

pub fn mtval(cpu: *Cpu, exc: Exception) u32 {
    return switch (exc) {
        error.LoadAccessFault,
        error.LoadAddressMisaligned,
        error.LoadPageFault,
        error.StoreAccessFault,
        error.StoreAddressMisaligned,
        error.StorePageFault => cpu.last_read_addres,

        error.InstructionAccessFault,
        error.InstructionAddressMisaligned,
        error.InstructionPageFault,
        error.BreakPoint => cpu.pc,

        error.ECallFromUMode,
        error.ECallFromSMode,
        error.ECallFromMMode,
        error.IllegalInstruction => 0,
        else => std.debug.panic("todo {}\n", .{exc}),
    };
}


pub fn take(cpu: *Cpu, exception: Exception) void {
    const medeleg = (@as(u64, cpu.csr(.medelegh).*) << 32) | cpu.csrs.get(.medeleg).*;
    const mideleg: u64 = cpu.csr(.mideleg).*;
    const deleg = if (isInterrupt(exception)) mideleg else medeleg;

    if (cpu.mode != .machine and (deleg >> @intCast(code(exception))) & 1 == 1) {
        @panic("todo supervisor interrupt");
    } else {
        takeMachine(cpu, exception);
    }
}

pub fn takeMachine(cpu: *Cpu, exception: Exception) void {
    cpu.csr(.mepc).* = cpu.pc & ~@as(u32, 1);
    cpu.csr(.mcause).* = @as(u32, @intFromBool(isInterrupt(exception))) << 31 | code(exception);
    cpu.csr(.mtval).* = mtval(cpu, exception);

    const mtvec = cpu.csrs.mtvec();
    cpu.pc = switch (mtvec.mode) {
        .direct => @as(u32, mtvec.addr) << 2,
        .vectored => @panic("todo"),
        _ => @panic("illegal mtvec"),
    };

    
    const mstatus = cpu.csrs.mstatus();
    mstatus.mpie = mstatus.mie;
    mstatus.mie = false;
    mstatus.mpp = cpu.mode;
    cpu.mode = .machine;
}
