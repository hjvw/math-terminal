const std = @import("std");
const fnct = @import("functions.zig");
pub fn parseInput(args: [][:0]u8) !void {
    if (args.len < 3) return error.InvalidArguments;
    if (!std.mem.eql(u8, args[1], "f")) return;

    var allocator = std.heap.page_allocator;

    if (std.mem.eql(u8, args[2], "sp")) {
        if (args.len < 5) return error.InvalidArguments;

        const x = try fnct.Complex.parseComplex(args[3]);
        const tokens = try fnct.tokenize(args[4], &allocator);
        defer allocator.free(tokens);

        const rpn = try fnct.toRPN(tokens, &allocator);
        defer allocator.free(rpn);

        const y = try fnct.evalRPN(rpn, x);
        std.debug.print("f({any}) = {any}\n", .{ x, y });
    } else if (std.mem.eql(u8, args[2], "mp")) {
        if (args.len < 6) return error.InvalidArguments;

        const from = try std.fmt.parseInt(i32, args[3], 10);
        const last = try std.fmt.parseInt(i32, args[4], 10);
        const formula = args[5];

        const tokens = try fnct.tokenize(formula, &allocator);
        defer allocator.free(tokens);
        const rpn = try fnct.toRPN(tokens, &allocator);
        defer allocator.free(rpn);

        var i: i32 = from;
        while (i < last) : (i += 1) {
            const x = fnct.Complex{ .re = @floatFromInt(i), .im = 0 };
            const y = try fnct.evalRPN(rpn, x);
            std.debug.print("x={any}, y={any}\n", .{ x, y });
        }
    }
}
