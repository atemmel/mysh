pub fn next(comptime T: type, ptr: *const T) *const T {
    return @intToPtr(*const T, @ptrToInt(ptr) + @sizeOf(T));
}
