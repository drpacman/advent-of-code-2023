const std = @import("std");
const expectEqual = std.testing.expectEqual;
const stdout = std.io.getStdOut().writer();

const Entry = struct {
    x: i8,
    y: i8,
    direction: Direction,
    prev: ?*const Entry,
    fn equal(self: Entry, other: Entry) bool {
        if (self.x == other.x and self.y == other.y and self.direction == other.direction) return true;
        return false;
    }
};
const Direction = enum(u2) { Up = 0, Down = 1, Left = 2, Right = 3 };
const Mirror = struct { mirror_type: u8, visited: u4 };

fn read_file(path: []const u8, allocator: std.mem.Allocator) ![][]*Mirror {
    const file = try std.fs.cwd().readFileAlloc(allocator, path, 1e8);
    var lines = std.mem.split(u8, file, "\n");
    var mirrors = std.ArrayList([]*Mirror).init(allocator);
    while (lines.next()) |line| {
        var cols = try allocator.alloc(*Mirror, line.len);
        for (line, 0..) |char, i| {
            const mirror = try allocator.create(Mirror);
            mirror.* = .{ .mirror_type = char, .visited = 0 };
            cols[i] = mirror;
        }
        try mirrors.append(cols);
    }
    return mirrors.toOwnedSlice();
}

fn process(entry: Entry, mirrors: *[][]*Mirror) ![]Entry {
    // done if off map
    if (entry.y < 0 or entry.y >= mirrors.*.len or entry.x < 0 or entry.x >= mirrors.*[0].len) {
        var last = [1]Entry{entry.prev.?.*};
        return last[0..];
    }
    var mirror = mirrors.*[@intCast(entry.y)][@intCast(entry.x)];
    const dir_as_int = @intFromEnum(entry.direction);
    const n: u4 = 1;
    const dir_mask: u4 = n << dir_as_int;
    if (mirror.visited & dir_mask > 0) {
        var last = [1]Entry{entry.prev.?.*};
        return last[0..];
    }
    mirror.visited |= dir_mask;

    switch (mirror.mirror_type) {
        '/' => {
            return switch (entry.direction) {
                Direction.Up => process(Entry{ .x = entry.x + 1, .y = entry.y, .direction = Direction.Right, .prev = &entry }, mirrors),
                Direction.Down => process(Entry{ .x = entry.x - 1, .y = entry.y, .direction = Direction.Left, .prev = &entry }, mirrors),
                Direction.Left => process(Entry{ .x = entry.x, .y = entry.y + 1, .direction = Direction.Down, .prev = &entry }, mirrors),
                Direction.Right => process(Entry{ .x = entry.x, .y = entry.y - 1, .direction = Direction.Up, .prev = &entry }, mirrors),
            };
        },
        '\\' => {
            return switch (entry.direction) {
                Direction.Up => process(Entry{ .x = entry.x - 1, .y = entry.y, .direction = Direction.Left, .prev = &entry }, mirrors),
                Direction.Down => process(Entry{ .x = entry.x + 1, .y = entry.y, .direction = Direction.Right, .prev = &entry }, mirrors),
                Direction.Left => process(Entry{ .x = entry.x, .y = entry.y - 1, .direction = Direction.Up, .prev = &entry }, mirrors),
                Direction.Right => process(Entry{ .x = entry.x, .y = entry.y + 1, .direction = Direction.Down, .prev = &entry }, mirrors),
            };
        },
        '-' => {
            return switch (entry.direction) {
                Direction.Up, Direction.Down => {
                    var combined = std.ArrayList(Entry).init(std.heap.page_allocator);
                    var entries = try process(Entry{ .x = entry.x - 1, .y = entry.y, .direction = Direction.Left, .prev = &entry }, mirrors);
                    for (entries) |e| {
                        try combined.append(e);
                    }
                    entries = try process(Entry{ .x = entry.x + 1, .y = entry.y, .direction = Direction.Right, .prev = &entry }, mirrors);
                    for (entries) |e| {
                        try combined.append(e);
                    }
                    return combined.toOwnedSlice();
                },
                Direction.Left => process(Entry{ .x = entry.x - 1, .y = entry.y, .direction = Direction.Left, .prev = &entry }, mirrors),
                Direction.Right => process(Entry{ .x = entry.x + 1, .y = entry.y, .direction = Direction.Right, .prev = &entry }, mirrors),
            };
        },
        '|' => {
            return switch (entry.direction) {
                Direction.Up => process(Entry{ .x = entry.x, .y = entry.y - 1, .direction = Direction.Up, .prev = &entry }, mirrors),
                Direction.Down => process(Entry{ .x = entry.x, .y = entry.y + 1, .direction = Direction.Down, .prev = &entry }, mirrors),
                Direction.Left, Direction.Right => {
                    var combined = std.ArrayList(Entry).init(std.heap.page_allocator);
                    var entries = try process(Entry{ .x = entry.x, .y = entry.y + 1, .direction = Direction.Down, .prev = &entry }, mirrors);
                    for (entries) |e| {
                        try combined.append(e);
                    }
                    entries = try process(Entry{ .x = entry.x, .y = entry.y - 1, .direction = Direction.Up, .prev = &entry }, mirrors);
                    for (entries) |e| {
                        try combined.append(e);
                    }
                    return combined.toOwnedSlice();
                },
            };
        },
        '.' => {
            return switch (entry.direction) {
                Direction.Up => process(Entry{ .x = entry.x, .y = entry.y - 1, .direction = Direction.Up, .prev = &entry }, mirrors),
                Direction.Down => process(Entry{ .x = entry.x, .y = entry.y + 1, .direction = Direction.Down, .prev = &entry }, mirrors),
                Direction.Left => process(Entry{ .x = entry.x - 1, .y = entry.y, .direction = Direction.Left, .prev = &entry }, mirrors),
                Direction.Right => process(Entry{ .x = entry.x + 1, .y = entry.y, .direction = Direction.Right, .prev = &entry }, mirrors),
            };
        },
        else => {
            unreachable;
        },
    }
    unreachable;
}

fn calculate_visited(start: Entry, mirrors: *[][]*Mirror) !u32 {
    // reset visited
    for (mirrors.*) |row| {
        for (row) |mirror| {
            mirror.visited = 0;
        }
    }
    _ = try process(start, mirrors);
    var result: u32 = 0;
    for (mirrors.*) |row| {
        for (row) |mirror| {
            if (mirror.visited > 0) result += 1;
        }
    }
    return result;
}

fn part1(mirrors: *[][]*Mirror) !u32 {
    const start = Entry{ .x = 0, .y = 0, .direction = Direction.Right, .prev = null };
    return calculate_visited(start, mirrors);
}

fn part2(mirrors: *[][]*Mirror) !u32 {
    const max_y = mirrors.*.len;
    const max_x = mirrors.*[0].len;
    var max_result: u32 = 0;
    for (0..max_x) |x| {
        const start = Entry{ .x = @intCast(x), .y = 0, .direction = Direction.Down, .prev = null };
        const result = try calculate_visited(start, mirrors);
        if (result > max_result) max_result = result;
    }
    for (0..max_x) |x| {
        const start = Entry{ .x = @intCast(x), .y = @intCast(max_y - 1), .direction = Direction.Up, .prev = null };
        const result = try calculate_visited(start, mirrors);
        if (result > max_result) max_result = result;
    }
    for (0..max_y) |y| {
        const start = Entry{ .x = 0, .y = @intCast(y), .direction = Direction.Right, .prev = null };
        const result = try calculate_visited(start, mirrors);
        if (result > max_result) max_result = result;
    }
    for (0..max_y) |y| {
        const start = Entry{ .x = @intCast(max_x - 1), .y = @intCast(y), .direction = Direction.Left, .prev = null };
        const result = try calculate_visited(start, mirrors);
        if (result > max_result) max_result = result;
    }
    return max_result;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var mirrors = try read_file("day16/input.txt", allocator);
    std.debug.print("Part 1 - {d}\n", .{try part1(&mirrors)});
    std.debug.print("Part 2 - {d}\n", .{try part2(&mirrors)});
}

test "part1" {
    const allocator = std.heap.page_allocator;
    var mirrors = try read_file("day16/test.txt", allocator);
    try expectEqual(try part1(&mirrors), 46);
}

test "read_file" {
    const allocator = std.heap.page_allocator;
    const mirrors = try read_file("day16/test.txt", allocator);
    defer allocator.free(mirrors);
    try expectEqual(mirrors.len, 10);
    try expectEqual(mirrors[0][0].visited, false);
}
