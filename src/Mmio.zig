const Machine = @import("Machine.zig");

pub const WriteCallBack = fn(*Machine, u32) void;
pub const LoadCallBack = fn(*Machine) u32;
