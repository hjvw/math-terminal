const std = @import("std");
const math_in_terminal = @import("math_in_terminal");
const fnct = @import("functions.zig");
pub fn main() !void {
    var allocator = std.heap.page_allocator;
    const expr = "2i * x + 2 + 3 + 82i";
    const tokens = try fnct.tokenize(expr, &allocator);
    const rpn = try fnct.toRPN(tokens, &allocator);
    for (tokens) |t| {
        std.debug.print(" {s}", .{t.text});
    }
    std.debug.print("\n", .{});
    for (rpn) |t| {
        std.debug.print(" {s}", .{t.text});
    }
    std.debug.print("\n", .{});

    const x_val = 1;
    const result = try fnct.evalRPN(rpn, x_val);

    std.debug.print("f({}) = {}\n", .{ x_val, result });
}
