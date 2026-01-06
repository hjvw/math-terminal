const std = @import("std");
pub const Complex = struct {
    re: f64,
    im: f64,
    pub fn parseComplex(input_raw: []const u8) !Complex {
        const input = std.mem.trim(u8, input_raw, " \t\n\r");

        var real: f64 = 0;
        var imag: f64 = 0;

        if (std.mem.indexOfScalar(u8, input, 'i')) |i_pos| {
            const before_i = input[0..i_pos];

            if (std.mem.lastIndexOfAny(u8, before_i, "+-")) |sign_pos| {
                if (sign_pos > 0) {
                    real = try std.fmt.parseFloat(f64, before_i[0..sign_pos]);
                }

                const imag_part = before_i[sign_pos..];
                if (imag_part.len == 1) {
                    imag = if (imag_part[0] == '+') 1.0 else -1.0;
                } else {
                    imag = try std.fmt.parseFloat(f64, imag_part);
                }
            } else {
                if (before_i.len == 0) {
                    imag = 1.0;
                } else {
                    imag = try std.fmt.parseFloat(f64, before_i);
                }
            }
        } else {
            real = try std.fmt.parseFloat(f64, input);
        }

        return Complex{ .re = real, .im = imag };
    }

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
    // pub fn ln(a: Complex) Complex {
    //     return Complex{ .re = std.math.log(f64, std.math.e, std.math.sqrt(.re= std.math.pow(f64, a.re, 2)a.re ^ 2 + a.im ^ 2)), .im = std.math.atan2(a.im, a.re) };
    // }
    // pub fn exp(a: Complex) Complex {
    //     const m = std.math.pow(f64, std.math.e, a);
    //     return Complex{ .re = m * std.math.cos(a.im), .im = m * std.math.sin(a.im) };
    // }
    pub fn sin(a: Complex) Complex {
        return Complex{ .re = std.math.sin(a.re) * std.math.cosh(a.im), .im = std.math.cos(a.re) * std.math.sinh(a.im) };
    }
    pub fn cos(a: Complex) Complex {
        return Complex{ .re = std.math.cos(a.re) * std.math.cosh(a.im), .im = -1 * std.math.sin(a.re) * std.math.sinh(a.im) };
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
            if (i + 1 < expr.len and expr[i + 1] == 'i') {
                try tokens.append(Token{
                    .kind = .Number,
                    .text = expr[start .. i + 1],
                    .isComplex = true,
                });
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
                            (precedence(top.text) == precedence(t.text) and !std.mem.eql(u8, t.text, "^"))))
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

pub fn evalRPN(rpn: []const Token, x_val: Complex) !Complex {
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
                stack[sp] = x_val;
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
            .Function => {
                const arg = stack[sp - 1];
                sp -= 1;
                var res: Complex = Complex{ .re = 0, .im = 0 };
                if (std.mem.eql(u8, t.text, "sin")) res = Complex.sin(arg);
                if (std.mem.eql(u8, t.text, "cos")) res = Complex.cos(arg);
                // if (std.mem.eql(u8, t.text, "ln")) res = Complex.ln(arg);
                // if (std.mem.eql(u8, t.text, "exp")) res = Complex.exp(arg);

                stack[sp] = res;
                sp += 1;
            },

            else => {},
        }
        // std.debug.print("\n{any}", .{stack[sp]});
    }

    return stack[0];
}

const Sequence = struct {
    formula: []const u8,

    pub fn sum(self: Sequence, first: i64, last: i64) !Complex {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const alloc = arena.allocator();

        const tokens = try tokenize(self.formula, alloc);
        const rpn = try toRPN(tokens, alloc);

        var s = Complex.zero();
        for (first..last) |i| {
            s = Complex.add(s, try evalRPN(rpn, i));
        }
        return s;
    }
};

const FunctionPoint = struct {
    formula: []const u8,
    x: Complex,
    y: Complex,

    pub fn init(
        allocator: std.mem.Allocator,
        formula: []const u8,
        x: Complex,
    ) !FunctionPoint {
        const tokens = try tokenize(formula, allocator);
        defer allocator.free(tokens);

        const rpn = try toRPN(tokens, allocator);
        defer allocator.free(rpn);

        const y = try evalRPN(rpn, x);

        return FunctionPoint{
            .formula = formula,
            .x = x,
            .y = y,
        };
    }
};
