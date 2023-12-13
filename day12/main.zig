const std = @import("std");

const Entry = struct { slots: []const u8, target: []u8 };
const CacheKey = struct { pos: u8, target_index: u8, run_count: u8 };

fn read_file(path: []const u8, allocator: std.mem.Allocator) ![]Entry {
    const contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var result = std.ArrayList(Entry).init(allocator);
    var lines = std.mem.split(u8, contents, "\n");
    while (lines.next()) |line| {
        var parts = std.mem.split(u8, line, " ");
        const slots = parts.next().?;
        var target_iter = std.mem.split(u8, parts.next().?, ",");
        var target = std.ArrayList(u8).init(allocator);
        while (target_iter.next()) |n| {
            try target.append(try std.fmt.parseInt(u8, n, 10));
        }
        try result.append(Entry{ .slots = slots, .target = try target.toOwnedSlice() });
    }
    return try result.toOwnedSlice();
}

fn count_variants(entry: Entry) !u64 {
    var cache = std.AutoHashMap(CacheKey, u64).init(std.heap.page_allocator);
    return try depth_first_search(&cache, entry, 0, 0, 0);
}

fn depth_first_search(cache: *std.AutoHashMap(CacheKey, u64), entry: Entry, pos: u8, target_index: u8, run_count: u8) !u64 {
    if (pos >= entry.slots.len) {
        // have we found them all?
        if (target_index >= entry.target.len) return 1;
        // handle a run right up to the end of the list
        if (target_index == entry.target.len - 1 and run_count == entry.target[target_index]) return 1;
        // no joy
        return 0;
    }

    if (cache.contains(CacheKey{ .pos = pos, .target_index = target_index, .run_count = run_count })) {
        return cache.get(CacheKey{ .pos = pos, .target_index = target_index, .run_count = run_count }).?;
    }

    var count: u64 = 0;
    // std.debug.print("{any}\n", .{pos});
    switch (entry.slots[pos]) {
        '.' => {
            if (run_count == 0) {
                // we can skip this slot, haven't started a run of damaged springs yet
                return try depth_first_search(cache, entry, pos + 1, target_index, 0);
            }

            if (target_index >= entry.target.len or run_count != entry.target[target_index]) {
                // we can't match the target
                return 0;
            }

            // found a valid run, on to the next
            return try depth_first_search(cache, entry, pos + 1, target_index + 1, 0);
        },
        '#' => {
            // have we already completed the expected runs of damaged springs?
            if (target_index >= entry.target.len) return 0;
            // is the run of damaged springs too long?
            if (run_count + 1 > entry.target[target_index]) return 0;
            return try depth_first_search(cache, entry, pos + 1, target_index, run_count + 1);
        },
        '?' => {
            // first treat it as '.'
            if (run_count == 0) {
                count += try depth_first_search(cache, entry, pos + 1, target_index, 0);
            }
            // otherwise can treat it as '#'
            if (target_index < entry.target.len) {
                if (run_count < entry.target[target_index]) {
                    count += try depth_first_search(cache, entry, pos + 1, target_index, run_count + 1);
                } else if (run_count == entry.target[target_index]) {
                    count += try depth_first_search(cache, entry, pos + 1, target_index + 1, 0);
                }
            }
            try cache.put(CacheKey{ .pos = pos, .target_index = target_index, .run_count = run_count }, count);

            return count;
        },
        else => unreachable,
    }
    return 0;
}

fn expand_entry(entry: Entry) !Entry {
    var new_targets = try std.heap.page_allocator.alloc(u8, entry.target.len * 5);
    const n = entry.slots.len + 1;
    var new_slots = try std.heap.page_allocator.alloc(u8, (n * 5) - 1);
    for (0..5) |i| {
        std.mem.copyForwards(u8, new_targets[entry.target.len * i ..], entry.target[0..]);
        std.mem.copyForwards(u8, new_slots[n * i ..], entry.slots[0..]);
        if (i < 4) new_slots[(n * (i + 1)) - 1] = '?';
    }

    return Entry{
        .slots = new_slots,
        .target = new_targets,
    };
}
fn part1(entries: []Entry) !u64 {
    var count: u64 = 0;
    for (entries) |entry| {
        count += try count_variants(entry);
    }
    return count;
}

fn part2(entries: []Entry) !u64 {
    var count: u64 = 0;
    for (entries) |entry| {
        count += try count_variants(try expand_entry(entry));
    }
    return count;
}

pub fn main() !void {
    const entries = try read_file("day12/input.txt", std.heap.page_allocator);
    std.debug.print("Part1 - {d}\n", .{try part1(entries)});
    std.debug.print("Part1 - {d}\n", .{try part2(entries)});
}

test "runs" {
    var t1 = [_]u8{ 3, 2, 1 };
    const result = count_variants(Entry{ .slots = "?###????????", .target = t1[0..] });
    try std.testing.expectEqual(result, 10);
}

test "expands" {
    var t1 = [_]u8{ 1, 1, 3 };
    const result = try expand_entry(Entry{ .slots = "???.###", .target = t1[0..] });
    try std.testing.expect(std.mem.eql(u8, result.slots, "???.###????.###????.###????.###????.###"));
}
