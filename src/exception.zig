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

pub fn loadToInstrFault(err: Exception) Exception {
    return switch (err) {
        error.LoadAccessFault => error.InstructionAccessFault,
        error.LoadAddressMisaligned => error.LoadAddressMisaligned,
        else => err,
    };
}

pub fn isInterrupt(err: Exception) bool {
    return switch (err) {
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

pub fn exceptionCode(err: Exception) u32 {
    return switch (err) {
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
