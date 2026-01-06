const std = @import("std");
const math_in_terminal = @import("math_in_terminal");
const fnct = @import("functions.zig");
const ifnct = @import("input_functions.zig");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try ifnct.parseInput(args);
}
