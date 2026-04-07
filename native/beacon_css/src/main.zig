const std = @import("std");
const candidate_module = @import("candidate.zig");
const utilities = @import("utilities.zig");
const emitter_module = @import("emitter.zig");
const variants_module = @import("variants.zig");

pub const Candidate = candidate_module.Candidate;
pub const Value = candidate_module.Value;
pub const Declaration = utilities.Declaration;
pub const Emitter = emitter_module.Emitter;
pub const Rule = emitter_module.Rule;

/// Characters that must be escaped in CSS selectors.
/// Covers: `:`, `/`, `[`, `]`, `.`, `#`, `%`, `!`, `(`, `)`, `,`, `'`, `"`
fn needsEscape(ch: u8) bool {
    return switch (ch) {
        ':', '/', '[', ']', '.', '#', '%', '!', '(', ')', ',', '\'', '"', ' ' => true,
        else => false,
    };
}

/// Build a CSS selector from a candidate string.
/// Escapes special characters and applies variant transformations.
fn buildSelector(alloc: std.mem.Allocator, raw_class: []const u8, candidate: Candidate) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(alloc);

    // Start with the `.` class selector prefix
    try buf.append(alloc, '.');

    // Escape the raw class name for use in a CSS selector
    for (raw_class) |ch| {
        if (needsEscape(ch)) {
            try buf.append(alloc, '\\');
        }
        try buf.append(alloc, ch);
    }

    // Apply variant selector suffixes
    for (candidate.variants) |variant_name| {
        if (variants_module.resolve(variant_name)) |variant_result| {
            if (variant_result.selector_suffix) |suffix| {
                try buf.appendSlice(alloc, suffix);
            }
        }
    }

    return try buf.toOwnedSlice(alloc);
}

/// Resolve the media query for a candidate's variants.
/// Returns the outermost media query if any variant specifies one.
fn resolveMediaQuery(candidate: Candidate) ?[]const u8 {
    for (candidate.variants) |variant_name| {
        if (variants_module.resolve(variant_name)) |variant_result| {
            if (variant_result.media_query) |mq| {
                return mq;
            }
        }
    }
    return null;
}

/// Apply the !important modifier to declarations.
/// Returns a new slice of declarations with " !important" appended to each value.
fn applyImportant(alloc: std.mem.Allocator, decls: []const Declaration) ![]const Declaration {
    var result = try alloc.alloc(Declaration, decls.len);
    for (decls, 0..) |decl, i| {
        const new_value = try std.fmt.allocPrint(alloc, "{s} !important", .{decl.value});
        result[i] = .{
            .property = decl.property,
            .value = new_value,
        };
    }
    return result;
}

/// Compile a list of candidate strings into minified CSS.
///
/// Takes an allocator and a slice of candidate class names (e.g. ["flex", "hidden", "hover:bg-blue-500"]).
/// Returns minified CSS wrapped in @layer utilities { ... }.
///
/// Currently supports:
/// - Static utilities (Phase 1)
/// - Variant prefixes (hover:, sm:, etc.)
/// - Important flag (!)
///
/// Phase 2 will add:
/// - Functional utilities (p-4, text-lg, bg-blue-500, etc.)
/// - Theme resolution
/// - Negative values
pub fn compile(alloc: std.mem.Allocator, candidates: []const []const u8) ![]const u8 {
    var emitter = Emitter.init(alloc);
    defer emitter.deinit();

    emitter.writeLayerOpen("utilities");

    for (candidates) |candidate_str| {
        const candidate = candidate_module.parse(alloc, candidate_str) orelse continue;
        defer alloc.free(candidate.variants);

        // Static utility lookup: only when there is no value
        if (candidate.value == null) {
            if (utilities.lookup(candidate.utility)) |decls| {
                const selector = try buildSelector(alloc, candidate_str, candidate);
                defer alloc.free(selector);

                const media_query = resolveMediaQuery(candidate);

                var final_decls = decls;
                var important_decls: ?[]const Declaration = null;
                defer {
                    if (important_decls) |imp| {
                        for (imp) |d| alloc.free(@constCast(d.value));
                        alloc.free(imp);
                    }
                }

                if (candidate.important) {
                    important_decls = try applyImportant(alloc, decls);
                    final_decls = important_decls.?;
                }

                emitter.writeRule(.{
                    .selector = selector,
                    .declarations = final_decls,
                    .media_query = media_query,
                });
            }
        }

        // TODO: functional utilities (Phase 2)
    }

    emitter.writeLayerClose();
    return try emitter.toOwnedSlice();
}

// ── Tests ────────────────────────────────────────────────────────────────────

// Pull in tests from all submodules
comptime {
    _ = @import("candidate.zig");
    _ = @import("utilities.zig");
    _ = @import("emitter.zig");
    _ = @import("variants.zig");
}

test "compile empty candidates" {
    const result = try compile(std.testing.allocator, &.{});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("@layer utilities{}", result);
}

test "compile single static utility" {
    const result = try compile(std.testing.allocator, &.{"flex"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("@layer utilities{.flex{display:flex}}", result);
}

test "compile multiple static utilities" {
    const result = try compile(std.testing.allocator, &.{ "flex", "hidden", "block" });
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.flex{display:flex}.hidden{display:none}.block{display:block}}",
        result,
    );
}

test "compile static utility with multi-declaration" {
    const result = try compile(std.testing.allocator, &.{"antialiased"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.antialiased{-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}}",
        result,
    );
}

test "compile unknown utility is skipped" {
    const result = try compile(std.testing.allocator, &.{ "flex", "nonexistent", "block" });
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.flex{display:flex}.block{display:block}}",
        result,
    );
}

test "compile utility with hover variant" {
    const result = try compile(std.testing.allocator, &.{"hover:flex"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.hover\\:flex:hover{display:flex}}",
        result,
    );
}

test "compile utility with responsive variant" {
    const result = try compile(std.testing.allocator, &.{"sm:flex"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{@media(min-width:40rem){.sm\\:flex{display:flex}}}",
        result,
    );
}

test "compile utility with multiple variants" {
    const result = try compile(std.testing.allocator, &.{"hover:sm:flex"});
    defer std.testing.allocator.free(result);
    // sm provides media query, hover provides selector suffix
    try std.testing.expectEqualStrings(
        "@layer utilities{@media(min-width:40rem){.hover\\:sm\\:flex:hover{display:flex}}}",
        result,
    );
}

test "compile utility with important flag" {
    const result = try compile(std.testing.allocator, &.{"!flex"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.\\!flex{display:flex !important}}",
        result,
    );
}

test "compile selector escaping" {
    // Test that special characters are escaped in selectors
    const result = try compile(std.testing.allocator, &.{"overflow-hidden"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.overflow-hidden{overflow:hidden}}",
        result,
    );
}

test "compile truncate multi-declaration" {
    const result = try compile(std.testing.allocator, &.{"truncate"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.truncate{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}",
        result,
    );
}

test "compile sr-only utility" {
    const result = try compile(std.testing.allocator, &.{"sr-only"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border-width:0}}",
        result,
    );
}

test "compile dark variant" {
    const result = try compile(std.testing.allocator, &.{"dark:hidden"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{@media(prefers-color-scheme:dark){.dark\\:hidden{display:none}}}",
        result,
    );
}

test "compile focus variant" {
    const result = try compile(std.testing.allocator, &.{"focus:outline-none"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.focus\\:outline-none:focus{outline:2px solid transparent;outline-offset:2px}}",
        result,
    );
}

test "compile functional utility is skipped in phase 1" {
    // p-4 has a value, so it won't match static lookup
    const result = try compile(std.testing.allocator, &.{ "flex", "p-4", "hidden" });
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.flex{display:flex}.hidden{display:none}}",
        result,
    );
}

test "compile mixed static and variant utilities" {
    const result = try compile(std.testing.allocator, &.{
        "flex",
        "items-center",
        "hover:underline",
        "sm:hidden",
    });
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.flex{display:flex}.items-center{align-items:center}.hover\\:underline:hover{text-decoration-line:underline}@media(min-width:40rem){.sm\\:hidden{display:none}}}",
        result,
    );
}

test "compile cursor pointer" {
    const result = try compile(std.testing.allocator, &.{"cursor-pointer"});
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        "@layer utilities{.cursor-pointer{cursor:pointer}}",
        result,
    );
}
