const std = @import("std");
const zap = @import("zap");
const argsParser = @import("args");
const database = @import("database.zig");

const Options = struct {
    directory: []const u8 = ".",
    verbose: bool = false,
    help: bool = false,

    pub const shorthands = .{ .d = "directory", .v = "verbose", .h = "help" };
    pub const meta = .{
        .usage_summary = "-d path",
        .full_text = "Never forget where you stored an item",
        .option_docs = .{
            .directory = "Serve this directory, where the frontend is",
            .verbose = "Increase logs verbosity",
            .help = "Print this help",
        },
    };
};

fn not_found(r: zap.Request) void {
    r.setStatus(.not_found);
    r.sendBody(@embedFile("not_found.html")) catch return;
}
fn search(r: zap.Request) void {
    r.sendBody("<html><body>Searching</body></html>") catch return;
}

fn display(r: zap.Request) void {
    if (r.query) |q| {
        std.log.debug("query: {s}", .{q});
    }
    r.sendBody("<html><body>Item</body></html>") catch return;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const options = try argsParser.parseForCurrentProcess(Options, allocator, .print);
    defer options.deinit();
    if (options.options.help) {
        try argsParser.printHelp(Options, "patavinus", std.io.getStdOut().writer());
        return;
    }
    if (options.options.verbose)
        zap.enableDebugLog();

    // var dbconn = database.Connection.init(allocator);
    // defer dbconn.deinit();
    // try dbconn.connect();

    var router = zap.Router.init(allocator, .{
        .not_found = not_found,
    });
    defer router.deinit();
    try router.handle_func_unbound("/i", display);
    try router.handle_func_unbound("/search", search);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = router.on_request_handler(),
        .public_folder = options.options.directory,
        .log = options.options.verbose,
        .max_clients = 100,
    });
    try listener.listen();
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
