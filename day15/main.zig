const std = @import("std");

fn parse_file(path: []const u8, allocator: std.mem.Allocator) ![]Entry {
    const contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var entries = std.ArrayList(Entry).init(allocator);
    var lines = std.mem.split(u8, contents, ",");
    while (lines.next()) |line| {
        if (line[line.len - 1] == '-') {
            const label = line[0 .. line.len - 1];
            try entries.append(Entry{ .item = line, .label = label });
        } else {
            const label = line[0 .. line.len - 2];
            try entries.append(Entry{ .item = line, .label = label, .value = try std.fmt.parseInt(u8, line[line.len - 1 ..], 10) });
        }
    }
    return entries.toOwnedSlice();
}

fn part1(entries: []Entry) u64 {
    var total: u64 = 0;
    for (entries) |entry| {
        total += hash(entry.item);
    }
    return total;
}

fn hash(item: []const u8) u64 {
    var h: u64 = 0;
    for (item) |c| {
        h = ((h + c) * 17) % 256;
    }
    return h;
}

const Entry = struct { item: []const u8, label: []const u8, value: ?u64 = null };

fn part2(entries: []Entry, comptime allocator: std.mem.Allocator) !u64 {
    var boxes_list = std.ArrayList(std.StringArrayHashMap(u64)).init(allocator);
    for (0..256) |_| {
        try boxes_list.append(std.StringArrayHashMap(u64).init(allocator));
    }
    var boxes = try boxes_list.toOwnedSlice();

    for (entries) |entry| {
        const box_num = hash(entry.label);
        if (entry.value) |value| {
            try boxes[box_num].put(entry.label, value);
        } else {
            _ = boxes[box_num].orderedRemove(entry.label);
        }
    }

    var total: u64 = 0;
    for (boxes, 0..256) |box, box_num| {
        const box_entries = box.values();
        var pos: u8 = 1;
        for (box_entries) |value| {
            total += ((box_num + 1) * pos * value);
            pos += 1;
        }
    }
    return total;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const entries = try parse_file("day15/input.txt", allocator);
    std.debug.print("total: {d}\n", .{part1(entries)});
    std.debug.print("total: {d}\n", .{try part2(entries, allocator)});
}

test "hash" {
    try std.testing.expectEqual(hash("HASH"), 52);
}

test "part2" {
    const allocator = std.heap.page_allocator;
    const entries = try parse_file("day15/test.txt", allocator);
    try std.testing.expectEqual(part2(entries, allocator), 145);
}
