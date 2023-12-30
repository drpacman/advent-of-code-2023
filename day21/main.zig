const std = @import("std");

fn parse_file(path: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);

    var lines_iter = std.mem.split(u8, file_contents, "\n");
    var lines = std.ArrayList([]const u8).init(allocator);
    while (lines_iter.next()) |line| {
        try lines.append(line);
    }
    return lines.toOwnedSlice();
}

fn part1(garden: [][]const u8, allocator: std.mem.Allocator) !u64 {
    var steps: u64 = 0;
    var positions = std.AutoHashMap([2]u8, void).init(allocator);
    const start = [2]u8{ @intCast((garden.len - 1) / 2), @intCast((garden[0].len - 1) / 2) };
    try positions.put(start, {});

    while (steps < 64) : (steps += 1) {
        const current_positions = positions.move();
        var pos_iter = current_positions.keyIterator();
        while (pos_iter.next()) |pos| {
            const next_steps = try step(garden, pos.*, allocator);
            for (next_steps) |next_step| {
                try positions.put(next_step, {});
            }
        }
    }
    return positions.count();
}

fn step(garden: [][]const u8, pos: [2]u8, allocator: std.mem.Allocator) ![][2]u8 {
    var neighbors = std.ArrayList([2]u8).init(allocator);
    if (pos[0] > 0 and garden[pos[0] - 1][pos[1]] != '#') try neighbors.append([2]u8{ pos[0] - 1, pos[1] });
    if (pos[0] < garden.len - 2 and garden[pos[0] + 1][pos[1]] != '#') try neighbors.append([2]u8{ pos[0] + 1, pos[1] });
    if (pos[1] > 0 and garden[pos[0]][pos[1] - 1] != '#') try neighbors.append([2]u8{ pos[0], pos[1] - 1 });
    if (pos[1] < garden[0].len - 2 and garden[pos[0]][pos[1] + 1] != '#') try neighbors.append([2]u8{ pos[0], pos[1] + 1 });
    return neighbors.toOwnedSlice();
}

// Can caluclate the infinite grid but that soon becomes too large to do brute force.
// No idea why but reddit says the answer is a quadratic function so have implented that
// https://www.reddit.com/r/adventofcode/comments/18nevo3/comment/keaiiq7/
fn part2(garden: [][]const u8, allocator: std.mem.Allocator) !u64 {
    // find result for steps 65, 65+131 and 65+131+131
    const results = try run_steps_part2(garden, 327, allocator);
    // work out attributed of quadratic function A(t) = at2 + bt + c
    // counting in steps of 131, offset by 65 - so t(0) is step 65, t(1) is step 196, t(2) is step 327
    // not forgetting results[0] is step 1 etc.
    const A_0 = results[64];
    const A_1 = results[195];
    const A_2 = results[326];
    // solving for a, b, c
    // where we can see that
    // A(0) = c
    // A(1) = a + b + c
    // A(2) = 4a + 2b + c
    const a = (A_2 - 2 * A_1 + A_0) / 2;
    const b = (4 * A_1 - A_2 - 3 * A_0) / 2;
    const c = A_0;
    // requested step is 26501365
    const target_step = (26501365 - 65) / 131;
    return a * target_step * target_step + b * target_step + c;
}

fn run_steps_part2(garden: [][]const u8, steps: u64, allocator: std.mem.Allocator) ![]u64 {
    var positions = std.AutoHashMap([4]i32, void).init(allocator);
    const start = [4]i32{ @intCast((garden.len - 1) / 2), @intCast((garden[0].len - 1) / 2), 0, 0 };
    try positions.put(start, {});
    var results = try allocator.alloc(u64, steps);
    var i: u64 = 0;
    while (i < steps) : (i += 1) {
        const current_positions = positions.move();
        var pos_iter = current_positions.keyIterator();
        while (pos_iter.next()) |pos| {
            const next_steps = try step_part_2(garden, pos.*, allocator);
            for (next_steps) |next_step| {
                try positions.put(next_step, {});
            }
        }
        results[i] = positions.count();
    }
    return results;
}

fn step_part_2(garden: [][]const u8, pos: [4]i32, allocator: std.mem.Allocator) ![][4]i32 {
    var neighbors = std.ArrayList([4]i32).init(allocator);
    var next = if (pos[0] == 0) [4]i32{ @intCast(garden.len - 1), pos[1], pos[2] - 1, pos[3] } else [4]i32{ pos[0] - 1, pos[1], pos[2], pos[3] };
    if (garden[@intCast(next[0])][@intCast(next[1])] != '#') try neighbors.append(next);

    next = if (pos[0] < garden.len - 1) [4]i32{ pos[0] + 1, pos[1], pos[2], pos[3] } else [4]i32{ 0, pos[1], pos[2] + 1, pos[3] };
    if (garden[@intCast(next[0])][@intCast(next[1])] != '#') try neighbors.append(next);

    next = if (pos[1] == 0) [4]i32{ pos[0], @intCast(garden[0].len - 1), pos[2], pos[3] - 1 } else [4]i32{ pos[0], pos[1] - 1, pos[2], pos[3] };
    if (garden[@intCast(next[0])][@intCast(next[1])] != '#') try neighbors.append(next);
    next = if (pos[1] < garden[0].len - 1) [4]i32{ pos[0], pos[1] + 1, pos[2], pos[3] } else [4]i32{ pos[0], 0, pos[2], pos[3] + 1 };
    if (garden[@intCast(next[0])][@intCast(next[1])] != '#') try neighbors.append(next);
    return neighbors.toOwnedSlice();
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const garden = try parse_file("day21/input.txt", allocator);
    std.debug.print("Part 1 - {d}\n", .{try part1(garden, allocator)});
    std.debug.print("Part 2 - {d}\n", .{try part2(garden, allocator)});
}
