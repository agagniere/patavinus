const std = @import("std");
const dvui = @import("dvui");
const web = @import("dvuiWebBackend");
const logFn = @import("log.zig").logFn;
const percent_encoding = @import("percent_encoding");

pub const std_options: std.Options = .{
    // Overwrite default log handler
    .logFn = logFn,
};

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

var win: dvui.Window = undefined;
var backend: web = undefined;
var touchPoints: [2]?dvui.Point = [_]?dvui.Point{null} ** 2;
var orig_content_scale: f32 = 1.0;

fn openURL(comptime format: []const u8, args: anytype) !void {
    const formatted = try std.fmt.allocPrint(gpa, format, args);
    defer gpa.free(formatted);
    const encoded = try percent_encoding.encode_alloc(gpa, formatted, .{ .@"/" = .raw, .@"?" = .raw, .@"=" = .raw });
    defer gpa.free(encoded);
    try dvui.openURL(encoded);
}

export fn app_init(platform_ptr: [*]const u8, platform_len: usize) i32 {
    const platform = platform_ptr[0..platform_len];
    dvui.log.debug("platform: {s}", .{platform});
    const mac = if (std.mem.indexOf(u8, platform, "Mac") != null) true else false;

    backend = web.init() catch {
        return 1;
    };
    win = dvui.Window.init(@src(), gpa, backend.backend(), .{ .keybinds = if (mac) .mac else .windows }) catch {
        return 2;
    };

    web.win = &win;

    orig_content_scale = win.content_scale;

    return 0;
}

export fn app_deinit() void {
    win.deinit();
    backend.deinit();
}

export fn app_update() i32 {
    return update() catch |err| {
        std.log.err("{!}", .{err});
        const msg = std.fmt.allocPrint(gpa, "{!}", .{err}) catch "allocPrint OOM";
        defer gpa.free(msg);
        web.wasm.wasm_panic(msg.ptr, msg.len);
        return -1;
    };
}

fn update() !i32 {
    const nstime = win.beginWait(backend.hasEvent());

    try win.begin(nstime);

    try dvui_frame();

    const end_micros = try win.end(.{});

    backend.setCursor(win.cursorRequested());
    backend.textInputRect(win.textInputRequested());

    const wait_event_micros = win.waitTime(end_micros, null);
    return @intCast(@divTrunc(wait_event_micros, 1000));
}

var theme_dark: bool = true;

fn dvui_frame() !void {
    if (theme_dark) {
        win.theme = win.themes.get("Adwaita Dark").?;
    } else {
        win.theme = win.themes.get("Adwaita Light").?;
    }
    var scroll = try dvui.scrollArea(@src(), .{}, .{ .expand = .both, .color_fill = .{ .name = .fill_window } });
    defer scroll.deinit();
    {
        var box = try dvui.box(@src(), .horizontal, .{});
        defer box.deinit();

        if (theme_dark) {
            if (try dvui.button(@src(), "Switch to light mode", .{}, .{}))
                theme_dark = false;
        } else {
            if (try dvui.button(@src(), "Switch to dark mode", .{}, .{}))
                theme_dark = true;
        }
        if (try dvui.button(@src(), "Source", .{}, .{})) {
            try dvui.openURL("https://github.com/agagniere/patavinus");
        }
    }
    if (try dvui.expander(@src(), "Create a new item", .{}, .{ .expand = .horizontal })) {
        {
            var box = try dvui.box(@src(), .horizontal, .{});
            defer box.deinit();

            try dvui.label(@src(), "Name", .{}, .{ .gravity_y = 0.5 });
            var name = try dvui.textEntry(@src(), .{}, .{});
            defer name.deinit();
        }
        {
            try dvui.label(@src(), "Description", .{}, .{});
            var description = try dvui.textEntry(@src(), .{ .multiline = true }, .{ .min_size_content = .{ .w = 500, .h = 50 } });
            defer description.deinit();
        }
    }
    if (try dvui.expander(@src(), "Search an existing item", .{ .default_expanded = true }, .{ .expand = .horizontal })) {
        var box = try dvui.box(@src(), .horizontal, .{});
        defer box.deinit();

        try dvui.label(@src(), "Query", .{}, .{ .gravity_y = 0.5 });
        {
            var name = try dvui.textEntry(@src(), .{}, .{});
            name.deinit();

            if (try dvui.button(@src(), "Search", .{}, .{})) {
                try openURL("/search?query={s}", .{name.getText()});
            }
        }
    }
}
