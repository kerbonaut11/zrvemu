export var stack: [8*1024*1024]u8 align(0x100) = undefined;

pub export fn main() callconv(.naked) noreturn {
    while (true) {
        const ptr: *volatile u8 = @ptrFromInt(4);
        ptr.* +%= 1;
    }
}
