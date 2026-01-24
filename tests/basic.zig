pub export fn main() callconv(.naked) noreturn {
    while (true) {
        const ptr: *volatile u8 = @ptrFromInt(4);
        ptr.* +%= 1;
    }
}
