const std = @import("std");
const Complex = struct {
    re: f64,
    im: f64,

    pub fn toString(self: Complex, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.imag) {
            0 => std.fmt.allocPrint(allocator, "{d}", .{self.re}),
            else => if (self.imag < 0)
                std.fmt.allocPrint(allocator, "{d} - {d}i", .{ self.re, -self.im })
            else
                std.fmt.allocPrint(allocator, "{d} + {d}i", .{ self.re, self.im }),
        };
    }
    pub fn add(a: Complex, b: Complex) Complex {
        return Complex{ .re = (a.re + b.re), .im = (a.im + b.im) };
    }
    pub fn substract(a: Complex, b: Complex) Complex {
        return Complex{ .re = (a.re - b.re), .im = (a.im - b.im) };
    }
    pub fn multiply(a: Complex, b: Complex) Complex {
        return Complex{ .re = (a.re * b.re - a.im * b.im), .im = (a.im * b.re + b.im * a.re) };
    }
    pub fn divide(a: Complex, b: Complex) !Complex {
        const denominator = (b.re * b.re) + (b.im * b.im);
        if (denominator == 0) return error.DivisionByZero;
        return Complex{
            .re = (a.re * b.re + a.im * b.im) / denominator,
            .im = (a.im * b.re - a.re * b.im) / denominator,
        };
    }
    pub fn ln(a: Complex, b: Complex) Complex {
        return Complex{ .re = std.math.log(f64, std.math.e, std.math.sqrt(a ^ 2 + b ^ 2)), .im = std.math.atan2(b, a) };
    }
    pub fn exp(a: Complex, b: Complex) Complex {
        const m = std.math.pow(f64, std.math.e, a);
        return Complex{ .re = m * std.math.cos(b), .im = m * std.math.sin(b) };
    }
    pub fn sin(a: Complex, b: Complex) Complex {
        return Complex{ .re = std.math.sin(a) * std.math.cosh(b), .im = std.math.cos(a) * std.math.sinh(b) };
    }
};

const ExprToken = enum { Number, Variable, Operator, Function, LeftParen, RightParen };

pub const Token = struct { kind: ExprToken, text: []const u8, isComplex: ?bool };

pub fn tokenize(expr: []const u8, allocator: *std.mem.Allocator) ![]Token {
    var tokens = std.ArrayList(Token).init(allocator.*);
    var i: usize = 0;

    while (i < expr.len) : (i += 1) {
        const c = expr[i];

        if (c == ' ' or c == '\t' or c == 'i') continue;

        if ((c >= '0' and c <= '9')) {
            const start = i;
            while (i + 1 < expr.len and ((expr[i + 1] >= '0' and expr[i + 1] <= '9') or expr[i + 1] == '.')) : (i += 1) {}
            if (expr[i + 1] == 'i') {
                try tokens.append(Token{ .kind = .Number, .text = expr[start .. i + 1], .isComplex = true });
                continue;
            }
            try tokens.append(Token{ .kind = .Number, .text = expr[start .. i + 1], .isComplex = false });
            continue;
        }

        if (c == 'x') {
            try tokens.append(Token{ .kind = .Variable, .text = "x", .isComplex = null });
            continue;
        }

        if (c == '(') {
            try tokens.append(Token{ .kind = .LeftParen, .text = "(", .isComplex = null });
            continue;
        }
        if (c == ')') {
            try tokens.append(Token{ .kind = .RightParen, .text = ")", .isComplex = null });
            continue;
        }

        if (i + 2 < expr.len) {
            const func = expr[i .. i + 3];
            if (std.mem.eql(u8, func, "sin") or std.mem.eql(u8, func, "cos")) {
                try tokens.append(Token{ .kind = .Function, .text = func, .isComplex = null });
                i += 2;
                continue;
            }
        }

        if (c == '+' or c == '-' or c == '*' or c == '/' or c == '^') {
            try tokens.append(Token{ .kind = .Operator, .text = expr[i .. i + 1], .isComplex = null });
            continue;
        }

        return error.InvalidCharacter;
    }

    return tokens.toOwnedSlice();
}

fn precedence(op: []const u8) u8 {
    if (std.mem.eql(u8, op, "^")) return 4;
    if (std.mem.eql(u8, op, "*") or std.mem.eql(u8, op, "/")) return 3;
    if (std.mem.eql(u8, op, "+") or std.mem.eql(u8, op, "-")) return 2;
    return 0;
}

fn isRightAssociative(op: []const u8) bool {
    return std.mem.eql(u8, op, "^");
}

pub fn toRPN(tokens: []const Token, allocator: *std.mem.Allocator) ![]Token {
    var output = std.ArrayList(Token).init(allocator.*);
    var stack = std.ArrayList(Token).init(allocator.*);

    for (tokens) |t| {
        switch (t.kind) {
            .Number, .Variable => try output.append(t),

            .Function => try stack.append(t),

            .Operator => {
                while (stack.items.len > 0) {
                    const top = stack.items[stack.items.len - 1];
                    if (top.kind == .Operator and
                        ((precedence(top.text) > precedence(t.text)) or
                            (precedence(top.text) == precedence(t.text) and !isRightAssociative(t.text))))
                    {
                        const popped = stack.pop().?;
                        try output.append(popped);
                    } else {
                        break;
                    }
                }
                try stack.append(t);
            },

            .LeftParen => try stack.append(t),
            .RightParen => {
                while (stack.items.len > 0 and stack.items[stack.items.len - 1].kind != .LeftParen) {
                    try output.append(stack.pop().?);
                }
                if (stack.items.len == 0) return error.MismatchedParentheses;
                _ = stack.pop();
                if (stack.items.len > 0 and stack.items[stack.items.len - 1].kind == .Function) {
                    try output.append(stack.pop().?);
                }
            },
        }
    }

    while (stack.items.len > 0) {
        const top = stack.pop().?;
        if (top.kind == .LeftParen or top.kind == .RightParen) {
            return error.MismatchedParentheses;
        }
        try output.append(top);
    }

    return output.toOwnedSlice();
}

pub fn evalRPN(rpn: []const Token, x_val: f64) !Complex {
    var stack: [128]Complex = undefined;
    var sp: usize = 0;

    for (rpn) |t| {
        switch (t.kind) {
            .Number => {
                if (t.isComplex == true) {
                    const val = std.fmt.parseFloat(f64, t.text) catch 0.0;
                    stack[sp] = Complex{ .re = 0, .im = val };
                } else {
                    const val = std.fmt.parseFloat(f64, t.text) catch 0.0;
                    stack[sp] = Complex{ .re = val, .im = 0 };
                }
                sp += 1;
            },
            .Variable => {
                stack[sp] = Complex{ .re = x_val, .im = 0 };
                sp += 1;
            },
            .Operator => {
                const b = stack[sp - 1];
                sp -= 1;
                const a = stack[sp - 1];
                sp -= 1;

                var res: Complex = Complex{ .re = 0, .im = 0 };

                if (std.mem.eql(u8, t.text, "+")) res = Complex.add(a, b);
                if (std.mem.eql(u8, t.text, "-")) res = Complex.substract(a, b);
                if (std.mem.eql(u8, t.text, "*")) res = Complex.multiply(a, b);
                if (std.mem.eql(u8, t.text, "/")) res = try Complex.divide(a, b);
                // if (std.mem.eql(u8, t.text, "^")) res = std.math.pow(f64, a, b);
                stack[sp] = res;
                sp += 1;
            },
            // .Function => {
            //     const arg = stack[sp - 1];
            //     sp -= 1;
            //     var res: f64 = 0;
            //     if (std.mem.eql(u8, t.text, "sin")) res = std.math.sin(arg);
            //     if (std.mem.eql(u8, t.text, "cos")) res = std.math.cos(arg);
            //     stack[sp] = res;
            //     sp += 1;
            // },
            // .Imaginary => {
            //     if (sp > 0) {
            //         const last = stack[sp - 1];
            //         stack[sp - 1] = Complex{ .re = 0, .im = last.re };
            //     } else {
            //         stack[sp] = Complex{ .re = 0, .im = 1 };
            //         sp += 1;
            //     }
            // },
            else => {},
        }
        std.debug.print("\n{any}", .{stack[sp]});
    }

    return stack[0];
}

const Sequence = struct {
    formula: []const u8,

    pub fn firstNumbers() ![]const f64 {}
    // pub fn extractNumber(self: Sequence) Complex {
    //     var form: ?[]f64 = null;
    //     for (self.formula, 0..) |char, i| {
    //         var x: ?f64 = null;
    //         _ = char;
    //         _ = i;

    //     }
    // }
};

pub fn sum() f64 {
    return (23);
}
