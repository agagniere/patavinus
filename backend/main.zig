const std = @import("std");
const zap = @import("zap");
const argsParser = @import("args");
const database = @import("database.zig");

fn on_request_verbose(r: zap.Request) void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
    }

    if (r.query) |the_query| {
        std.debug.print("QUERY: {s}\n", .{the_query});
    }
    r.sendBody(@embedFile("not_found.html")) catch return;
}

fn on_request_minimal(r: zap.Request) void {
    r.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>") catch return;
}

const Options = struct {
    directory: []const u8 = ".",
    help: bool = false,

    pub const shorthands = .{ .d = "directory", .h = "help" };
    pub const meta = .{
        .usage_summary = "-d path",
        .full_text = "Never forget where you stored an item",
        .option_docs = .{
            .directory = "Serve this directory, where the frontend is",
            .help = "Print this help",
        },
    };
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const options = try argsParser.parseForCurrentProcess(Options, allocator, .print);
    defer options.deinit();
    if (options.options.help) {
        try argsParser.printHelp(Options, "patavinus", std.io.getStdOut().writer());
        return;
    }

    std.log.info("Serving {s}", .{options.options.directory});

    // var dbconn = database.Connection.init(allocator);
    // defer dbconn.deinit();
    // try dbconn.connect();

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request_verbose,
        .public_folder = options.options.directory,
        .log = true,
        .max_clients = 100,
    });
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
