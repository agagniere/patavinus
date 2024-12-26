const std = @import("std");

const libpq = @cImport({
    @cInclude("libpq-fe.h");
});

const Allocator = std.mem.Allocator;
const PgMap = std.StringArrayHashMapUnmanaged(PgType);
const log = std.log.scoped(.database);

const PostgresError = error{
    BufferInsertFailed,
    ConnectionFailed,
    ConnectionLost,
    InvalidConnectionString,
    AuthenticationFailed,
    QueryFailed,
    InvalidQuery,
    NoSuchTable,
    NoSuchColumn,
    PermissionDenied,
    TransactionBeginFailed,
    TransactionCommitFailed,
    TransactionRollbackFailed,
    TypeMismatch,
    InvalidUTF8,
    NullValue,
    QueryTimeout,
    ConnectionTimeout,
    NetworkError,
    SSLHandshakeFailed,
    ProtocolViolation,
    InvalidMessage,
    OutOfMemory,
    InternalError,
    Cancelled,
};

pub const PgType = union(enum) {
    string: []const u8,
    number: i64,
};

pub const Connection = struct {
    pq: ?*libpq.PGconn,
    last_result: ?*libpq.PGresult,
    is_reading: bool,
    is_reffed: bool,
    result_buffer: PgMap,
    allocator: Allocator,
    format_buffer: [16 * 1024]u8 = [_]u8{0} ** (16 * 1024), //16KB buffer

    pub fn init(allocator: Allocator) Connection {
        return .{
            .pq = null,
            .last_result = null,
            .is_reading = false,
            .is_reffed = false,
            .result_buffer = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Connection) void {
        self.result_buffer.deinit(self.allocator);
        if (self.last_result != null) {
            libpq.PQclear(self.last_result);
        }
        if (self.pq != null) {
            libpq.PQfinish(self.pq);
            self.pq = null;
        }
    }

    /// Use environment variables PGHOST, PGDATABASE, PGUSER, etc
    pub fn connect(self: *Connection) !void {
        self.pq = libpq.PQconnectdb("");
        if (libpq.PQstatus(self.pq) != libpq.CONNECTION_OK) {
            std.log.err("Connection failed: {s}", .{libpq.PQerrorMessage(self.pq)});
            return PostgresError.ConnectionFailed;
        }
        if (true) {
            var infos: [*]const libpq.PQconninfoOption = libpq.PQconninfo(self.pq);

            while (infos[0].keyword != null) {
                log.debug("{s}: {s}", .{ infos[0].keyword, infos[0].val });
                infos += 1;
            }
        }
        log.info("DB Connection success", .{});
    }

    // pub fn exec(self: *@This(), comptime query: []const u8, argv: anytype) !void {
    //     if (self.pq == null) return PostgresError.ConnectionFailed;

    //     @memset(self.format_buffer[0..], 0);
    //     const m_query = try std.fmt.bufPrint(&self.format_buffer, query, argv);

    //     const result = libpq.PQexec(self.pq, @ptrCast(m_query));
    //     if (result == null) {
    //         std.log.err("Exec failed: {s}\n", .{libpq.PQerrorMessage(self.pq)});
    //         return PostgresError.QueryFailed;
    //     }
    //     self.last_result = result;
    // }

    // pub fn getLastResult(self: *@This()) !std.StringArrayHashMap(PgType).Iterator {
    //     const stat = libpq.PQresultStatus(self.last_result);

    //     switch (stat) {
    //         libpq.PGRES_COMMAND_OK => return self.result_buffer.iterator(),
    //         libpq.PGRES_TUPLES_OK => {
    //             const nrows: usize = @intCast(libpq.PQntuples(self.last_result));
    //             const ncols: usize = @intCast(libpq.PQnfields(self.last_result));

    //             // Clear the result buffer to store fresh data
    //             self.result_buffer.clearAndFree();

    //             for (0..nrows) |i| for (0..ncols) |j| {
    //                 const field_name = std.mem.span(libpq.PQfname(self.last_result, @intCast(j)));
    //                 const value = std.mem.span(libpq.PQgetvalue(self.last_result, @intCast(i), @intCast(j)));

    //                 const field_type = libpq.PQftype(self.last_result, @intCast(j));
    //                 var pg_value: PgType = undefined;

    //                 std.debug.print("OID: {}\n", .{field_type});

    //                 pg_value = switch (field_type) {
    //                     20...23, 1700 => PgType{ .number = std.fmt.parseInt(i64, value, 10) catch {
    //                         std.debug.print("Error parsing number for column {s}\n", .{field_name});
    //                         continue;
    //                     } },
    //                     else => PgType{ .string = value },
    //                 };

    //                 self.result_buffer.put(field_name[0..], pg_value) catch {
    //                     return PostgresError.BufferInsertFailed;
    //                 };
    //             };

    //             std.debug.print("Rows: {}, Columns: {}\n", .{ nrows, ncols });
    //             return self.result_buffer.iterator();
    //         },
    //         else => {
    //             const err = libpq.PQresultErrorMessage(self.last_result);
    //             std.debug.print("Query Fatal Error: {s}\n", .{err});
    //             return PostgresError.QueryFailed;
    //         },
    //     }
    // }

    // pub fn getLastErrorMessage(self: *@This()) ?[]const u8 {
    //     if (self.pq != null) {
    //         return std.mem.span(libpq.PQerrorMessage(self.pq));
    //     }
    //     return null;
    // }

    // pub fn serverVersion(self: *@This()) i32 {
    //     return libpq.PQserverVersion(self.pq);
    // }
};
