const std = @import("std");
const utilities = @import("utilities.zig");

pub const Value = union(enum) {
    named: []const u8,
    arbitrary: []const u8,
    bare_number: i64,
    fraction: struct { numerator: i64, denominator: i64 },
};

pub const Candidate = struct {
    variants: []const []const u8,
    important: bool,
    negative: bool,
    utility: []const u8,
    value: ?Value,
    modifier: ?[]const u8,
};

/// Split a string on `:` respecting `[]` brackets.
/// Returns the segments before the last unbracketed `:` as variants,
/// and the remainder as the utility part.
fn splitVariants(alloc: std.mem.Allocator, input: []const u8) !struct {
    variants: []const []const u8,
    rest: []const u8,
} {
    var colon_positions: std.ArrayList(usize) = .empty;
    defer colon_positions.deinit(alloc);

    var bracket_depth: usize = 0;
    for (input, 0..) |ch, i| {
        switch (ch) {
            '[' => bracket_depth += 1,
            ']' => {
                if (bracket_depth > 0) bracket_depth -= 1;
            },
            ':' => {
                if (bracket_depth == 0) {
                    try colon_positions.append(alloc, i);
                }
            },
            else => {},
        }
    }

    if (colon_positions.items.len == 0) {
        const empty = try alloc.alloc([]const u8, 0);
        return .{ .variants = empty, .rest = input };
    }

    var variant_list: std.ArrayList([]const u8) = .empty;
    defer variant_list.deinit(alloc);

    var start: usize = 0;
    for (colon_positions.items) |pos| {
        try variant_list.append(alloc, input[start..pos]);
        start = pos + 1;
    }
    const rest = input[start..];

    return .{
        .variants = try variant_list.toOwnedSlice(alloc),
        .rest = rest,
    };
}

/// Split the modifier off the end of the utility part.
/// E.g. "bg-red-500/50" -> ("bg-red-500", "50")
/// Respects brackets: "bg-[url(x/y)]/50" -> ("bg-[url(x/y)]", "50")
fn splitModifier(input: []const u8) struct { base: []const u8, modifier: ?[]const u8 } {
    // Scan from the end for an unbracketed `/`
    var bracket_depth: usize = 0;
    var i: usize = input.len;
    while (i > 0) {
        i -= 1;
        const ch = input[i];
        if (ch == ']') {
            bracket_depth += 1;
        } else if (ch == '[') {
            if (bracket_depth > 0) bracket_depth -= 1;
        } else if (ch == '/' and bracket_depth == 0) {
            // Found unbracketed /
            if (i > 0 and i < input.len - 1) {
                return .{ .base = input[0..i], .modifier = input[i + 1 ..] };
            }
            break;
        }
    }
    return .{ .base = input, .modifier = null };
}

/// Parse the value part of a utility.
/// Given the part after the utility root (e.g. "blue-500", "4", "1/2", "[calc(100%-2rem)]")
fn parseValue(raw: []const u8) ?Value {
    if (raw.len == 0) return null;

    // Arbitrary value: [...]
    if (raw.len >= 2 and raw[0] == '[' and raw[raw.len - 1] == ']') {
        return .{ .arbitrary = raw[1 .. raw.len - 1] };
    }

    // Try fraction: digits/digits (but only if both sides are valid integers)
    if (std.mem.indexOfScalar(u8, raw, '/')) |slash_pos| {
        if (slash_pos > 0 and slash_pos < raw.len - 1) {
            const num_str = raw[0..slash_pos];
            const den_str = raw[slash_pos + 1 ..];
            const num = std.fmt.parseInt(i64, num_str, 10) catch null;
            const den = std.fmt.parseInt(i64, den_str, 10) catch null;
            if (num != null and den != null) {
                return .{ .fraction = .{ .numerator = num.?, .denominator = den.? } };
            }
        }
    }

    // Try bare number (integer)
    if (std.fmt.parseInt(i64, raw, 10)) |n| {
        return .{ .bare_number = n };
    } else |_| {}

    // Named value (default)
    return .{ .named = raw };
}

/// Find the utility root by matching against known utility prefixes.
/// For a candidate like "bg-blue-500", we need to find "bg" as the utility root.
/// We try progressively longer prefixes of the input.
///
/// The strategy:
/// 1. First check if the entire input is a static utility (like "flex", "hidden")
/// 2. Then try to find the longest utility root prefix followed by a `-`
fn findUtilityRoot(input: []const u8) struct { root: []const u8, value_part: ?[]const u8 } {
    // Check if the entire thing is a known static utility
    if (utilities.lookup(input) != null) {
        return .{ .root = input, .value_part = null };
    }

    // Known functional utility prefixes (ordered: try to match longest first)
    // These are utility roots that take a value after a `-`
    const known_prefixes = [_][]const u8{
        // Spacing
        "p",  "px", "py", "pt", "pr", "pb", "pl", "ps", "pe",
        "m",  "mx", "my", "mt", "mr", "mb", "ml", "ms", "me",
        // Sizing
        "w",     "h",     "size",
        "min-w", "min-h", "max-w", "max-h",
        // Layout
        "gap",    "gap-x",  "gap-y",
        "basis",  "order",
        "columns",
        "inset",  "inset-x", "inset-y",
        "top",    "right",   "bottom",  "left",
        "start",  "end",
        "z",
        // Grid
        "grid-cols",     "grid-rows",
        "col-span",      "row-span",
        "col-start",     "col-end",
        "row-start",     "row-end",
        "auto-cols",     "auto-rows",
        // Typography
        "text",        "font",     "tracking",
        "leading",     "indent",
        "decoration",
        // Colors
        "bg",          "text",     "border",
        "ring",        "ring-offset",
        "divide",      "outline",
        "accent",      "caret",
        "fill",        "stroke",
        "shadow",      "from",    "via", "to",
        "placeholder",
        // Border
        "border",      "border-x", "border-y",
        "border-t",    "border-r", "border-b", "border-l",
        "border-s",    "border-e",
        "rounded",
        "rounded-t",   "rounded-r",  "rounded-b",  "rounded-l",
        "rounded-tl",  "rounded-tr", "rounded-br",  "rounded-bl",
        "rounded-s",   "rounded-e",  "rounded-ss",  "rounded-se",
        "rounded-es",  "rounded-ee",
        "divide-x",    "divide-y",
        // Effects
        "opacity",     "shadow",
        "blur",        "brightness", "contrast",
        "drop-shadow", "grayscale",  "hue-rotate",
        "invert",      "saturate",   "sepia",
        "backdrop-blur",       "backdrop-brightness",
        "backdrop-contrast",   "backdrop-grayscale",
        "backdrop-hue-rotate", "backdrop-invert",
        "backdrop-opacity",    "backdrop-saturate",
        "backdrop-sepia",
        // Transform
        "scale",   "scale-x",  "scale-y",
        "rotate",
        "translate-x", "translate-y",
        "skew-x",  "skew-y",
        "origin",
        "perspective",
        // Transition
        "duration", "delay",  "ease",
        // Spacing
        "space-x",  "space-y",
        "scroll-m",  "scroll-mx", "scroll-my",
        "scroll-mt", "scroll-mr", "scroll-mb", "scroll-ml",
        "scroll-ms", "scroll-me",
        "scroll-p",  "scroll-px", "scroll-py",
        "scroll-pt", "scroll-pr", "scroll-pb", "scroll-pl",
        "scroll-ps", "scroll-pe",
        // Aspect
        "aspect",
        // Stroke
        "stroke",
        // Line clamp
        "line-clamp",
        // Content
        "content",
        // Ring
        "ring-offset",
        // Outline
        "outline-offset",
        "outline",
    };

    // Sort by longest prefix first so we match the most specific
    // Since we're doing this at runtime, we scan linearly and track the longest match
    var best_root: ?[]const u8 = null;
    var best_value: ?[]const u8 = null;

    for (known_prefixes) |prefix| {
        // Check if input starts with prefix followed by `-`
        if (input.len > prefix.len + 1 and
            std.mem.eql(u8, input[0..prefix.len], prefix) and
            input[prefix.len] == '-')
        {
            // This prefix matches; is it longer than the best so far?
            if (best_root == null or prefix.len > best_root.?.len) {
                best_root = prefix;
                best_value = input[prefix.len + 1 ..];
            }
        }
    }

    if (best_root) |root| {
        return .{ .root = root, .value_part = best_value };
    }

    // No known prefix matched; treat the entire thing as the utility root
    return .{ .root = input, .value_part = null };
}

/// Parse a candidate string into its components.
/// Examples:
///   "flex"                -> { utility: "flex", value: null }
///   "p-4"                 -> { utility: "p", value: bare_number(4) }
///   "bg-blue-500"         -> { utility: "bg", value: named("blue-500") }
///   "hover:bg-blue-500"   -> { variants: ["hover"], utility: "bg", value: named("blue-500") }
///   "!font-bold"          -> { important: true, utility: "font-bold", value: null }
///   "-m-4"                -> { negative: true, utility: "m", value: bare_number(4) }
///   "bg-red-500/50"       -> { utility: "bg", value: named("red-500"), modifier: "50" }
///   "w-[calc(100%-2rem)]" -> { utility: "w", value: arbitrary("calc(100%-2rem)") }
///   "text-[#ff0000]"      -> { utility: "text", value: arbitrary("#ff0000") }
///   "w-1/2"               -> { utility: "w", value: fraction(1,2) }
pub fn parse(alloc: std.mem.Allocator, input: []const u8) ?Candidate {
    if (input.len == 0) return null;

    var remaining = input;
    var important = false;
    var negative = false;

    // Check for leading !
    if (remaining[0] == '!') {
        important = true;
        remaining = remaining[1..];
        if (remaining.len == 0) return null;
    }

    // Split variants
    const split = splitVariants(alloc, remaining) catch return null;
    remaining = split.rest;

    if (remaining.len == 0) {
        alloc.free(split.variants);
        return null;
    }

    // Check for leading - (negative value)
    if (remaining[0] == '-') {
        negative = true;
        remaining = remaining[1..];
        if (remaining.len == 0) {
            alloc.free(split.variants);
            return null;
        }
    }

    // Try parsing with and without modifier split.
    // Strategy: first try with modifier split. If the value part contains
    // a fraction (num/num), prefer interpreting the whole thing without
    // the modifier split.
    const mod_split = splitModifier(remaining);
    const util_with_mod = findUtilityRoot(mod_split.base);
    const util_without_mod = findUtilityRoot(remaining);

    var utility_root: []const u8 = undefined;
    var value: ?Value = null;
    var modifier: ?[]const u8 = null;

    // If there was no `/` at all, simple case
    if (mod_split.modifier == null) {
        utility_root = util_without_mod.root;
        if (util_without_mod.value_part) |vp| {
            value = parseValue(vp);
        }
    } else {
        // There was a `/` -- check if the unsplit version produces a fraction
        var is_fraction = false;
        if (util_without_mod.value_part) |vp| {
            const unsplit_value = parseValue(vp);
            if (unsplit_value) |uv| {
                switch (uv) {
                    .fraction => {
                        is_fraction = true;
                    },
                    else => {},
                }
            }
        }

        if (is_fraction) {
            // Use unsplit: the `/` is part of a fraction value
            utility_root = util_without_mod.root;
            if (util_without_mod.value_part) |vp| {
                value = parseValue(vp);
            }
            modifier = null;
        } else {
            // Use split: the `/` is a modifier separator
            utility_root = util_with_mod.root;
            if (util_with_mod.value_part) |vp| {
                value = parseValue(vp);
            }
            modifier = mod_split.modifier;
        }
    }

    return Candidate{
        .variants = split.variants,
        .important = important,
        .negative = negative,
        .utility = utility_root,
        .value = value,
        .modifier = modifier,
    };
}

// ── Tests ────────────────────────────────────────────────────────────────────

test "parse simple static utility" {
    const c = parse(std.testing.allocator, "flex").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("flex", c.utility);
    try std.testing.expect(c.value == null);
    try std.testing.expect(!c.important);
    try std.testing.expect(!c.negative);
    try std.testing.expect(c.modifier == null);
    try std.testing.expectEqual(@as(usize, 0), c.variants.len);
}

test "parse utility with bare number value" {
    const c = parse(std.testing.allocator, "p-4").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("p", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 4 }, c.value.?);
    try std.testing.expect(c.modifier == null);
}

test "parse utility with named value" {
    const c = parse(std.testing.allocator, "bg-blue-500").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("bg", c.utility);
    try std.testing.expectEqualStrings("blue-500", c.value.?.named);
}

test "parse utility with arbitrary value" {
    const c = parse(std.testing.allocator, "w-[calc(100%-2rem)]").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("w", c.utility);
    try std.testing.expectEqualStrings("calc(100%-2rem)", c.value.?.arbitrary);
}

test "parse utility with fraction value" {
    const c = parse(std.testing.allocator, "w-1/2").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("w", c.utility);
    const frac = c.value.?.fraction;
    try std.testing.expectEqual(@as(i64, 1), frac.numerator);
    try std.testing.expectEqual(@as(i64, 2), frac.denominator);
}

test "parse with variants" {
    const c = parse(std.testing.allocator, "hover:sm:bg-blue-500").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqual(@as(usize, 2), c.variants.len);
    try std.testing.expectEqualStrings("hover", c.variants[0]);
    try std.testing.expectEqualStrings("sm", c.variants[1]);
    try std.testing.expectEqualStrings("bg", c.utility);
    try std.testing.expectEqualStrings("blue-500", c.value.?.named);
}

test "parse with important flag" {
    const c = parse(std.testing.allocator, "!font-bold").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expect(c.important);
    // "font-bold" is not a known static or prefix, so it becomes the full root
    try std.testing.expectEqualStrings("font", c.utility);
    try std.testing.expectEqualStrings("bold", c.value.?.named);
}

test "parse with negative flag" {
    const c = parse(std.testing.allocator, "-m-4").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expect(c.negative);
    try std.testing.expectEqualStrings("m", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 4 }, c.value.?);
}

test "parse with modifier" {
    const c = parse(std.testing.allocator, "bg-red-500/50").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("bg", c.utility);
    try std.testing.expectEqualStrings("red-500", c.value.?.named);
    try std.testing.expectEqualStrings("50", c.modifier.?);
}

test "parse with arbitrary value and modifier" {
    const c = parse(std.testing.allocator, "bg-[#ff0000]/75").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("bg", c.utility);
    try std.testing.expectEqualStrings("#ff0000", c.value.?.arbitrary);
    try std.testing.expectEqualStrings("75", c.modifier.?);
}

test "parse with variants, important, and modifier" {
    const c = parse(std.testing.allocator, "!hover:bg-red-500/50").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expect(c.important);
    try std.testing.expectEqual(@as(usize, 1), c.variants.len);
    try std.testing.expectEqualStrings("hover", c.variants[0]);
    try std.testing.expectEqualStrings("bg", c.utility);
    try std.testing.expectEqualStrings("red-500", c.value.?.named);
    try std.testing.expectEqualStrings("50", c.modifier.?);
}

test "parse with bracket in variant" {
    // group-[.is-published]:block — the bracket is inside the variant
    const c = parse(std.testing.allocator, "group-[.is-published]:block").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqual(@as(usize, 1), c.variants.len);
    try std.testing.expectEqualStrings("group-[.is-published]", c.variants[0]);
    try std.testing.expectEqualStrings("block", c.utility);
}

test "parse returns null for empty input" {
    try std.testing.expect(parse(std.testing.allocator, "") == null);
    try std.testing.expect(parse(std.testing.allocator, "!") == null);
}

test "parse negative with named value" {
    const c = parse(std.testing.allocator, "-top-4").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expect(c.negative);
    try std.testing.expectEqualStrings("top", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 4 }, c.value.?);
}

test "parse multi-part utility prefix" {
    // min-w-full is a known static utility, so it resolves as a whole
    const c = parse(std.testing.allocator, "min-w-full").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("min-w-full", c.utility);
    try std.testing.expect(c.value == null);
}

test "parse multi-part utility with value" {
    // min-w-0 is NOT a static utility, so it resolves as prefix + value
    const c = parse(std.testing.allocator, "min-w-screen").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("min-w", c.utility);
    try std.testing.expectEqualStrings("screen", c.value.?.named);
}

test "parse border utility with value" {
    const c = parse(std.testing.allocator, "border-t-2").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("border-t", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 2 }, c.value.?);
}

test "parse arbitrary value with colon inside brackets" {
    // color:[var(--my-color)] — the colon inside brackets should not be a variant split
    const c = parse(std.testing.allocator, "text-[color:var(--my-color)]").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqual(@as(usize, 0), c.variants.len);
    try std.testing.expectEqualStrings("text", c.utility);
    try std.testing.expectEqualStrings("color:var(--my-color)", c.value.?.arbitrary);
}

test "parse grid column utility" {
    const c = parse(std.testing.allocator, "grid-cols-3").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("grid-cols", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 3 }, c.value.?);
}

test "parse scale utility" {
    const c = parse(std.testing.allocator, "scale-75").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("scale", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 75 }, c.value.?);
}

test "parse duration utility" {
    const c = parse(std.testing.allocator, "duration-300").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("duration", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 300 }, c.value.?);
}

test "parse divide utility" {
    const c = parse(std.testing.allocator, "divide-x-2").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("divide-x", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 2 }, c.value.?);
}

test "parse rounded utility" {
    const c = parse(std.testing.allocator, "rounded-tl-lg").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("rounded-tl", c.utility);
    try std.testing.expectEqualStrings("lg", c.value.?.named);
}

test "parse translate utility" {
    const c = parse(std.testing.allocator, "translate-x-4").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("translate-x", c.utility);
    try std.testing.expectEqual(Value{ .bare_number = 4 }, c.value.?);
}

test "parse with modifier on arbitrary" {
    // Brackets with slash inside should not split: bg-[url(x/y)]/50
    const c = parse(std.testing.allocator, "bg-[url(x/y)]/50").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("bg", c.utility);
    try std.testing.expectEqualStrings("url(x/y)", c.value.?.arbitrary);
    try std.testing.expectEqualStrings("50", c.modifier.?);
}

test "parse fraction in larger utility" {
    const c = parse(std.testing.allocator, "basis-1/2").?;
    defer std.testing.allocator.free(c.variants);
    try std.testing.expectEqualStrings("basis", c.utility);
    const frac = c.value.?.fraction;
    try std.testing.expectEqual(@as(i64, 1), frac.numerator);
    try std.testing.expectEqual(@as(i64, 2), frac.denominator);
}
