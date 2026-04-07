const std = @import("std");
const utilities = @import("utilities.zig");

pub const Declaration = utilities.Declaration;

pub const Rule = struct {
    selector: []const u8,
    declarations: []const Declaration,
    media_query: ?[]const u8,
};

pub const Emitter = struct {
    buffer: std.ArrayList(u8),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) Emitter {
        return .{
            .buffer = .empty,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Emitter) void {
        self.buffer.deinit(self.alloc);
    }

    pub fn writeLayerOpen(self: *Emitter, name: []const u8) void {
        self.buffer.appendSlice(self.alloc, "@layer ") catch return;
        self.buffer.appendSlice(self.alloc, name) catch return;
        self.buffer.append(self.alloc, '{') catch return;
    }

    pub fn writeRule(self: *Emitter, rule: Rule) void {
        if (rule.media_query) |mq| {
            self.buffer.appendSlice(self.alloc, mq) catch return;
            self.buffer.append(self.alloc, '{') catch return;
        }

        self.buffer.appendSlice(self.alloc, rule.selector) catch return;
        self.buffer.append(self.alloc, '{') catch return;

        for (rule.declarations, 0..) |decl, i| {
            self.buffer.appendSlice(self.alloc, decl.property) catch return;
            self.buffer.append(self.alloc, ':') catch return;
            self.buffer.appendSlice(self.alloc, decl.value) catch return;
            // Add semicolons between declarations, but not after the last one
            if (i < rule.declarations.len - 1) {
                self.buffer.append(self.alloc, ';') catch return;
            }
        }

        self.buffer.append(self.alloc, '}') catch return;

        if (rule.media_query != null) {
            self.buffer.append(self.alloc, '}') catch return;
        }
    }

    pub fn writeLayerClose(self: *Emitter) void {
        self.buffer.append(self.alloc, '}') catch return;
    }

    pub fn toOwnedSlice(self: *Emitter) ![]const u8 {
        return try self.buffer.toOwnedSlice(self.alloc);
    }
};

// ── Tests ────────────────────────────────────────────────────────────────────

test "emit single-declaration rule" {
    var emitter = Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    emitter.writeRule(.{
        .selector = ".flex",
        .declarations = &.{.{ .property = "display", .value = "flex" }},
        .media_query = null,
    });

    const result = try emitter.toOwnedSlice();
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(".flex{display:flex}", result);
}

test "emit multi-declaration rule" {
    var emitter = Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    emitter.writeRule(.{
        .selector = ".antialiased",
        .declarations = &.{
            .{ .property = "-webkit-font-smoothing", .value = "antialiased" },
            .{ .property = "-moz-osx-font-smoothing", .value = "grayscale" },
        },
        .media_query = null,
    });

    const result = try emitter.toOwnedSlice();
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(
        ".antialiased{-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}",
        result,
    );
}

test "emit rule with media query" {
    var emitter = Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    emitter.writeRule(.{
        .selector = ".hover\\:bg-red-500:hover",
        .declarations = &.{.{ .property = "background-color", .value = "var(--color-red-500)" }},
        .media_query = "@media(hover:hover)",
    });

    const result = try emitter.toOwnedSlice();
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(
        "@media(hover:hover){.hover\\:bg-red-500:hover{background-color:var(--color-red-500)}}",
        result,
    );
}

test "emit layer wrapper" {
    var emitter = Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    emitter.writeLayerOpen("utilities");
    emitter.writeRule(.{
        .selector = ".flex",
        .declarations = &.{.{ .property = "display", .value = "flex" }},
        .media_query = null,
    });
    emitter.writeLayerClose();

    const result = try emitter.toOwnedSlice();
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(
        "@layer utilities{.flex{display:flex}}",
        result,
    );
}

test "emit multiple rules" {
    var emitter = Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    emitter.writeLayerOpen("utilities");
    emitter.writeRule(.{
        .selector = ".flex",
        .declarations = &.{.{ .property = "display", .value = "flex" }},
        .media_query = null,
    });
    emitter.writeRule(.{
        .selector = ".hidden",
        .declarations = &.{.{ .property = "display", .value = "none" }},
        .media_query = null,
    });
    emitter.writeLayerClose();

    const result = try emitter.toOwnedSlice();
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(
        "@layer utilities{.flex{display:flex}.hidden{display:none}}",
        result,
    );
}
