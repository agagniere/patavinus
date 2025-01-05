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
    r.sendBody(
        \\<main class="h-screen w-full flex flex-col justify-center items-center bg-[#1A2238]">
        \\<h1 class="text-9xl font-extrabold text-white tracking-widest">404</h1>
        \\<div class="bg-[#FF6A3D] px-2 text-sm rounded rotate-12 absolute">
        \\Page Not Found
        \\</div>
        \\<button class="mt-5">
        \\<a
        \\class="relative inline-block text-sm font-medium text-[#FF6A3D] group active:text-orange-500 focus:outline-none focus:ring"
        \\>
        \\<span
        \\class="absolute inset-0 transition-transform translate-x-0.5 translate-y-0.5 bg-[#FF6A3D] group-hover:translate-y-0 group-hover:translate-x-0"
        \\></span>
        \\<span class="relative block px-8 py-3 bg-[#1A2238] border border-current">
        \\<router-link to="/">Go Home</router-link>
        \\</span>
        \\</a>
        \\</button>
        \\</main>
    ) catch return;
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
