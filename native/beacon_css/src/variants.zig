//! Variant definitions for Tailwind CSS v4.
//! Maps variant names to their CSS selector transformations and media queries.
//!
//! Phase 2: Full variant resolution will be implemented here.

const std = @import("std");

pub const VariantResult = struct {
    /// The selector suffix/transformation (e.g. ":hover", ":focus", "::before")
    selector_suffix: ?[]const u8,
    /// Optional media query wrapper (e.g. "@media(hover:hover)")
    media_query: ?[]const u8,
};

/// Resolve a variant name to its CSS selector transformation.
/// Returns null if the variant is not recognized.
pub fn resolve(name: []const u8) ?VariantResult {
    return variant_map.get(name);
}

/// Helper to construct a VariantResult at comptime.
fn v(comptime suffix: ?[]const u8, comptime mq: ?[]const u8) VariantResult {
    return .{ .selector_suffix = suffix, .media_query = mq };
}

const variant_map = std.StaticStringMap(VariantResult).initComptime(.{
    // Pseudo-class variants
    .{ "hover", v(":hover", null) },
    .{ "focus", v(":focus", null) },
    .{ "focus-within", v(":focus-within", null) },
    .{ "focus-visible", v(":focus-visible", null) },
    .{ "active", v(":active", null) },
    .{ "visited", v(":visited", null) },
    .{ "target", v(":target", null) },
    .{ "first", v(":first-child", null) },
    .{ "last", v(":last-child", null) },
    .{ "only", v(":only-child", null) },
    .{ "odd", v(":nth-child(odd)", null) },
    .{ "even", v(":nth-child(even)", null) },
    .{ "first-of-type", v(":first-of-type", null) },
    .{ "last-of-type", v(":last-of-type", null) },
    .{ "only-of-type", v(":only-of-type", null) },
    .{ "empty", v(":empty", null) },
    .{ "disabled", v(":disabled", null) },
    .{ "enabled", v(":enabled", null) },
    .{ "checked", v(":checked", null) },
    .{ "indeterminate", v(":indeterminate", null) },
    .{ "default", v(":default", null) },
    .{ "required", v(":required", null) },
    .{ "valid", v(":valid", null) },
    .{ "invalid", v(":invalid", null) },
    .{ "in-range", v(":in-range", null) },
    .{ "out-of-range", v(":out-of-range", null) },
    .{ "placeholder-shown", v(":placeholder-shown", null) },
    .{ "autofill", v(":autofill", null) },
    .{ "read-only", v(":read-only", null) },
    .{ "open", v(":open", null) },

    // Pseudo-element variants
    .{ "before", v("::before", null) },
    .{ "after", v("::after", null) },
    .{ "placeholder", v("::placeholder", null) },
    .{ "file", v("::file-selector-button", null) },
    .{ "marker", v("::marker", null) },
    .{ "selection", v("::selection", null) },
    .{ "first-line", v("::first-line", null) },
    .{ "first-letter", v("::first-letter", null) },
    .{ "backdrop", v("::backdrop", null) },

    // Responsive breakpoints (Tailwind v4 defaults)
    .{ "sm", v(null, "@media(min-width:40rem)") },
    .{ "md", v(null, "@media(min-width:48rem)") },
    .{ "lg", v(null, "@media(min-width:64rem)") },
    .{ "xl", v(null, "@media(min-width:80rem)") },
    .{ "2xl", v(null, "@media(min-width:96rem)") },

    // Preference media queries
    .{ "dark", v(null, "@media(prefers-color-scheme:dark)") },
    .{ "motion-safe", v(null, "@media(prefers-reduced-motion:no-preference)") },
    .{ "motion-reduce", v(null, "@media(prefers-reduced-motion:reduce)") },
    .{ "contrast-more", v(null, "@media(prefers-contrast:more)") },
    .{ "contrast-less", v(null, "@media(prefers-contrast:less)") },
    .{ "portrait", v(null, "@media(orientation:portrait)") },
    .{ "landscape", v(null, "@media(orientation:landscape)") },
    .{ "print", v(null, "@media print") },

    // Forced colors
    .{ "forced-colors", v(null, "@media(forced-colors:active)") },
});

// ── Tests ────────────────────────────────────────────────────────────────────

test "resolve hover variant" {
    const result = resolve("hover").?;
    try std.testing.expectEqualStrings(":hover", result.selector_suffix.?);
    try std.testing.expect(result.media_query == null);
}

test "resolve responsive variant" {
    const result = resolve("sm").?;
    try std.testing.expect(result.selector_suffix == null);
    try std.testing.expectEqualStrings("@media(min-width:40rem)", result.media_query.?);
}

test "resolve dark variant" {
    const result = resolve("dark").?;
    try std.testing.expect(result.selector_suffix == null);
    try std.testing.expectEqualStrings("@media(prefers-color-scheme:dark)", result.media_query.?);
}

test "resolve pseudo-element variant" {
    const result = resolve("before").?;
    try std.testing.expectEqualStrings("::before", result.selector_suffix.?);
}

test "resolve unknown variant" {
    try std.testing.expect(resolve("nonexistent") == null);
}
