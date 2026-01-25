pub const Exception = error {
    InstructionAddressMisaligned,
    InstructionAccessFault,
    IllegalInstruction,

    LoadAddressMisaligned,
    LoadAccessFault,

    ECallFromUMode,
    ECallFromSMode,
    ECallFromMMode,
    BreakPoint,
};

pub fn loadToInstrFault(err: Exception) Exception {
    return switch (err) {
        error.LoadAccessFault => error.InstructionAccessFault,
        error.LoadAddressMisaligned => error.LoadAddressMisaligned,
        else => err,
    };
}

