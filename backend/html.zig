const std = @import("std");

const Allocator = std.mem.Allocator;
const Dict = std.StringArrayHashMapUnmanaged(?[]u8);
const List = std.ArrayListUnmanaged(Element);
const Map = std.StringArrayHashMapUnmanaged(Node);

const Error = Allocator.Error || error{NoSuchChild};

const Tag = enum { node, ownedLeaf, literalLeaf };

const RenderOptions = struct {
    linebreaks: bool,
    indent: bool,
    depth: u8 = 0,
    nameComments: bool,

    pub const pretty: RenderOptions = .{ .linebreaks = true, .indent = true, .nameComments = true };
    pub const compact: RenderOptions = .{ .linebreaks = false, .indent = false, .nameComments = false };

    pub fn nextDepth(self: RenderOptions) RenderOptions {
        return .{
            .linebreaks = self.linebreaks,
            .indent = self.indent,
            .nameComments = self.nameComments,
            .depth = self.depth + 1,
        };
    }
};

pub const Element = union(Tag) {
    node: Node,
    ownedLeaf: []u8,
    literalLeaf: []const u8,

    pub fn writeTo(self: Element, writer: anytype, options: RenderOptions) !void {
        switch (self) {
            .node => |value| try value.writeTo(writer, options),
            .ownedLeaf, .literalLeaf => |value| {
                if (options.indent)
                    try writer.writeByteNTimes(' ', options.depth);
                try writer.writeAll(value);
                if (options.linebreaks)
                    try writer.writeByte('\n');
            },
        }
    }

    pub fn deinit(self: *Element, allocator: Allocator) void {
        switch (self.*) {
            .node => |*value| value.deinit(allocator),
            .ownedLeaf => |value| allocator.free(value),
            .literalLeaf => {},
        }
    }
};

pub const Node = struct {
    name: []u8,
    attributes: Dict,
    children: List,
    namedChildren: Map,

    pub fn init(allocator: Allocator, name: []const u8) !Node {
        return .{
            .name = try allocator.dupe(u8, name),
            .attributes = .{},
            .children = .{},
            .namedChildren = .{},
        };
    }

    pub fn deinit(self: *Node, allocator: Allocator) void {
        allocator.free(self.name);

        var attributes = self.attributes.iterator();
        while (attributes.next()) |attribute| {
            allocator.free(attribute.key_ptr.*);
            if (attribute.value_ptr.*) |value|
                allocator.free(value);
        }
        self.attributes.deinit(allocator);

        for (self.children.items) |*child|
            child.deinit(allocator);
        self.children.deinit(allocator);

        var children = self.namedChildren.iterator();
        while (children.next()) |child| {
            allocator.free(child.key_ptr.*);
            child.value_ptr.deinit(allocator);
        }
        self.namedChildren.deinit(allocator);
    }

    pub fn addAttribute(self: *Node, allocator: Allocator, attribute: []const u8, value: ?[]const u8) !void {
        try self.attributes.putNoClobber(allocator, try allocator.dupe(u8, attribute), if (value) |v| try allocator.dupe(u8, v) else null);
    }

    pub fn add(self: *Node, allocator: Allocator, element: Element) !void {
        try self.children.append(allocator, element);
    }

    pub fn addTo(self: *Node, allocator: Allocator, path: []const u8, element: Element) Error!void {
        const is_deep = std.mem.indexOfScalar(u8, path, '.');

        if (is_deep) |dot| {
            const has_child = self.namedChildren.getPtr(path[0..dot]);
            if (has_child) |child| {
                try child.addTo(allocator, path[dot + 1 ..], element);
            } else return Error.NoSuchChild;
        } else {
            const has_child = self.namedChildren.getPtr(path);
            if (has_child) |child| {
                try child.add(allocator, element);
            } else return Error.NoSuchChild;
        }
    }

    pub fn set(self: *Node, allocator: Allocator, path: []const u8, node: Node) Error!void {
        const is_deep = std.mem.indexOfScalar(u8, path, '.');

        if (is_deep) |dot| {
            const has_child = self.namedChildren.getPtr(path[0..dot]);
            if (has_child) |child| {
                try child.set(allocator, path[dot + 1 ..], node);
            } else return Error.NoSuchChild;
        } else {
            try self.namedChildren.put(allocator, try allocator.dupe(u8, path), node);
        }
    }

    pub fn writeTo(self: Node, writer: anytype, options: RenderOptions) Allocator.Error!void {
        const multiline = options.linebreaks and (self.namedChildren.count() > 0 or self.children.items.len > 0);

        if (options.indent)
            try writer.writeByteNTimes(' ', options.depth);
        try writer.print("<{s}", .{self.name});
        var attributes = self.attributes.iterator();

        while (attributes.next()) |attribute| {
            try writer.writeByte(' ');
            try writer.writeAll(attribute.key_ptr.*);
            if (attribute.value_ptr.*) |value| {
                try writer.print(
                    \\="{s}"
                , .{value});
            }
        }
        try writer.writeByte('>');
        if (multiline) {
            try writer.writeByte('\n');
        }
        var children = self.namedChildren.iterator();
        while (children.next()) |child| {
            if (options.nameComments) {
                if (options.indent)
                    try writer.writeByteNTimes(' ', options.depth + 1);
                try writer.print("<!-- {s} -->", .{child.key_ptr.*});
                if (options.linebreaks)
                    try writer.writeByte('\n');
            }
            try child.value_ptr.writeTo(writer, options.nextDepth());
        }
        for (self.children.items) |child| {
            try child.writeTo(writer, options.nextDepth());
        }
        if (multiline and options.indent)
            try writer.writeByteNTimes(' ', options.depth);
        try writer.print("</{s}>", .{self.name});
        if (options.linebreaks) {
            try writer.writeByte('\n');
        }
    }

    pub fn setLanguage(self: *Node, allocator: Allocator, language: Language) !void {
        try self.addAttribute(allocator, "lang", language.toString());
    }
};

const Language = enum {
    chinese,
    english,
    french,
    german,
    japanese,

    pub fn toString(self: Language) []const u8 {
        return switch (self) {
            .chinese => "zh-Hant",
            .english => "en",
            .french => "fr",
            .german => "de",
            .japanese => "ja",
        };
    }
};

pub const Document = struct {
    gpa: Allocator,
    root: Node,

    pub fn init(gpa: Allocator, title: []const u8) Error!Document {
        var self: Document = .{ .gpa = gpa, .root = try Node.init(gpa, "html") };
        var charset = try Node.init(gpa, "meta");
        try charset.addAttribute(gpa, "charset", "utf-8");

        try self.root.set(gpa, "head", try Node.init(gpa, "head"));
        try self.root.addTo(gpa, "head", .{ .node = charset });
        try self.root.set(gpa, "head.title", try Node.init(gpa, "title"));
        try self.root.addTo(gpa, "head.title", try self.text(title));
        try self.root.set(gpa, "body", try Node.init(gpa, "body"));
        return self;
    }

    pub fn deinit(self: *Document) void {
        self.root.deinit(self.gpa);
    }

    pub fn add(self: *Document, element: Element) !void {
        try self.root.add(self.gpa, element);
    }

    pub fn node(self: Document, name: []const u8) !Element {
        return .{ .node = try Node.init(self.gpa, name) };
    }

    pub fn text(self: Document, _text: []const u8) !Element {
        return .{ .ownedLeaf = try self.gpa.dupe(u8, _text) };
    }

    pub fn addPragma(self: *Document, name: []const u8, content: []const u8) !void {
        var meta = try Node.init(self.gpa, "meta");
        try meta.addAttribute(self.gpa, "http-equiv", name);
        try meta.addAttribute(self.gpa, "content", content);
        try self.root.addTo(self.gpa, "head", .{ .node = meta });
    }

    pub fn addScript(self: *Document, filename: []const u8) !void {
        var script = try Node.init(self.gpa, "script");
        try script.addAttribute(self.gpa, "src", filename);
        try self.root.addTo(self.gpa, "head", .{ .node = script });
    }

    pub fn setLanguage(self: *Document, language: Language) !void {
        try self.root.setLanguage(self.gpa, language);
    }

    pub fn toString(self: Document, allocator: Allocator, options: RenderOptions) ![]u8 {
        var builder: std.ArrayListUnmanaged(u8) = .{};

        try builder.appendSlice(allocator, "<!DOCTYPE html>");
        if (options.linebreaks)
            try builder.append(allocator, '\n');
        try self.root.writeTo(builder.writer(allocator), options);
        return try builder.toOwnedSlice(allocator);
    }
};

test Document {
    var d = try Document.init(std.testing.allocator, "Patavinus");
    defer d.deinit();

    try d.setLanguage(.english);
    try d.root.addAttribute(d.gpa, "style", "height: 100%");
    try d.addPragma("Cache-Control", "no-cache, no-store, must-revalidate");
    try d.addPragma("Pragma", "no-cache");
    try d.addPragma("Expires", "0");
    try d.addScript("WebBackend.js");

    const pretty = try d.toString(std.testing.allocator, RenderOptions.pretty);
    defer std.testing.allocator.free(pretty);
    std.debug.print("{s}", .{pretty});

    const str = try d.toString(std.testing.allocator, RenderOptions.compact);
    defer std.testing.allocator.free(str);
    std.debug.print("{s}\n", .{str});
}
