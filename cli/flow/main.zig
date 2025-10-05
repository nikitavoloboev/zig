const std = @import("std");
const build_options = @import("build_options");

const stdout_file = std.fs.File.stdout();
const stderr_file = std.fs.File.stderr();

const Entry = struct {
    name: []const u8,
    kind: std.fs.Dir.Entry.Kind,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // executable name
    const maybe_command = args.next();

    if (maybe_command == null) {
        try printHelp(allocator);
        return;
    }

    const command = maybe_command.?;
    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp(allocator);
        return;
    }

    if (std.mem.eql(u8, command, "--version")) {
        try printVersion(allocator);
        return;
    }

    if (std.mem.eql(u8, command, "tree")) {
        const target_path = args.next() orelse ".";
        if (args.next()) |_| {
            try printError(allocator, "flow tree accepts at most one path argument.\n", .{});
            std.process.exit(1);
        }

        runTree(allocator, target_path) catch |err| {
            const msg = try std.fmt.allocPrint(allocator, "Error: unable to render tree for '{s}': {s}\n", .{ target_path, @errorName(err) });
            try stderr_file.writeAll(msg);
            std.process.exit(1);
        };
        return;
    }

    const msg = try std.fmt.allocPrint(allocator, "Unknown command '{s}'.\n", .{command});
    try stderr_file.writeAll(msg);
    try printHelp(allocator);
    std.process.exit(1);
}

fn printHelp(allocator: std.mem.Allocator) !void {
    const header = try std.fmt.allocPrint(allocator, "flow {s}\n\n", .{build_options.version});
    const body =
        "Usage:\n" ++
        "  flow [--help] [--version]\n" ++
        "  flow tree [path]\n\n" ++
        "Commands:\n" ++
        "  tree    Print a simple directory tree (defaults to '.')\n";

    try stdout_file.writeAll(header);
    try stdout_file.writeAll(body);
}

fn printVersion(allocator: std.mem.Allocator) !void {
    const version_line = try std.fmt.allocPrint(allocator, "flow {s}\n", .{build_options.version});
    try stdout_file.writeAll(version_line);
}

fn printError(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const message = try std.fmt.allocPrint(allocator, fmt, args);
    try stderr_file.writeAll(message);
}

fn runTree(allocator: std.mem.Allocator, path: []const u8) !void {
    const stat = std.fs.cwd().statFile(path) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Error: failed to access '{s}': {s}\n", .{ path, @errorName(err) });
        try stderr_file.writeAll(msg);
        std.process.exit(1);
    };

    if (stat.kind == .directory) {
        try stdout_file.writeAll(path);
        try stdout_file.writeAll("\n");
        try renderTree(allocator, path, "");
    } else {
        try stdout_file.writeAll(path);
        try stdout_file.writeAll("\n");
    }
}

fn renderTree(allocator: std.mem.Allocator, path: []const u8, prefix: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList(Entry).empty;
    defer entries.deinit(allocator);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) continue;
        const name_copy = try allocator.dupe(u8, entry.name);
        try entries.append(allocator, .{ .name = name_copy, .kind = entry.kind });
    }

    if (entries.items.len == 0) return;

    var index: usize = 0;
    while (index < entries.items.len) : (index += 1) {
        const entry = entries.items[index];
        const is_last = index == entries.items.len - 1;
        try stdout_file.writeAll(prefix);
        try stdout_file.writeAll(if (is_last) "\\-- " else "|-- ");
        try stdout_file.writeAll(entry.name);
        try stdout_file.writeAll("\n");

        if (entry.kind == .directory) {
            const child_path = try std.fs.path.join(allocator, &.{ path, entry.name });
            const child_prefix = try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, if (is_last) "    " else "|   " });
            renderTree(allocator, child_path, child_prefix) catch |err| {
                const msg = try std.fmt.allocPrint(allocator, "Warning: skipping '{s}': {s}\n", .{ child_path, @errorName(err) });
                try stderr_file.writeAll(msg);
            };
        }
    }
}
