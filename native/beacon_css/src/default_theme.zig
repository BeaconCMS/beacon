//! Default Tailwind v4 theme values.
//! Contains the default spacing scale, colors, font sizes, breakpoints, etc.
//!
//! Phase 2: Full default theme values will be populated here.

const std = @import("std");
const theme_mod = @import("theme.zig");

pub const Theme = theme_mod.Theme;

/// Create a Theme populated with Tailwind v4 default values.
pub fn defaults() Theme {
    return theme_mod.defaultTheme();
}
