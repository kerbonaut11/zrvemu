const std = @import("std");

pub fn mask(n: comptime_int) comptime_int {
    return (1 << n)-1;
}

pub fn putBitRange(src: anytype, dest: anytype, hi: comptime_int, lo: comptime_int, dest_idx: comptime_int) @TypeOf(dest) {
    const bits = (src >> lo) & mask(hi-lo+1);
    return dest | (@as(@TypeOf(dest), @intCast(bits)) << dest_idx);
}

fn switchIntSign(comptime T: type) type {
    var int = @typeInfo(T).int;
    int.signedness = if (int.signedness == .signed) .unsinged else .signed;
    return @Type(.{.int = int});
}

pub fn u2i(x: anytype) i32 {
    return @bitCast(x);
}

pub fn i2u(x: i32) u32 {
    return @bitCast(x);
}

pub fn sext(x: anytype) u32 {
    const T = @TypeOf(x);
    const int = @typeInfo(T).int;
    const signed = if (int.signedness == .signed) 
        x
    else
        @as(switchIntSign(T), @bitCast(x));
    return @bitCast(@as(i32, signed));
}

pub fn arithShift(sign_extend: bool, val: u32, shift_amount: u5) u32 {
    var result = val >> shift_amount;
    if (sign_extend) {
        result |= ~(@as(u32, mask(32)) >> shift_amount);
    }
    return result;
}

const testing = std.testing;

test "arithShift" {
    const x: i32 = -32;
    try testing.expectEqual(arithShift(true, @bitCast(x), 2), @as(u32, @bitCast(x/4)));
}

test "sext" {
    try testing.expectEqual(i2u(-1), sext(@as(u4, 0xf)));
}
