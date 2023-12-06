const std = @import("std");

const Entry = struct {
    src: u64,
    dst: u64,
    range: u64,

    fn cmp(context: void, a: Entry, b: Entry) bool {
        _ = context;
        if (a.src < b.src) {
            return true;
        } else {
            return false;
        }
    }
};

const Mapping = struct { from: []const u8, to: []const u8, entries: []Entry };

const Game = struct { seeds: []u64, mappings: []Mapping };

fn parse_file(name: []const u8, allocator: std.mem.Allocator) !Game {
    var file = try std.fs.cwd().openFile(name, .{});
    const file_contents = try file.readToEndAlloc(allocator, 1e6);
    var file_iter = std.mem.split(u8, file_contents, "\n");
    var seeds_iter = std.mem.split(u8, file_iter.next().?, " ");
    _ = seeds_iter.next();
    var seeds = std.ArrayList(u64).init(allocator);
    while (seeds_iter.next()) |seed| {
        try seeds.append(try std.fmt.parseInt(u64, seed, 10));
    }
    _ = file_iter.next();
    var mappings = std.ArrayList(Mapping).init(allocator);
    while (true) {
        const mapping = try parse_mapping(&file_iter, allocator);
        if (mapping == null) break;
        try mappings.append(mapping.?);
    }
    return Game{ .seeds = seeds.items, .mappings = try mappings.toOwnedSlice() };
}

fn parse_mapping(input_iter: *std.mem.SplitIterator(u8, .sequence), allocator: std.mem.Allocator) !?Mapping {
    const mapping = input_iter.next();
    if (mapping == null) {
        return null;
    }
    var mapping_iter = std.mem.split(u8, mapping.?, "-");
    var entries = std.ArrayList(Entry).init(allocator);
    while (input_iter.next()) |line| {
        if (line.len == 0) break;
        try entries.append(try parse_entry(line));
    }
    const entries_slice = try entries.toOwnedSlice();
    std.sort.insertion(Entry, entries_slice, {}, Entry.cmp);

    const from = mapping_iter.next().?;
    _ = mapping_iter.next();
    var to_iter = std.mem.split(u8, mapping_iter.next().?, " ");
    const to = to_iter.next().?;
    return Mapping{ .from = from, .to = to, .entries = entries_slice };
}

fn parse_entry(line: []const u8) !Entry {
    var entry_iter = std.mem.split(u8, line, " ");
    return Entry{
        .dst = try std.fmt.parseInt(u64, entry_iter.next().?, 10),
        .src = try std.fmt.parseInt(u64, entry_iter.next().?, 10),
        .range = try std.fmt.parseInt(u64, entry_iter.next().?, 10),
    };
}

fn part2(game: Game) u64 {
    // go from location to a seed
    var location: u64 = 0;
    while (true) : (location += 1) {
        var pos = location;
        // walk backwards from location to soil
        // check if seed is any of the ranges
        var target: []const u8 = "location";
        while (!std.mem.eql(u8, target, "seed")) {
            mappings: for (game.mappings) |mapping| {
                if (!std.mem.eql(u8, mapping.to, target)) continue;
                for (mapping.entries) |entry| {
                    if (pos >= entry.dst and pos <= entry.dst + entry.range) {
                        // found range mapping
                        pos = entry.src + (pos - entry.dst);
                        break;
                    }
                }
                target = mapping.from;
                break :mappings;
            }
        }
        // see if the seed is in the game range
        var i: u32 = 0;
        while (i < game.seeds.len) : (i += 2) {
            if (game.seeds[i] <= pos and game.seeds[i] + game.seeds[i + 1] >= pos) {
                return location;
            }
        }
    }
    return 0;
}

fn part1(game: Game) u64 {
    var result: u64 = 1e10;
    // walk seeds from soil to location
    for (game.seeds) |seed| {
        var pos: u64 = seed;
        var target: []const u8 = "seed";
        for (game.mappings) |mapping| {
            if (!std.mem.eql(u8, mapping.from, target)) continue;
            for (mapping.entries) |entry| {
                if (entry.src > pos) {
                    // found pos
                    break;
                } else if (entry.src + entry.range >= pos) {
                    pos = entry.dst + (pos - entry.src);
                    break;
                }
            }
            if (std.mem.eql(u8, mapping.to, "location")) {
                if (result > pos) {
                    result = pos;
                }
            } else {
                target = mapping.to;
            }
        }
    }
    return result;
}

pub fn main() !void {
    const game = try parse_file("day05/input.txt", std.heap.page_allocator);
    std.debug.print("Part 1 - {d}\n", .{part1(game)});
    std.debug.print("Part 2- {d}\n", .{part2(game)});
}

test "parsing" {
    const game = try parse_file("day05/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(game.mappings.len, 7);
    const result = [_]u64{ 79, 14, 55, 13 };
    try std.testing.expect(std.mem.eql(u64, game.seeds, &result));
    try std.testing.expectEqualStrings(game.mappings[2].from, "fertilizer");
    try std.testing.expectEqualStrings(game.mappings[2].to, "water");
    try std.testing.expectEqual(game.mappings[0].entries[0].src, 50);
}

test "part1" {
    const game = try parse_file("day05/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(part1(game), 35);
}

test "part2" {
    const game = try parse_file("day05/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(part2(game), 46);
}
