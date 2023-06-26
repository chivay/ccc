const std = @import("std");

pub const Keyword = enum {
    auto,
    @"break",
    case,
    char,
    @"const",
    @"continue",
    default,
    do,
    double,
    @"else",
    @"enum",
    @"extern",
    float,
    @"for",
    goto,
    @"if",
    @"inline",
    int,
    long,
    register,
    restrict,
    @"return",
    short,
    signed,
    sizeof,
    static,
    @"struct",
    @"switch",
    typedef,
    @"union",
    unsigned,
    void,
    @"volatile",
    @"while",
};

pub const Tokenizer = struct {
    const Self = @This();

    const Type = enum {
        keyword,
        identifier,
        constant,
        string_literal,
        lparen,
        rparen,
        lbrace,
        rbrace,
        lbracket,
        rbracket,
        semicolon,
        minus,
        plus,
        divide,
        asterisk,
        ampersand,
    };

    const TokenData = union(Type) {
        keyword: Keyword,
        identifier: void,
        constant: void,
        string_literal: void,
        lparen: void,
        rparen: void,
        lbrace: void,
        rbrace: void,
        lbracket: void,
        rbracket: void,
        semicolon: void,
        minus: void,
        plus: void,
        divide: void,
        asterisk: void,
        ampersand: void,
    };
    const Token = struct {
        start_pos: usize,
        end_pos: usize,
        data: TokenData,

        pub fn length(self: *const @This()) usize {
            return self.end_pos - self.start_pos;
        }
    };

    const TokenIterator = struct {
        alloc: std.mem.Allocator,
        data: []const u8,
        pos: usize,

        fn isWhitespace(c: u8) bool {
            return c == ' ' or c == '\t' or c == '\n';
        }

        fn nextNonWhite(self: *@This()) ?usize {
            var pos: usize = self.pos;
            while (isWhitespace(self.data[pos])) {
                if (pos + 1 >= self.data.len) return null;
                pos += 1;
            }
            self.pos = pos;
            return pos;
        }

        fn isDigit(c: u8) bool {
            return c >= '0' and c <= '9';
        }
        fn isLetter(c: u8) bool {
            return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
        }

        fn matchIdentifier(self: *@This()) ?Token {
            var len: usize = 0;
            var fst_char = self.data[self.pos];

            if (!isLetter(fst_char) and fst_char != '_') {
                return null;
            }

            len += 1;

            for (self.data[self.pos + 1 ..]) |c| {
                if (!(isLetter(c) or isDigit(c) or c == '_')) {
                    break;
                }
                len += 1;
            }
            return .{
                .data = .{
                    .identifier = {},
                },
                .start_pos = self.pos,
                .end_pos = self.pos + len,
            };
        }

        fn matchKeyword(self: *@This()) ?Token {
            inline for (@typeInfo(Keyword).Enum.fields) |field| {
                if (std.mem.startsWith(u8, self.data[self.pos..], field.name)) {
                    return .{
                        .data = .{ .keyword = @field(Keyword, field.name) },
                        .start_pos = self.pos,
                        .end_pos = self.pos + field.name.len,
                    };
                }
            }
            return null;
        }

        fn oneCharToken(self: *@This(), comptime typ: Type) Token {
            return .{
                .data = @unionInit(TokenData, @tagName(typ), {}),
                .start_pos = self.pos,
                .end_pos = self.pos + 1,
            };
        }

        fn matchMisc(self: *@This()) ?Token {
            var fst_char = self.data[self.pos];
            return switch (fst_char) {
                '{' => self.oneCharToken(.lbrace),
                '}' => self.oneCharToken(.rbrace),
                '(' => self.oneCharToken(.lparen),
                ')' => self.oneCharToken(.rparen),
                '[' => self.oneCharToken(.lbracket),
                ']' => self.oneCharToken(.rbracket),
                ';' => self.oneCharToken(.semicolon),
                '-' => self.oneCharToken(.minus),
                '+' => self.oneCharToken(.plus),
                '/' => self.oneCharToken(.divide),
                '*' => self.oneCharToken(.asterisk),
                else => null,
            };
        }

        fn matchConstant(self: *@This()) ?Token {
            var len: usize = 0;
            var fst_char = self.data[self.pos];
            if (fst_char == '0') {
                // TODO
                unreachable;
            }
            else if (isDigit(fst_char)) {
                // is digit but nonzero
                len = 1;
                for (self.data[self.pos + 1 ..]) |c| {
                    if (!isDigit(c)) {
                        break;
                    }
                    len += 1;
                }
                return .{ .data = . {.constant = {}}, .start_pos = self.pos, .end_pos = self.pos + len };
            }
            return null;
        }

        pub fn next(self: *@This()) ?Token {
            _ = self.nextNonWhite() orelse return null;

            const mb_keyword = self.matchKeyword();
            const mb_identifier = self.matchIdentifier();
            const mb_misc = self.matchMisc();
            const mb_constant = self.matchConstant();

            // order is important, keyword can be parsed as identifier too
            const results = [_]?Token{
                mb_keyword,
                mb_identifier,
                mb_misc,
                mb_constant,
            };

            var best: ?Token = null;
            for (results) |r| {
                if (r == null) continue;

                if (best == null or r.?.length() > best.?.length()) {
                    best = r;
                }
            }

            if (best) |b| {
                self.pos += b.length();
            }

            return best;
        }
    };

    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) Self {
        return .{ .alloc = alloc };
    }

    pub fn tokenize(self: *Self, data: []const u8) TokenIterator {
        return .{
            .alloc = self.alloc,
            .data = data,
            .pos = 0,
        };
    }
};

pub fn main() !void {
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (alloc.deinit() != .ok) {
        std.debug.print("Some memory leaked\n", .{});
    };
    std.debug.print("ccc - chivay's C compiler v0.1\n", .{});

    var arg_iterator = try std.process.argsWithAllocator(alloc.allocator());
    defer arg_iterator.deinit();
    _ = arg_iterator.skip();

    while (arg_iterator.next()) |filename| {
        std.debug.print("Processing - {s}\n", .{filename});
        const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
        var reader = file.reader();
        const input = try reader.readAllAlloc(alloc.allocator(), 1024 * 1024 * 1);
        defer alloc.allocator().free(input);

        var tokenizer = Tokenizer.init(alloc.allocator());
        var token_it = tokenizer.tokenize(input);

        while (token_it.next()) |token| {
            std.debug.print("{s} - {s}\n", .{@tagName(token.data), input[token.start_pos..token.end_pos]});
        }
        std.debug.print("\n", .{});

        defer file.close();
    }
}

comptime {
    @export(cMain, .{ .name = "main", .linkage = .Strong });
}
export fn cMain () void {
}
