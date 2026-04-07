//! Theme data structure and resolver.
//! Maps theme keys (e.g. spacing scale, colors) to CSS values.
//!
//! Phase 2: Full theme resolution will be implemented here.

const std = @import("std");

pub const Theme = struct {
    // Placeholder for theme data.
    // In Phase 2, this will hold the full Tailwind v4 theme:
    // colors, spacing scale, breakpoints, font sizes, etc.
    _placeholder: u8 = 0,
};

/// Return the default Tailwind v4 theme.
pub fn defaultTheme() Theme {
    return .{};
}
