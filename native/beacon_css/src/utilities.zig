const std = @import("std");

pub const Declaration = struct {
    property: []const u8,
    value: []const u8,
};

/// Helper to create a comptime slice of declarations.
fn d(comptime decls: []const Declaration) []const Declaration {
    return decls;
}

pub const static_map = std.StaticStringMap([]const Declaration).initComptime(.{
    // ── Display ──────────────────────────────────────────────────────────
    .{ "block", d(&.{.{ .property = "display", .value = "block" }}) },
    .{ "inline-block", d(&.{.{ .property = "display", .value = "inline-block" }}) },
    .{ "inline", d(&.{.{ .property = "display", .value = "inline" }}) },
    .{ "flex", d(&.{.{ .property = "display", .value = "flex" }}) },
    .{ "inline-flex", d(&.{.{ .property = "display", .value = "inline-flex" }}) },
    .{ "grid", d(&.{.{ .property = "display", .value = "grid" }}) },
    .{ "inline-grid", d(&.{.{ .property = "display", .value = "inline-grid" }}) },
    .{ "contents", d(&.{.{ .property = "display", .value = "contents" }}) },
    .{ "hidden", d(&.{.{ .property = "display", .value = "none" }}) },
    .{ "table", d(&.{.{ .property = "display", .value = "table" }}) },
    .{ "table-row", d(&.{.{ .property = "display", .value = "table-row" }}) },
    .{ "table-cell", d(&.{.{ .property = "display", .value = "table-cell" }}) },
    .{ "flow-root", d(&.{.{ .property = "display", .value = "flow-root" }}) },
    .{ "list-item", d(&.{.{ .property = "display", .value = "list-item" }}) },

    // ── Position ─────────────────────────────────────────────────────────
    .{ "static", d(&.{.{ .property = "position", .value = "static" }}) },
    .{ "fixed", d(&.{.{ .property = "position", .value = "fixed" }}) },
    .{ "absolute", d(&.{.{ .property = "position", .value = "absolute" }}) },
    .{ "relative", d(&.{.{ .property = "position", .value = "relative" }}) },
    .{ "sticky", d(&.{.{ .property = "position", .value = "sticky" }}) },

    // ── Visibility ───────────────────────────────────────────────────────
    .{ "visible", d(&.{.{ .property = "visibility", .value = "visible" }}) },
    .{ "invisible", d(&.{.{ .property = "visibility", .value = "hidden" }}) },
    .{ "collapse", d(&.{.{ .property = "visibility", .value = "collapse" }}) },

    // ── Overflow ─────────────────────────────────────────────────────────
    .{ "overflow-auto", d(&.{.{ .property = "overflow", .value = "auto" }}) },
    .{ "overflow-hidden", d(&.{.{ .property = "overflow", .value = "hidden" }}) },
    .{ "overflow-visible", d(&.{.{ .property = "overflow", .value = "visible" }}) },
    .{ "overflow-scroll", d(&.{.{ .property = "overflow", .value = "scroll" }}) },
    .{ "overflow-clip", d(&.{.{ .property = "overflow", .value = "clip" }}) },
    .{ "overflow-x-auto", d(&.{.{ .property = "overflow-x", .value = "auto" }}) },
    .{ "overflow-x-hidden", d(&.{.{ .property = "overflow-x", .value = "hidden" }}) },
    .{ "overflow-x-clip", d(&.{.{ .property = "overflow-x", .value = "clip" }}) },
    .{ "overflow-x-visible", d(&.{.{ .property = "overflow-x", .value = "visible" }}) },
    .{ "overflow-x-scroll", d(&.{.{ .property = "overflow-x", .value = "scroll" }}) },
    .{ "overflow-y-auto", d(&.{.{ .property = "overflow-y", .value = "auto" }}) },
    .{ "overflow-y-hidden", d(&.{.{ .property = "overflow-y", .value = "hidden" }}) },
    .{ "overflow-y-clip", d(&.{.{ .property = "overflow-y", .value = "clip" }}) },
    .{ "overflow-y-visible", d(&.{.{ .property = "overflow-y", .value = "visible" }}) },
    .{ "overflow-y-scroll", d(&.{.{ .property = "overflow-y", .value = "scroll" }}) },

    // ── Float / Clear ────────────────────────────────────────────────────
    .{ "float-left", d(&.{.{ .property = "float", .value = "left" }}) },
    .{ "float-right", d(&.{.{ .property = "float", .value = "right" }}) },
    .{ "float-none", d(&.{.{ .property = "float", .value = "none" }}) },
    .{ "float-start", d(&.{.{ .property = "float", .value = "inline-start" }}) },
    .{ "float-end", d(&.{.{ .property = "float", .value = "inline-end" }}) },
    .{ "clear-left", d(&.{.{ .property = "clear", .value = "left" }}) },
    .{ "clear-right", d(&.{.{ .property = "clear", .value = "right" }}) },
    .{ "clear-both", d(&.{.{ .property = "clear", .value = "both" }}) },
    .{ "clear-none", d(&.{.{ .property = "clear", .value = "none" }}) },
    .{ "clear-start", d(&.{.{ .property = "clear", .value = "inline-start" }}) },
    .{ "clear-end", d(&.{.{ .property = "clear", .value = "inline-end" }}) },

    // ── Box Sizing ───────────────────────────────────────────────────────
    .{ "box-border", d(&.{.{ .property = "box-sizing", .value = "border-box" }}) },
    .{ "box-content", d(&.{.{ .property = "box-sizing", .value = "content-box" }}) },

    // ── Isolation ────────────────────────────────────────────────────────
    .{ "isolate", d(&.{.{ .property = "isolation", .value = "isolate" }}) },
    .{ "isolation-auto", d(&.{.{ .property = "isolation", .value = "auto" }}) },

    // ── Object Fit ───────────────────────────────────────────────────────
    .{ "object-contain", d(&.{.{ .property = "object-fit", .value = "contain" }}) },
    .{ "object-cover", d(&.{.{ .property = "object-fit", .value = "cover" }}) },
    .{ "object-fill", d(&.{.{ .property = "object-fit", .value = "fill" }}) },
    .{ "object-none", d(&.{.{ .property = "object-fit", .value = "none" }}) },
    .{ "object-scale-down", d(&.{.{ .property = "object-fit", .value = "scale-down" }}) },

    // ── Flex Direction ───────────────────────────────────────────────────
    .{ "flex-row", d(&.{.{ .property = "flex-direction", .value = "row" }}) },
    .{ "flex-row-reverse", d(&.{.{ .property = "flex-direction", .value = "row-reverse" }}) },
    .{ "flex-col", d(&.{.{ .property = "flex-direction", .value = "column" }}) },
    .{ "flex-col-reverse", d(&.{.{ .property = "flex-direction", .value = "column-reverse" }}) },

    // ── Flex Wrap ────────────────────────────────────────────────────────
    .{ "flex-wrap", d(&.{.{ .property = "flex-wrap", .value = "wrap" }}) },
    .{ "flex-wrap-reverse", d(&.{.{ .property = "flex-wrap", .value = "wrap-reverse" }}) },
    .{ "flex-nowrap", d(&.{.{ .property = "flex-wrap", .value = "nowrap" }}) },

    // ── Flex Shorthand ───────────────────────────────────────────────────
    .{ "flex-1", d(&.{.{ .property = "flex", .value = "1 1 0%" }}) },
    .{ "flex-auto", d(&.{.{ .property = "flex", .value = "1 1 auto" }}) },
    .{ "flex-initial", d(&.{.{ .property = "flex", .value = "0 1 auto" }}) },
    .{ "flex-none", d(&.{.{ .property = "flex", .value = "none" }}) },

    // ── Grow / Shrink ────────────────────────────────────────────────────
    .{ "grow", d(&.{.{ .property = "flex-grow", .value = "1" }}) },
    .{ "grow-0", d(&.{.{ .property = "flex-grow", .value = "0" }}) },
    .{ "shrink", d(&.{.{ .property = "flex-shrink", .value = "1" }}) },
    .{ "shrink-0", d(&.{.{ .property = "flex-shrink", .value = "0" }}) },

    // ── Grid Auto Flow ───────────────────────────────────────────────────
    .{ "grid-flow-row", d(&.{.{ .property = "grid-auto-flow", .value = "row" }}) },
    .{ "grid-flow-col", d(&.{.{ .property = "grid-auto-flow", .value = "column" }}) },
    .{ "grid-flow-dense", d(&.{.{ .property = "grid-auto-flow", .value = "dense" }}) },
    .{ "grid-flow-row-dense", d(&.{.{ .property = "grid-auto-flow", .value = "row dense" }}) },
    .{ "grid-flow-col-dense", d(&.{.{ .property = "grid-auto-flow", .value = "column dense" }}) },

    // ── Justify Content ──────────────────────────────────────────────────
    .{ "justify-start", d(&.{.{ .property = "justify-content", .value = "flex-start" }}) },
    .{ "justify-end", d(&.{.{ .property = "justify-content", .value = "flex-end" }}) },
    .{ "justify-center", d(&.{.{ .property = "justify-content", .value = "center" }}) },
    .{ "justify-between", d(&.{.{ .property = "justify-content", .value = "space-between" }}) },
    .{ "justify-around", d(&.{.{ .property = "justify-content", .value = "space-around" }}) },
    .{ "justify-evenly", d(&.{.{ .property = "justify-content", .value = "space-evenly" }}) },
    .{ "justify-stretch", d(&.{.{ .property = "justify-content", .value = "stretch" }}) },
    .{ "justify-normal", d(&.{.{ .property = "justify-content", .value = "normal" }}) },

    // ── Justify Items ────────────────────────────────────────────────────
    .{ "justify-items-start", d(&.{.{ .property = "justify-items", .value = "start" }}) },
    .{ "justify-items-end", d(&.{.{ .property = "justify-items", .value = "end" }}) },
    .{ "justify-items-center", d(&.{.{ .property = "justify-items", .value = "center" }}) },
    .{ "justify-items-stretch", d(&.{.{ .property = "justify-items", .value = "stretch" }}) },

    // ── Justify Self ─────────────────────────────────────────────────────
    .{ "justify-self-auto", d(&.{.{ .property = "justify-self", .value = "auto" }}) },
    .{ "justify-self-start", d(&.{.{ .property = "justify-self", .value = "start" }}) },
    .{ "justify-self-end", d(&.{.{ .property = "justify-self", .value = "end" }}) },
    .{ "justify-self-center", d(&.{.{ .property = "justify-self", .value = "center" }}) },
    .{ "justify-self-stretch", d(&.{.{ .property = "justify-self", .value = "stretch" }}) },

    // ── Align Items ──────────────────────────────────────────────────────
    .{ "items-start", d(&.{.{ .property = "align-items", .value = "flex-start" }}) },
    .{ "items-end", d(&.{.{ .property = "align-items", .value = "flex-end" }}) },
    .{ "items-center", d(&.{.{ .property = "align-items", .value = "center" }}) },
    .{ "items-baseline", d(&.{.{ .property = "align-items", .value = "baseline" }}) },
    .{ "items-stretch", d(&.{.{ .property = "align-items", .value = "stretch" }}) },

    // ── Align Self ───────────────────────────────────────────────────────
    .{ "self-auto", d(&.{.{ .property = "align-self", .value = "auto" }}) },
    .{ "self-start", d(&.{.{ .property = "align-self", .value = "flex-start" }}) },
    .{ "self-end", d(&.{.{ .property = "align-self", .value = "flex-end" }}) },
    .{ "self-center", d(&.{.{ .property = "align-self", .value = "center" }}) },
    .{ "self-stretch", d(&.{.{ .property = "align-self", .value = "stretch" }}) },
    .{ "self-baseline", d(&.{.{ .property = "align-self", .value = "baseline" }}) },

    // ── Align Content ────────────────────────────────────────────────────
    .{ "content-start", d(&.{.{ .property = "align-content", .value = "flex-start" }}) },
    .{ "content-end", d(&.{.{ .property = "align-content", .value = "flex-end" }}) },
    .{ "content-center", d(&.{.{ .property = "align-content", .value = "center" }}) },
    .{ "content-between", d(&.{.{ .property = "align-content", .value = "space-between" }}) },
    .{ "content-around", d(&.{.{ .property = "align-content", .value = "space-around" }}) },
    .{ "content-evenly", d(&.{.{ .property = "align-content", .value = "space-evenly" }}) },
    .{ "content-stretch", d(&.{.{ .property = "align-content", .value = "stretch" }}) },
    .{ "content-baseline", d(&.{.{ .property = "align-content", .value = "baseline" }}) },
    .{ "content-normal", d(&.{.{ .property = "align-content", .value = "normal" }}) },

    // ── Place Content ────────────────────────────────────────────────────
    .{ "place-content-center", d(&.{.{ .property = "place-content", .value = "center" }}) },
    .{ "place-content-start", d(&.{.{ .property = "place-content", .value = "start" }}) },
    .{ "place-content-end", d(&.{.{ .property = "place-content", .value = "end" }}) },
    .{ "place-content-between", d(&.{.{ .property = "place-content", .value = "space-between" }}) },
    .{ "place-content-around", d(&.{.{ .property = "place-content", .value = "space-around" }}) },
    .{ "place-content-evenly", d(&.{.{ .property = "place-content", .value = "space-evenly" }}) },
    .{ "place-content-stretch", d(&.{.{ .property = "place-content", .value = "stretch" }}) },
    .{ "place-content-baseline", d(&.{.{ .property = "place-content", .value = "baseline" }}) },

    // ── Place Items ──────────────────────────────────────────────────────
    .{ "place-items-start", d(&.{.{ .property = "place-items", .value = "start" }}) },
    .{ "place-items-end", d(&.{.{ .property = "place-items", .value = "end" }}) },
    .{ "place-items-center", d(&.{.{ .property = "place-items", .value = "center" }}) },
    .{ "place-items-stretch", d(&.{.{ .property = "place-items", .value = "stretch" }}) },
    .{ "place-items-baseline", d(&.{.{ .property = "place-items", .value = "baseline" }}) },

    // ── Place Self ───────────────────────────────────────────────────────
    .{ "place-self-auto", d(&.{.{ .property = "place-self", .value = "auto" }}) },
    .{ "place-self-start", d(&.{.{ .property = "place-self", .value = "start" }}) },
    .{ "place-self-end", d(&.{.{ .property = "place-self", .value = "end" }}) },
    .{ "place-self-center", d(&.{.{ .property = "place-self", .value = "center" }}) },
    .{ "place-self-stretch", d(&.{.{ .property = "place-self", .value = "stretch" }}) },

    // ── Text Alignment ───────────────────────────────────────────────────
    .{ "text-left", d(&.{.{ .property = "text-align", .value = "left" }}) },
    .{ "text-center", d(&.{.{ .property = "text-align", .value = "center" }}) },
    .{ "text-right", d(&.{.{ .property = "text-align", .value = "right" }}) },
    .{ "text-justify", d(&.{.{ .property = "text-align", .value = "justify" }}) },
    .{ "text-start", d(&.{.{ .property = "text-align", .value = "start" }}) },
    .{ "text-end", d(&.{.{ .property = "text-align", .value = "end" }}) },

    // ── Text Transform ───────────────────────────────────────────────────
    .{ "uppercase", d(&.{.{ .property = "text-transform", .value = "uppercase" }}) },
    .{ "lowercase", d(&.{.{ .property = "text-transform", .value = "lowercase" }}) },
    .{ "capitalize", d(&.{.{ .property = "text-transform", .value = "capitalize" }}) },
    .{ "normal-case", d(&.{.{ .property = "text-transform", .value = "none" }}) },

    // ── Font Style ───────────────────────────────────────────────────────
    .{ "italic", d(&.{.{ .property = "font-style", .value = "italic" }}) },
    .{ "not-italic", d(&.{.{ .property = "font-style", .value = "normal" }}) },

    // ── Text Decoration ──────────────────────────────────────────────────
    .{ "underline", d(&.{.{ .property = "text-decoration-line", .value = "underline" }}) },
    .{ "overline", d(&.{.{ .property = "text-decoration-line", .value = "overline" }}) },
    .{ "line-through", d(&.{.{ .property = "text-decoration-line", .value = "line-through" }}) },
    .{ "no-underline", d(&.{.{ .property = "text-decoration-line", .value = "none" }}) },

    // ── Font Smoothing ───────────────────────────────────────────────────
    .{ "antialiased", d(&.{
        .{ .property = "-webkit-font-smoothing", .value = "antialiased" },
        .{ .property = "-moz-osx-font-smoothing", .value = "grayscale" },
    }) },
    .{ "subpixel-antialiased", d(&.{
        .{ .property = "-webkit-font-smoothing", .value = "auto" },
        .{ .property = "-moz-osx-font-smoothing", .value = "auto" },
    }) },

    // ── Text Overflow ────────────────────────────────────────────────────
    .{ "truncate", d(&.{
        .{ .property = "overflow", .value = "hidden" },
        .{ .property = "text-overflow", .value = "ellipsis" },
        .{ .property = "white-space", .value = "nowrap" },
    }) },
    .{ "text-ellipsis", d(&.{.{ .property = "text-overflow", .value = "ellipsis" }}) },
    .{ "text-clip", d(&.{.{ .property = "text-overflow", .value = "clip" }}) },

    // ── Text Wrap ────────────────────────────────────────────────────────
    .{ "text-wrap", d(&.{.{ .property = "text-wrap", .value = "wrap" }}) },
    .{ "text-nowrap", d(&.{.{ .property = "text-wrap", .value = "nowrap" }}) },
    .{ "text-balance", d(&.{.{ .property = "text-wrap", .value = "balance" }}) },
    .{ "text-pretty", d(&.{.{ .property = "text-wrap", .value = "pretty" }}) },

    // ── Word Break ───────────────────────────────────────────────────────
    .{ "break-normal", d(&.{
        .{ .property = "overflow-wrap", .value = "normal" },
        .{ .property = "word-break", .value = "normal" },
    }) },
    .{ "break-words", d(&.{.{ .property = "overflow-wrap", .value = "break-word" }}) },
    .{ "break-all", d(&.{.{ .property = "word-break", .value = "break-all" }}) },
    .{ "break-keep", d(&.{.{ .property = "word-break", .value = "keep-all" }}) },

    // ── Whitespace ───────────────────────────────────────────────────────
    .{ "whitespace-normal", d(&.{.{ .property = "white-space", .value = "normal" }}) },
    .{ "whitespace-nowrap", d(&.{.{ .property = "white-space", .value = "nowrap" }}) },
    .{ "whitespace-pre", d(&.{.{ .property = "white-space", .value = "pre" }}) },
    .{ "whitespace-pre-line", d(&.{.{ .property = "white-space", .value = "pre-line" }}) },
    .{ "whitespace-pre-wrap", d(&.{.{ .property = "white-space", .value = "pre-wrap" }}) },
    .{ "whitespace-break-spaces", d(&.{.{ .property = "white-space", .value = "break-spaces" }}) },

    // ── List Style Position ──────────────────────────────────────────────
    .{ "list-inside", d(&.{.{ .property = "list-style-position", .value = "inside" }}) },
    .{ "list-outside", d(&.{.{ .property = "list-style-position", .value = "outside" }}) },

    // ── List Style Type ──────────────────────────────────────────────────
    .{ "list-none", d(&.{.{ .property = "list-style-type", .value = "none" }}) },
    .{ "list-disc", d(&.{.{ .property = "list-style-type", .value = "disc" }}) },
    .{ "list-decimal", d(&.{.{ .property = "list-style-type", .value = "decimal" }}) },

    // ── Border Style ─────────────────────────────────────────────────────
    .{ "border-solid", d(&.{.{ .property = "border-style", .value = "solid" }}) },
    .{ "border-dashed", d(&.{.{ .property = "border-style", .value = "dashed" }}) },
    .{ "border-dotted", d(&.{.{ .property = "border-style", .value = "dotted" }}) },
    .{ "border-double", d(&.{.{ .property = "border-style", .value = "double" }}) },
    .{ "border-hidden", d(&.{.{ .property = "border-style", .value = "hidden" }}) },
    .{ "border-none", d(&.{.{ .property = "border-style", .value = "none" }}) },

    // ── Table Layout ─────────────────────────────────────────────────────
    .{ "table-auto", d(&.{.{ .property = "table-layout", .value = "auto" }}) },
    .{ "table-fixed", d(&.{.{ .property = "table-layout", .value = "fixed" }}) },

    // ── Border Collapse ──────────────────────────────────────────────────
    .{ "border-collapse", d(&.{.{ .property = "border-collapse", .value = "collapse" }}) },
    .{ "border-separate", d(&.{.{ .property = "border-collapse", .value = "separate" }}) },

    // ── Appearance ───────────────────────────────────────────────────────
    .{ "appearance-none", d(&.{.{ .property = "appearance", .value = "none" }}) },
    .{ "appearance-auto", d(&.{.{ .property = "appearance", .value = "auto" }}) },

    // ── Cursor ───────────────────────────────────────────────────────────
    .{ "cursor-auto", d(&.{.{ .property = "cursor", .value = "auto" }}) },
    .{ "cursor-default", d(&.{.{ .property = "cursor", .value = "default" }}) },
    .{ "cursor-pointer", d(&.{.{ .property = "cursor", .value = "pointer" }}) },
    .{ "cursor-wait", d(&.{.{ .property = "cursor", .value = "wait" }}) },
    .{ "cursor-text", d(&.{.{ .property = "cursor", .value = "text" }}) },
    .{ "cursor-move", d(&.{.{ .property = "cursor", .value = "move" }}) },
    .{ "cursor-help", d(&.{.{ .property = "cursor", .value = "help" }}) },
    .{ "cursor-not-allowed", d(&.{.{ .property = "cursor", .value = "not-allowed" }}) },
    .{ "cursor-none", d(&.{.{ .property = "cursor", .value = "none" }}) },
    .{ "cursor-context-menu", d(&.{.{ .property = "cursor", .value = "context-menu" }}) },
    .{ "cursor-progress", d(&.{.{ .property = "cursor", .value = "progress" }}) },
    .{ "cursor-cell", d(&.{.{ .property = "cursor", .value = "cell" }}) },
    .{ "cursor-crosshair", d(&.{.{ .property = "cursor", .value = "crosshair" }}) },
    .{ "cursor-vertical-text", d(&.{.{ .property = "cursor", .value = "vertical-text" }}) },
    .{ "cursor-alias", d(&.{.{ .property = "cursor", .value = "alias" }}) },
    .{ "cursor-copy", d(&.{.{ .property = "cursor", .value = "copy" }}) },
    .{ "cursor-no-drop", d(&.{.{ .property = "cursor", .value = "no-drop" }}) },
    .{ "cursor-grab", d(&.{.{ .property = "cursor", .value = "grab" }}) },
    .{ "cursor-grabbing", d(&.{.{ .property = "cursor", .value = "grabbing" }}) },
    .{ "cursor-all-scroll", d(&.{.{ .property = "cursor", .value = "all-scroll" }}) },
    .{ "cursor-col-resize", d(&.{.{ .property = "cursor", .value = "col-resize" }}) },
    .{ "cursor-row-resize", d(&.{.{ .property = "cursor", .value = "row-resize" }}) },
    .{ "cursor-n-resize", d(&.{.{ .property = "cursor", .value = "n-resize" }}) },
    .{ "cursor-e-resize", d(&.{.{ .property = "cursor", .value = "e-resize" }}) },
    .{ "cursor-s-resize", d(&.{.{ .property = "cursor", .value = "s-resize" }}) },
    .{ "cursor-w-resize", d(&.{.{ .property = "cursor", .value = "w-resize" }}) },
    .{ "cursor-ne-resize", d(&.{.{ .property = "cursor", .value = "ne-resize" }}) },
    .{ "cursor-nw-resize", d(&.{.{ .property = "cursor", .value = "nw-resize" }}) },
    .{ "cursor-se-resize", d(&.{.{ .property = "cursor", .value = "se-resize" }}) },
    .{ "cursor-sw-resize", d(&.{.{ .property = "cursor", .value = "sw-resize" }}) },
    .{ "cursor-ew-resize", d(&.{.{ .property = "cursor", .value = "ew-resize" }}) },
    .{ "cursor-ns-resize", d(&.{.{ .property = "cursor", .value = "ns-resize" }}) },
    .{ "cursor-nesw-resize", d(&.{.{ .property = "cursor", .value = "nesw-resize" }}) },
    .{ "cursor-nwse-resize", d(&.{.{ .property = "cursor", .value = "nwse-resize" }}) },
    .{ "cursor-zoom-in", d(&.{.{ .property = "cursor", .value = "zoom-in" }}) },
    .{ "cursor-zoom-out", d(&.{.{ .property = "cursor", .value = "zoom-out" }}) },

    // ── Pointer Events ───────────────────────────────────────────────────
    .{ "pointer-events-none", d(&.{.{ .property = "pointer-events", .value = "none" }}) },
    .{ "pointer-events-auto", d(&.{.{ .property = "pointer-events", .value = "auto" }}) },

    // ── Resize ───────────────────────────────────────────────────────────
    .{ "resize-none", d(&.{.{ .property = "resize", .value = "none" }}) },
    .{ "resize", d(&.{.{ .property = "resize", .value = "both" }}) },
    .{ "resize-x", d(&.{.{ .property = "resize", .value = "horizontal" }}) },
    .{ "resize-y", d(&.{.{ .property = "resize", .value = "vertical" }}) },

    // ── Scroll Behavior ──────────────────────────────────────────────────
    .{ "scroll-auto", d(&.{.{ .property = "scroll-behavior", .value = "auto" }}) },
    .{ "scroll-smooth", d(&.{.{ .property = "scroll-behavior", .value = "smooth" }}) },

    // ── Scroll Snap Align ────────────────────────────────────────────────
    .{ "snap-start", d(&.{.{ .property = "scroll-snap-align", .value = "start" }}) },
    .{ "snap-end", d(&.{.{ .property = "scroll-snap-align", .value = "end" }}) },
    .{ "snap-center", d(&.{.{ .property = "scroll-snap-align", .value = "center" }}) },
    .{ "snap-align-none", d(&.{.{ .property = "scroll-snap-align", .value = "none" }}) },

    // ── Scroll Snap Stop ─────────────────────────────────────────────────
    .{ "snap-normal", d(&.{.{ .property = "scroll-snap-stop", .value = "normal" }}) },
    .{ "snap-always", d(&.{.{ .property = "scroll-snap-stop", .value = "always" }}) },

    // ── Scroll Snap Type ─────────────────────────────────────────────────
    .{ "snap-none", d(&.{.{ .property = "scroll-snap-type", .value = "none" }}) },
    .{ "snap-x", d(&.{.{ .property = "scroll-snap-type", .value = "x var(--tw-scroll-snap-strictness)" }}) },
    .{ "snap-y", d(&.{.{ .property = "scroll-snap-type", .value = "y var(--tw-scroll-snap-strictness)" }}) },
    .{ "snap-both", d(&.{.{ .property = "scroll-snap-type", .value = "both var(--tw-scroll-snap-strictness)" }}) },
    .{ "snap-mandatory", d(&.{.{ .property = "--tw-scroll-snap-strictness", .value = "mandatory" }}) },
    .{ "snap-proximity", d(&.{.{ .property = "--tw-scroll-snap-strictness", .value = "proximity" }}) },

    // ── Touch Action ─────────────────────────────────────────────────────
    .{ "touch-auto", d(&.{.{ .property = "touch-action", .value = "auto" }}) },
    .{ "touch-none", d(&.{.{ .property = "touch-action", .value = "none" }}) },
    .{ "touch-pan-x", d(&.{.{ .property = "touch-action", .value = "pan-x" }}) },
    .{ "touch-pan-left", d(&.{.{ .property = "touch-action", .value = "pan-left" }}) },
    .{ "touch-pan-right", d(&.{.{ .property = "touch-action", .value = "pan-right" }}) },
    .{ "touch-pan-y", d(&.{.{ .property = "touch-action", .value = "pan-y" }}) },
    .{ "touch-pan-up", d(&.{.{ .property = "touch-action", .value = "pan-up" }}) },
    .{ "touch-pan-down", d(&.{.{ .property = "touch-action", .value = "pan-down" }}) },
    .{ "touch-pinch-zoom", d(&.{.{ .property = "touch-action", .value = "pinch-zoom" }}) },
    .{ "touch-manipulation", d(&.{.{ .property = "touch-action", .value = "manipulation" }}) },

    // ── User Select ──────────────────────────────────────────────────────
    .{ "select-none", d(&.{.{ .property = "user-select", .value = "none" }}) },
    .{ "select-text", d(&.{.{ .property = "user-select", .value = "text" }}) },
    .{ "select-all", d(&.{.{ .property = "user-select", .value = "all" }}) },
    .{ "select-auto", d(&.{.{ .property = "user-select", .value = "auto" }}) },

    // ── Will Change ──────────────────────────────────────────────────────
    .{ "will-change-auto", d(&.{.{ .property = "will-change", .value = "auto" }}) },
    .{ "will-change-scroll", d(&.{.{ .property = "will-change", .value = "scroll-position" }}) },
    .{ "will-change-contents", d(&.{.{ .property = "will-change", .value = "contents" }}) },
    .{ "will-change-transform", d(&.{.{ .property = "will-change", .value = "transform" }}) },

    // ── Screen Reader ────────────────────────────────────────────────────
    .{ "sr-only", d(&.{
        .{ .property = "position", .value = "absolute" },
        .{ .property = "width", .value = "1px" },
        .{ .property = "height", .value = "1px" },
        .{ .property = "padding", .value = "0" },
        .{ .property = "margin", .value = "-1px" },
        .{ .property = "overflow", .value = "hidden" },
        .{ .property = "clip", .value = "rect(0,0,0,0)" },
        .{ .property = "white-space", .value = "nowrap" },
        .{ .property = "border-width", .value = "0" },
    }) },
    .{ "not-sr-only", d(&.{
        .{ .property = "position", .value = "static" },
        .{ .property = "width", .value = "auto" },
        .{ .property = "height", .value = "auto" },
        .{ .property = "padding", .value = "0" },
        .{ .property = "margin", .value = "0" },
        .{ .property = "overflow", .value = "visible" },
        .{ .property = "clip", .value = "auto" },
        .{ .property = "white-space", .value = "normal" },
    }) },

    // ── Transition ───────────────────────────────────────────────────────
    .{ "transition-none", d(&.{.{ .property = "transition-property", .value = "none" }}) },
    .{ "transition-all", d(&.{
        .{ .property = "transition-property", .value = "all" },
        .{ .property = "transition-timing-function", .value = "var(--tw-ease, ease)" },
        .{ .property = "transition-duration", .value = "var(--tw-duration, 0s)" },
    }) },
    .{ "transition", d(&.{
        .{ .property = "transition-property", .value = "color,background-color,border-color,text-decoration-color,fill,stroke,opacity,box-shadow,transform,translate,scale,rotate,filter,backdrop-filter" },
        .{ .property = "transition-timing-function", .value = "var(--tw-ease, ease)" },
        .{ .property = "transition-duration", .value = "var(--tw-duration, 0s)" },
    }) },
    .{ "transition-colors", d(&.{
        .{ .property = "transition-property", .value = "color,background-color,border-color,text-decoration-color,fill,stroke" },
        .{ .property = "transition-timing-function", .value = "var(--tw-ease, ease)" },
        .{ .property = "transition-duration", .value = "var(--tw-duration, 0s)" },
    }) },
    .{ "transition-opacity", d(&.{
        .{ .property = "transition-property", .value = "opacity" },
        .{ .property = "transition-timing-function", .value = "var(--tw-ease, ease)" },
        .{ .property = "transition-duration", .value = "var(--tw-duration, 0s)" },
    }) },
    .{ "transition-shadow", d(&.{
        .{ .property = "transition-property", .value = "box-shadow" },
        .{ .property = "transition-timing-function", .value = "var(--tw-ease, ease)" },
        .{ .property = "transition-duration", .value = "var(--tw-duration, 0s)" },
    }) },
    .{ "transition-transform", d(&.{
        .{ .property = "transition-property", .value = "transform,translate,scale,rotate" },
        .{ .property = "transition-timing-function", .value = "var(--tw-ease, ease)" },
        .{ .property = "transition-duration", .value = "var(--tw-duration, 0s)" },
    }) },

    // ── Outline Style ────────────────────────────────────────────────────
    .{ "outline-none", d(&.{
        .{ .property = "outline", .value = "2px solid transparent" },
        .{ .property = "outline-offset", .value = "2px" },
    }) },
    .{ "outline", d(&.{.{ .property = "outline-style", .value = "solid" }}) },
    .{ "outline-dashed", d(&.{.{ .property = "outline-style", .value = "dashed" }}) },
    .{ "outline-dotted", d(&.{.{ .property = "outline-style", .value = "dotted" }}) },
    .{ "outline-double", d(&.{.{ .property = "outline-style", .value = "double" }}) },

    // ── Mix Blend Mode ───────────────────────────────────────────────────
    .{ "mix-blend-normal", d(&.{.{ .property = "mix-blend-mode", .value = "normal" }}) },
    .{ "mix-blend-multiply", d(&.{.{ .property = "mix-blend-mode", .value = "multiply" }}) },
    .{ "mix-blend-screen", d(&.{.{ .property = "mix-blend-mode", .value = "screen" }}) },
    .{ "mix-blend-overlay", d(&.{.{ .property = "mix-blend-mode", .value = "overlay" }}) },
    .{ "mix-blend-darken", d(&.{.{ .property = "mix-blend-mode", .value = "darken" }}) },
    .{ "mix-blend-lighten", d(&.{.{ .property = "mix-blend-mode", .value = "lighten" }}) },
    .{ "mix-blend-color-dodge", d(&.{.{ .property = "mix-blend-mode", .value = "color-dodge" }}) },
    .{ "mix-blend-color-burn", d(&.{.{ .property = "mix-blend-mode", .value = "color-burn" }}) },
    .{ "mix-blend-hard-light", d(&.{.{ .property = "mix-blend-mode", .value = "hard-light" }}) },
    .{ "mix-blend-soft-light", d(&.{.{ .property = "mix-blend-mode", .value = "soft-light" }}) },
    .{ "mix-blend-difference", d(&.{.{ .property = "mix-blend-mode", .value = "difference" }}) },
    .{ "mix-blend-exclusion", d(&.{.{ .property = "mix-blend-mode", .value = "exclusion" }}) },
    .{ "mix-blend-hue", d(&.{.{ .property = "mix-blend-mode", .value = "hue" }}) },
    .{ "mix-blend-saturation", d(&.{.{ .property = "mix-blend-mode", .value = "saturation" }}) },
    .{ "mix-blend-color", d(&.{.{ .property = "mix-blend-mode", .value = "color" }}) },
    .{ "mix-blend-luminosity", d(&.{.{ .property = "mix-blend-mode", .value = "luminosity" }}) },
    .{ "mix-blend-plus-darker", d(&.{.{ .property = "mix-blend-mode", .value = "plus-darker" }}) },
    .{ "mix-blend-plus-lighter", d(&.{.{ .property = "mix-blend-mode", .value = "plus-lighter" }}) },

    // ── Background Blend Mode ────────────────────────────────────────────
    .{ "bg-blend-normal", d(&.{.{ .property = "background-blend-mode", .value = "normal" }}) },
    .{ "bg-blend-multiply", d(&.{.{ .property = "background-blend-mode", .value = "multiply" }}) },
    .{ "bg-blend-screen", d(&.{.{ .property = "background-blend-mode", .value = "screen" }}) },
    .{ "bg-blend-overlay", d(&.{.{ .property = "background-blend-mode", .value = "overlay" }}) },
    .{ "bg-blend-darken", d(&.{.{ .property = "background-blend-mode", .value = "darken" }}) },
    .{ "bg-blend-lighten", d(&.{.{ .property = "background-blend-mode", .value = "lighten" }}) },
    .{ "bg-blend-color-dodge", d(&.{.{ .property = "background-blend-mode", .value = "color-dodge" }}) },
    .{ "bg-blend-color-burn", d(&.{.{ .property = "background-blend-mode", .value = "color-burn" }}) },
    .{ "bg-blend-hard-light", d(&.{.{ .property = "background-blend-mode", .value = "hard-light" }}) },
    .{ "bg-blend-soft-light", d(&.{.{ .property = "background-blend-mode", .value = "soft-light" }}) },
    .{ "bg-blend-difference", d(&.{.{ .property = "background-blend-mode", .value = "difference" }}) },
    .{ "bg-blend-exclusion", d(&.{.{ .property = "background-blend-mode", .value = "exclusion" }}) },
    .{ "bg-blend-hue", d(&.{.{ .property = "background-blend-mode", .value = "hue" }}) },
    .{ "bg-blend-saturation", d(&.{.{ .property = "background-blend-mode", .value = "saturation" }}) },
    .{ "bg-blend-color", d(&.{.{ .property = "background-blend-mode", .value = "color" }}) },
    .{ "bg-blend-luminosity", d(&.{.{ .property = "background-blend-mode", .value = "luminosity" }}) },

    // ── Background Attachment ────────────────────────────────────────────
    .{ "bg-fixed", d(&.{.{ .property = "background-attachment", .value = "fixed" }}) },
    .{ "bg-local", d(&.{.{ .property = "background-attachment", .value = "local" }}) },
    .{ "bg-scroll", d(&.{.{ .property = "background-attachment", .value = "scroll" }}) },

    // ── Background Clip ──────────────────────────────────────────────────
    .{ "bg-clip-border", d(&.{.{ .property = "background-clip", .value = "border-box" }}) },
    .{ "bg-clip-padding", d(&.{.{ .property = "background-clip", .value = "padding-box" }}) },
    .{ "bg-clip-content", d(&.{.{ .property = "background-clip", .value = "content-box" }}) },
    .{ "bg-clip-text", d(&.{.{ .property = "background-clip", .value = "text" }}) },

    // ── Background Origin ────────────────────────────────────────────────
    .{ "bg-origin-border", d(&.{.{ .property = "background-origin", .value = "border-box" }}) },
    .{ "bg-origin-padding", d(&.{.{ .property = "background-origin", .value = "padding-box" }}) },
    .{ "bg-origin-content", d(&.{.{ .property = "background-origin", .value = "content-box" }}) },

    // ── Background Repeat ────────────────────────────────────────────────
    .{ "bg-repeat", d(&.{.{ .property = "background-repeat", .value = "repeat" }}) },
    .{ "bg-no-repeat", d(&.{.{ .property = "background-repeat", .value = "no-repeat" }}) },
    .{ "bg-repeat-x", d(&.{.{ .property = "background-repeat", .value = "repeat-x" }}) },
    .{ "bg-repeat-y", d(&.{.{ .property = "background-repeat", .value = "repeat-y" }}) },
    .{ "bg-repeat-round", d(&.{.{ .property = "background-repeat", .value = "round" }}) },
    .{ "bg-repeat-space", d(&.{.{ .property = "background-repeat", .value = "space" }}) },

    // ── Background Size ──────────────────────────────────────────────────
    .{ "bg-auto", d(&.{.{ .property = "background-size", .value = "auto" }}) },
    .{ "bg-cover", d(&.{.{ .property = "background-size", .value = "cover" }}) },
    .{ "bg-contain", d(&.{.{ .property = "background-size", .value = "contain" }}) },

    // ── Background Position ──────────────────────────────────────────────
    .{ "bg-bottom", d(&.{.{ .property = "background-position", .value = "bottom" }}) },
    .{ "bg-center", d(&.{.{ .property = "background-position", .value = "center" }}) },
    .{ "bg-left", d(&.{.{ .property = "background-position", .value = "left" }}) },
    .{ "bg-left-bottom", d(&.{.{ .property = "background-position", .value = "left bottom" }}) },
    .{ "bg-left-top", d(&.{.{ .property = "background-position", .value = "left top" }}) },
    .{ "bg-right", d(&.{.{ .property = "background-position", .value = "right" }}) },
    .{ "bg-right-bottom", d(&.{.{ .property = "background-position", .value = "right bottom" }}) },
    .{ "bg-right-top", d(&.{.{ .property = "background-position", .value = "right top" }}) },
    .{ "bg-top", d(&.{.{ .property = "background-position", .value = "top" }}) },

    // ── Transform Origin ─────────────────────────────────────────────────
    .{ "origin-center", d(&.{.{ .property = "transform-origin", .value = "center" }}) },
    .{ "origin-top", d(&.{.{ .property = "transform-origin", .value = "top" }}) },
    .{ "origin-top-right", d(&.{.{ .property = "transform-origin", .value = "top right" }}) },
    .{ "origin-right", d(&.{.{ .property = "transform-origin", .value = "right" }}) },
    .{ "origin-bottom-right", d(&.{.{ .property = "transform-origin", .value = "bottom right" }}) },
    .{ "origin-bottom", d(&.{.{ .property = "transform-origin", .value = "bottom" }}) },
    .{ "origin-bottom-left", d(&.{.{ .property = "transform-origin", .value = "bottom left" }}) },
    .{ "origin-left", d(&.{.{ .property = "transform-origin", .value = "left" }}) },
    .{ "origin-top-left", d(&.{.{ .property = "transform-origin", .value = "top left" }}) },

    // ── Vertical Align ───────────────────────────────────────────────────
    .{ "align-baseline", d(&.{.{ .property = "vertical-align", .value = "baseline" }}) },
    .{ "align-top", d(&.{.{ .property = "vertical-align", .value = "top" }}) },
    .{ "align-middle", d(&.{.{ .property = "vertical-align", .value = "middle" }}) },
    .{ "align-bottom", d(&.{.{ .property = "vertical-align", .value = "bottom" }}) },
    .{ "align-text-top", d(&.{.{ .property = "vertical-align", .value = "text-top" }}) },
    .{ "align-text-bottom", d(&.{.{ .property = "vertical-align", .value = "text-bottom" }}) },
    .{ "align-sub", d(&.{.{ .property = "vertical-align", .value = "sub" }}) },
    .{ "align-super", d(&.{.{ .property = "vertical-align", .value = "super" }}) },

    // ── Hyphens ──────────────────────────────────────────────────────────
    .{ "hyphens-none", d(&.{.{ .property = "hyphens", .value = "none" }}) },
    .{ "hyphens-manual", d(&.{.{ .property = "hyphens", .value = "manual" }}) },
    .{ "hyphens-auto", d(&.{.{ .property = "hyphens", .value = "auto" }}) },

    // ── Columns ──────────────────────────────────────────────────────────
    .{ "columns-auto", d(&.{.{ .property = "columns", .value = "auto" }}) },

    // ── Break Before ─────────────────────────────────────────────────────
    .{ "break-before-auto", d(&.{.{ .property = "break-before", .value = "auto" }}) },
    .{ "break-before-avoid", d(&.{.{ .property = "break-before", .value = "avoid" }}) },
    .{ "break-before-all", d(&.{.{ .property = "break-before", .value = "all" }}) },
    .{ "break-before-avoid-page", d(&.{.{ .property = "break-before", .value = "avoid-page" }}) },
    .{ "break-before-page", d(&.{.{ .property = "break-before", .value = "page" }}) },
    .{ "break-before-left", d(&.{.{ .property = "break-before", .value = "left" }}) },
    .{ "break-before-right", d(&.{.{ .property = "break-before", .value = "right" }}) },
    .{ "break-before-column", d(&.{.{ .property = "break-before", .value = "column" }}) },

    // ── Break After ──────────────────────────────────────────────────────
    .{ "break-after-auto", d(&.{.{ .property = "break-after", .value = "auto" }}) },
    .{ "break-after-avoid", d(&.{.{ .property = "break-after", .value = "avoid" }}) },
    .{ "break-after-all", d(&.{.{ .property = "break-after", .value = "all" }}) },
    .{ "break-after-avoid-page", d(&.{.{ .property = "break-after", .value = "avoid-page" }}) },
    .{ "break-after-page", d(&.{.{ .property = "break-after", .value = "page" }}) },
    .{ "break-after-left", d(&.{.{ .property = "break-after", .value = "left" }}) },
    .{ "break-after-right", d(&.{.{ .property = "break-after", .value = "right" }}) },
    .{ "break-after-column", d(&.{.{ .property = "break-after", .value = "column" }}) },

    // ── Break Inside ─────────────────────────────────────────────────────
    .{ "break-inside-auto", d(&.{.{ .property = "break-inside", .value = "auto" }}) },
    .{ "break-inside-avoid", d(&.{.{ .property = "break-inside", .value = "avoid" }}) },
    .{ "break-inside-avoid-page", d(&.{.{ .property = "break-inside", .value = "avoid-page" }}) },
    .{ "break-inside-avoid-column", d(&.{.{ .property = "break-inside", .value = "avoid-column" }}) },

    // ── Box Decoration Break ─────────────────────────────────────────────
    .{ "box-decoration-clone", d(&.{.{ .property = "box-decoration-break", .value = "clone" }}) },
    .{ "box-decoration-slice", d(&.{.{ .property = "box-decoration-break", .value = "slice" }}) },

    // ── Object Position ──────────────────────────────────────────────────
    .{ "object-bottom", d(&.{.{ .property = "object-position", .value = "bottom" }}) },
    .{ "object-center", d(&.{.{ .property = "object-position", .value = "center" }}) },
    .{ "object-left", d(&.{.{ .property = "object-position", .value = "left" }}) },
    .{ "object-left-bottom", d(&.{.{ .property = "object-position", .value = "left bottom" }}) },
    .{ "object-left-top", d(&.{.{ .property = "object-position", .value = "left top" }}) },
    .{ "object-right", d(&.{.{ .property = "object-position", .value = "right" }}) },
    .{ "object-right-bottom", d(&.{.{ .property = "object-position", .value = "right bottom" }}) },
    .{ "object-right-top", d(&.{.{ .property = "object-position", .value = "right top" }}) },
    .{ "object-top", d(&.{.{ .property = "object-position", .value = "top" }}) },

    // ── Inset ────────────────────────────────────────────────────────────
    .{ "inset-auto", d(&.{
        .{ .property = "inset", .value = "auto" },
    }) },
    .{ "inset-x-auto", d(&.{
        .{ .property = "left", .value = "auto" },
        .{ .property = "right", .value = "auto" },
    }) },
    .{ "inset-y-auto", d(&.{
        .{ .property = "top", .value = "auto" },
        .{ .property = "bottom", .value = "auto" },
    }) },
    .{ "top-auto", d(&.{.{ .property = "top", .value = "auto" }}) },
    .{ "right-auto", d(&.{.{ .property = "right", .value = "auto" }}) },
    .{ "bottom-auto", d(&.{.{ .property = "bottom", .value = "auto" }}) },
    .{ "left-auto", d(&.{.{ .property = "left", .value = "auto" }}) },
    .{ "start-auto", d(&.{.{ .property = "inset-inline-start", .value = "auto" }}) },
    .{ "end-auto", d(&.{.{ .property = "inset-inline-end", .value = "auto" }}) },

    // ── Z-Index ──────────────────────────────────────────────────────────
    .{ "z-auto", d(&.{.{ .property = "z-index", .value = "auto" }}) },

    // ── Basis ────────────────────────────────────────────────────────────
    .{ "basis-auto", d(&.{.{ .property = "flex-basis", .value = "auto" }}) },
    .{ "basis-full", d(&.{.{ .property = "flex-basis", .value = "100%" }}) },

    // ── Width / Height auto/full/screen/min/max/fit ──────────────────────
    .{ "w-auto", d(&.{.{ .property = "width", .value = "auto" }}) },
    .{ "w-full", d(&.{.{ .property = "width", .value = "100%" }}) },
    .{ "w-screen", d(&.{.{ .property = "width", .value = "100vw" }}) },
    .{ "w-svw", d(&.{.{ .property = "width", .value = "100svw" }}) },
    .{ "w-lvw", d(&.{.{ .property = "width", .value = "100lvw" }}) },
    .{ "w-dvw", d(&.{.{ .property = "width", .value = "100dvw" }}) },
    .{ "w-min", d(&.{.{ .property = "width", .value = "min-content" }}) },
    .{ "w-max", d(&.{.{ .property = "width", .value = "max-content" }}) },
    .{ "w-fit", d(&.{.{ .property = "width", .value = "fit-content" }}) },
    .{ "min-w-full", d(&.{.{ .property = "min-width", .value = "100%" }}) },
    .{ "min-w-min", d(&.{.{ .property = "min-width", .value = "min-content" }}) },
    .{ "min-w-max", d(&.{.{ .property = "min-width", .value = "max-content" }}) },
    .{ "min-w-fit", d(&.{.{ .property = "min-width", .value = "fit-content" }}) },
    .{ "max-w-full", d(&.{.{ .property = "max-width", .value = "100%" }}) },
    .{ "max-w-min", d(&.{.{ .property = "max-width", .value = "min-content" }}) },
    .{ "max-w-max", d(&.{.{ .property = "max-width", .value = "max-content" }}) },
    .{ "max-w-fit", d(&.{.{ .property = "max-width", .value = "fit-content" }}) },
    .{ "max-w-none", d(&.{.{ .property = "max-width", .value = "none" }}) },
    .{ "max-w-prose", d(&.{.{ .property = "max-width", .value = "65ch" }}) },
    .{ "h-auto", d(&.{.{ .property = "height", .value = "auto" }}) },
    .{ "h-full", d(&.{.{ .property = "height", .value = "100%" }}) },
    .{ "h-screen", d(&.{.{ .property = "height", .value = "100vh" }}) },
    .{ "h-svh", d(&.{.{ .property = "height", .value = "100svh" }}) },
    .{ "h-lvh", d(&.{.{ .property = "height", .value = "100lvh" }}) },
    .{ "h-dvh", d(&.{.{ .property = "height", .value = "100dvh" }}) },
    .{ "h-min", d(&.{.{ .property = "height", .value = "min-content" }}) },
    .{ "h-max", d(&.{.{ .property = "height", .value = "max-content" }}) },
    .{ "h-fit", d(&.{.{ .property = "height", .value = "fit-content" }}) },
    .{ "min-h-full", d(&.{.{ .property = "min-height", .value = "100%" }}) },
    .{ "min-h-screen", d(&.{.{ .property = "min-height", .value = "100vh" }}) },
    .{ "min-h-svh", d(&.{.{ .property = "min-height", .value = "100svh" }}) },
    .{ "min-h-lvh", d(&.{.{ .property = "min-height", .value = "100lvh" }}) },
    .{ "min-h-dvh", d(&.{.{ .property = "min-height", .value = "100dvh" }}) },
    .{ "min-h-min", d(&.{.{ .property = "min-height", .value = "min-content" }}) },
    .{ "min-h-max", d(&.{.{ .property = "min-height", .value = "max-content" }}) },
    .{ "min-h-fit", d(&.{.{ .property = "min-height", .value = "fit-content" }}) },
    .{ "max-h-full", d(&.{.{ .property = "max-height", .value = "100%" }}) },
    .{ "max-h-screen", d(&.{.{ .property = "max-height", .value = "100vh" }}) },
    .{ "max-h-svh", d(&.{.{ .property = "max-height", .value = "100svh" }}) },
    .{ "max-h-lvh", d(&.{.{ .property = "max-height", .value = "100lvh" }}) },
    .{ "max-h-dvh", d(&.{.{ .property = "max-height", .value = "100dvh" }}) },
    .{ "max-h-min", d(&.{.{ .property = "max-height", .value = "min-content" }}) },
    .{ "max-h-max", d(&.{.{ .property = "max-height", .value = "max-content" }}) },
    .{ "max-h-fit", d(&.{.{ .property = "max-height", .value = "fit-content" }}) },
    .{ "max-h-none", d(&.{.{ .property = "max-height", .value = "none" }}) },
    .{ "size-auto", d(&.{
        .{ .property = "width", .value = "auto" },
        .{ .property = "height", .value = "auto" },
    }) },
    .{ "size-full", d(&.{
        .{ .property = "width", .value = "100%" },
        .{ .property = "height", .value = "100%" },
    }) },
    .{ "size-min", d(&.{
        .{ .property = "width", .value = "min-content" },
        .{ .property = "height", .value = "min-content" },
    }) },
    .{ "size-max", d(&.{
        .{ .property = "width", .value = "max-content" },
        .{ .property = "height", .value = "max-content" },
    }) },
    .{ "size-fit", d(&.{
        .{ .property = "width", .value = "fit-content" },
        .{ .property = "height", .value = "fit-content" },
    }) },

    // ── Gap ──────────────────────────────────────────────────────────────
    .{ "gap-x-0", d(&.{.{ .property = "column-gap", .value = "0px" }}) },
    .{ "gap-y-0", d(&.{.{ .property = "row-gap", .value = "0px" }}) },
    .{ "gap-0", d(&.{.{ .property = "gap", .value = "0px" }}) },

    // ── Space (margin-based) ─────────────────────────────────────────────
    // These are special: they use the > :not(:last-child) selector pattern.
    // For now, we store the declarations; the selector logic is handled in main.zig.

    // ── Aspect Ratio ─────────────────────────────────────────────────────
    .{ "aspect-auto", d(&.{.{ .property = "aspect-ratio", .value = "auto" }}) },
    .{ "aspect-square", d(&.{.{ .property = "aspect-ratio", .value = "1/1" }}) },
    .{ "aspect-video", d(&.{.{ .property = "aspect-ratio", .value = "16/9" }}) },

    // ── Container ────────────────────────────────────────────────────────
    .{ "container", d(&.{.{ .property = "width", .value = "100%" }}) },

    // ── Content ──────────────────────────────────────────────────────────
    .{ "content-none", d(&.{.{ .property = "content", .value = "none" }}) },

    // ── Forced Color Adjust ──────────────────────────────────────────────
    .{ "forced-color-adjust-auto", d(&.{.{ .property = "forced-color-adjust", .value = "auto" }}) },
    .{ "forced-color-adjust-none", d(&.{.{ .property = "forced-color-adjust", .value = "none" }}) },

    // ── Accent Color ─────────────────────────────────────────────────────
    .{ "accent-auto", d(&.{.{ .property = "accent-color", .value = "auto" }}) },

    // ── Caret Color ──────────────────────────────────────────────────────
    .{ "caret-transparent", d(&.{.{ .property = "caret-color", .value = "transparent" }}) },

    // ── Text Decoration Style ────────────────────────────────────────────
    .{ "decoration-solid", d(&.{.{ .property = "text-decoration-style", .value = "solid" }}) },
    .{ "decoration-double", d(&.{.{ .property = "text-decoration-style", .value = "double" }}) },
    .{ "decoration-dotted", d(&.{.{ .property = "text-decoration-style", .value = "dotted" }}) },
    .{ "decoration-dashed", d(&.{.{ .property = "text-decoration-style", .value = "dashed" }}) },
    .{ "decoration-wavy", d(&.{.{ .property = "text-decoration-style", .value = "wavy" }}) },

    // ── Stroke ───────────────────────────────────────────────────────────
    .{ "stroke-none", d(&.{.{ .property = "stroke", .value = "none" }}) },

    // ── Fill ─────────────────────────────────────────────────────────────
    .{ "fill-none", d(&.{.{ .property = "fill", .value = "none" }}) },

    // ── Table display variants ───────────────────────────────────────────
    .{ "table-caption", d(&.{.{ .property = "display", .value = "table-caption" }}) },
    .{ "table-column", d(&.{.{ .property = "display", .value = "table-column" }}) },
    .{ "table-column-group", d(&.{.{ .property = "display", .value = "table-column-group" }}) },
    .{ "table-footer-group", d(&.{.{ .property = "display", .value = "table-footer-group" }}) },
    .{ "table-header-group", d(&.{.{ .property = "display", .value = "table-header-group" }}) },
    .{ "table-row-group", d(&.{.{ .property = "display", .value = "table-row-group" }}) },

    // ── Caption Side ─────────────────────────────────────────────────────
    .{ "caption-top", d(&.{.{ .property = "caption-side", .value = "top" }}) },
    .{ "caption-bottom", d(&.{.{ .property = "caption-side", .value = "bottom" }}) },

    // ── Transform ────────────────────────────────────────────────────────
    .{ "transform-none", d(&.{.{ .property = "transform", .value = "none" }}) },
    .{ "transform-gpu", d(&.{.{ .property = "--tw-transform", .value = "translate3d(var(--tw-translate-x),var(--tw-translate-y),0) rotate(var(--tw-rotate)) skewX(var(--tw-skew-x)) skewY(var(--tw-skew-y)) scaleX(var(--tw-scale-x)) scaleY(var(--tw-scale-y))" }}) },

    // ── Backface Visibility ──────────────────────────────────────────────
    .{ "backface-visible", d(&.{.{ .property = "backface-visibility", .value = "visible" }}) },
    .{ "backface-hidden", d(&.{.{ .property = "backface-visibility", .value = "hidden" }}) },

    // ── Perspective ──────────────────────────────────────────────────────
    .{ "perspective-none", d(&.{.{ .property = "perspective", .value = "none" }}) },

    // ── Margin auto ──────────────────────────────────────────────────────
    .{ "m-auto", d(&.{.{ .property = "margin", .value = "auto" }}) },
    .{ "mx-auto", d(&.{
        .{ .property = "margin-left", .value = "auto" },
        .{ .property = "margin-right", .value = "auto" },
    }) },
    .{ "my-auto", d(&.{
        .{ .property = "margin-top", .value = "auto" },
        .{ .property = "margin-bottom", .value = "auto" },
    }) },
    .{ "mt-auto", d(&.{.{ .property = "margin-top", .value = "auto" }}) },
    .{ "mr-auto", d(&.{.{ .property = "margin-right", .value = "auto" }}) },
    .{ "mb-auto", d(&.{.{ .property = "margin-bottom", .value = "auto" }}) },
    .{ "ml-auto", d(&.{.{ .property = "margin-left", .value = "auto" }}) },
    .{ "ms-auto", d(&.{.{ .property = "margin-inline-start", .value = "auto" }}) },
    .{ "me-auto", d(&.{.{ .property = "margin-inline-end", .value = "auto" }}) },

    // ── Padding 0 ────────────────────────────────────────────────────────
    .{ "p-0", d(&.{.{ .property = "padding", .value = "0px" }}) },
    .{ "px-0", d(&.{
        .{ .property = "padding-left", .value = "0px" },
        .{ .property = "padding-right", .value = "0px" },
    }) },
    .{ "py-0", d(&.{
        .{ .property = "padding-top", .value = "0px" },
        .{ .property = "padding-bottom", .value = "0px" },
    }) },
    .{ "pt-0", d(&.{.{ .property = "padding-top", .value = "0px" }}) },
    .{ "pr-0", d(&.{.{ .property = "padding-right", .value = "0px" }}) },
    .{ "pb-0", d(&.{.{ .property = "padding-bottom", .value = "0px" }}) },
    .{ "pl-0", d(&.{.{ .property = "padding-left", .value = "0px" }}) },
    .{ "ps-0", d(&.{.{ .property = "padding-inline-start", .value = "0px" }}) },
    .{ "pe-0", d(&.{.{ .property = "padding-inline-end", .value = "0px" }}) },

    // ── Margin 0 ─────────────────────────────────────────────────────────
    .{ "m-0", d(&.{.{ .property = "margin", .value = "0px" }}) },
    .{ "mx-0", d(&.{
        .{ .property = "margin-left", .value = "0px" },
        .{ .property = "margin-right", .value = "0px" },
    }) },
    .{ "my-0", d(&.{
        .{ .property = "margin-top", .value = "0px" },
        .{ .property = "margin-bottom", .value = "0px" },
    }) },
    .{ "mt-0", d(&.{.{ .property = "margin-top", .value = "0px" }}) },
    .{ "mr-0", d(&.{.{ .property = "margin-right", .value = "0px" }}) },
    .{ "mb-0", d(&.{.{ .property = "margin-bottom", .value = "0px" }}) },
    .{ "ml-0", d(&.{.{ .property = "margin-left", .value = "0px" }}) },
    .{ "ms-0", d(&.{.{ .property = "margin-inline-start", .value = "0px" }}) },
    .{ "me-0", d(&.{.{ .property = "margin-inline-end", .value = "0px" }}) },

    // ── Rounded 0 / full / none ──────────────────────────────────────────
    .{ "rounded-none", d(&.{.{ .property = "border-radius", .value = "0px" }}) },
    .{ "rounded-full", d(&.{.{ .property = "border-radius", .value = "9999px" }}) },

    // ── Border Width 0 ───────────────────────────────────────────────────
    .{ "border-0", d(&.{.{ .property = "border-width", .value = "0px" }}) },
    .{ "border-x-0", d(&.{
        .{ .property = "border-left-width", .value = "0px" },
        .{ .property = "border-right-width", .value = "0px" },
    }) },
    .{ "border-y-0", d(&.{
        .{ .property = "border-top-width", .value = "0px" },
        .{ .property = "border-bottom-width", .value = "0px" },
    }) },
    .{ "border-t-0", d(&.{.{ .property = "border-top-width", .value = "0px" }}) },
    .{ "border-r-0", d(&.{.{ .property = "border-right-width", .value = "0px" }}) },
    .{ "border-b-0", d(&.{.{ .property = "border-bottom-width", .value = "0px" }}) },
    .{ "border-l-0", d(&.{.{ .property = "border-left-width", .value = "0px" }}) },

    // ── Shadow ───────────────────────────────────────────────────────────
    .{ "shadow-none", d(&.{.{ .property = "box-shadow", .value = "0 0 #0000" }}) },

    // ── Opacity ──────────────────────────────────────────────────────────
    .{ "opacity-0", d(&.{.{ .property = "opacity", .value = "0" }}) },
    .{ "opacity-100", d(&.{.{ .property = "opacity", .value = "1" }}) },

    // ── Gradient Direction ───────────────────────────────────────────────
    .{ "bg-none", d(&.{.{ .property = "background-image", .value = "none" }}) },

    // ── Filter ───────────────────────────────────────────────────────────
    .{ "filter-none", d(&.{.{ .property = "filter", .value = "none" }}) },
    .{ "backdrop-filter-none", d(&.{.{ .property = "backdrop-filter", .value = "none" }}) },

    // ── Color scheme ─────────────────────────────────────────────────────
    .{ "scheme-normal", d(&.{.{ .property = "color-scheme", .value = "normal" }}) },
    .{ "scheme-light", d(&.{.{ .property = "color-scheme", .value = "only light" }}) },
    .{ "scheme-dark", d(&.{.{ .property = "color-scheme", .value = "only dark" }}) },
    .{ "scheme-light-dark", d(&.{.{ .property = "color-scheme", .value = "light dark" }}) },
});

pub fn lookup(name: []const u8) ?[]const Declaration {
    return static_map.get(name);
}

// ── Tests ────────────────────────────────────────────────────────────────────

test "lookup display utilities" {
    {
        const decls = lookup("flex").?;
        try std.testing.expectEqual(@as(usize, 1), decls.len);
        try std.testing.expectEqualStrings("display", decls[0].property);
        try std.testing.expectEqualStrings("flex", decls[0].value);
    }
    {
        const decls = lookup("hidden").?;
        try std.testing.expectEqual(@as(usize, 1), decls.len);
        try std.testing.expectEqualStrings("display", decls[0].property);
        try std.testing.expectEqualStrings("none", decls[0].value);
    }
    {
        const decls = lookup("inline-flex").?;
        try std.testing.expectEqualStrings("inline-flex", decls[0].value);
    }
}

test "lookup position utilities" {
    {
        const decls = lookup("absolute").?;
        try std.testing.expectEqualStrings("position", decls[0].property);
        try std.testing.expectEqualStrings("absolute", decls[0].value);
    }
    {
        const decls = lookup("sticky").?;
        try std.testing.expectEqualStrings("position", decls[0].property);
        try std.testing.expectEqualStrings("sticky", decls[0].value);
    }
}

test "lookup multi-declaration utilities" {
    {
        const decls = lookup("antialiased").?;
        try std.testing.expectEqual(@as(usize, 2), decls.len);
        try std.testing.expectEqualStrings("-webkit-font-smoothing", decls[0].property);
        try std.testing.expectEqualStrings("antialiased", decls[0].value);
        try std.testing.expectEqualStrings("-moz-osx-font-smoothing", decls[1].property);
        try std.testing.expectEqualStrings("grayscale", decls[1].value);
    }
    {
        const decls = lookup("truncate").?;
        try std.testing.expectEqual(@as(usize, 3), decls.len);
    }
    {
        const decls = lookup("sr-only").?;
        try std.testing.expectEqual(@as(usize, 9), decls.len);
    }
}

test "lookup transition utilities" {
    {
        const decls = lookup("transition-all").?;
        try std.testing.expectEqual(@as(usize, 3), decls.len);
        try std.testing.expectEqualStrings("transition-property", decls[0].property);
        try std.testing.expectEqualStrings("all", decls[0].value);
    }
    {
        const decls = lookup("transition-none").?;
        try std.testing.expectEqual(@as(usize, 1), decls.len);
        try std.testing.expectEqualStrings("none", decls[0].value);
    }
}

test "lookup returns null for unknown utility" {
    try std.testing.expect(lookup("nonexistent") == null);
    try std.testing.expect(lookup("bg-blue-500") == null);
    try std.testing.expect(lookup("p-4") == null);
}

test "lookup cursor utilities" {
    {
        const decls = lookup("cursor-pointer").?;
        try std.testing.expectEqualStrings("cursor", decls[0].property);
        try std.testing.expectEqualStrings("pointer", decls[0].value);
    }
    {
        const decls = lookup("cursor-not-allowed").?;
        try std.testing.expectEqualStrings("not-allowed", decls[0].value);
    }
}

test "lookup overflow utilities" {
    {
        const decls = lookup("overflow-hidden").?;
        try std.testing.expectEqualStrings("overflow", decls[0].property);
        try std.testing.expectEqualStrings("hidden", decls[0].value);
    }
    {
        const decls = lookup("overflow-x-auto").?;
        try std.testing.expectEqualStrings("overflow-x", decls[0].property);
        try std.testing.expectEqualStrings("auto", decls[0].value);
    }
}

test "lookup flex utilities" {
    {
        const decls = lookup("flex-1").?;
        try std.testing.expectEqualStrings("flex", decls[0].property);
        try std.testing.expectEqualStrings("1 1 0%", decls[0].value);
    }
    {
        const decls = lookup("flex-col").?;
        try std.testing.expectEqualStrings("flex-direction", decls[0].property);
        try std.testing.expectEqualStrings("column", decls[0].value);
    }
}

test "lookup border style utilities" {
    const decls = lookup("border-dashed").?;
    try std.testing.expectEqualStrings("border-style", decls[0].property);
    try std.testing.expectEqualStrings("dashed", decls[0].value);
}

test "lookup width/height keyword utilities" {
    {
        const decls = lookup("w-full").?;
        try std.testing.expectEqualStrings("width", decls[0].property);
        try std.testing.expectEqualStrings("100%", decls[0].value);
    }
    {
        const decls = lookup("h-screen").?;
        try std.testing.expectEqualStrings("height", decls[0].property);
        try std.testing.expectEqualStrings("100vh", decls[0].value);
    }
    {
        const decls = lookup("size-full").?;
        try std.testing.expectEqual(@as(usize, 2), decls.len);
        try std.testing.expectEqualStrings("width", decls[0].property);
        try std.testing.expectEqualStrings("100%", decls[0].value);
        try std.testing.expectEqualStrings("height", decls[1].property);
        try std.testing.expectEqualStrings("100%", decls[1].value);
    }
}

test "lookup margin auto utilities" {
    {
        const decls = lookup("mx-auto").?;
        try std.testing.expectEqual(@as(usize, 2), decls.len);
        try std.testing.expectEqualStrings("margin-left", decls[0].property);
        try std.testing.expectEqualStrings("auto", decls[0].value);
    }
    {
        const decls = lookup("m-auto").?;
        try std.testing.expectEqualStrings("margin", decls[0].property);
        try std.testing.expectEqualStrings("auto", decls[0].value);
    }
}
