const std = @import("std");

const Entry = struct { max: [][]u64, value: u8 };
const Direction = enum(u2) { Up = 0, Down = 1, Left = 2, Right = 3 };
const Move = struct { x: i16, y: i16, direction: Direction, count: u8, score: u64 };
const Challenge = struct { grid: [][]*Entry, min_moves: u8, max_moves: u8 };

fn load_challenge(path: []const u8, allocator: std.mem.Allocator, min_moves: u8, max_moves: u8) !Challenge {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.mem.split(u8, file_contents, "\n");
    var result = std.ArrayList([]*Entry).init(allocator);
    while (lines.next()) |line| {
        var row = try allocator.alloc(*Entry, line.len);
        for (line, 0..) |num, i| {
            const entry = try allocator.create(Entry);
            var dir_holder: [][]u64 = try allocator.alloc([]u64, 4);
            for (0..4) |dir_idx| {
                var move_count_holder = try allocator.alloc(u64, max_moves);
                for (0..max_moves) |n| {
                    move_count_holder[n] = 1e6;
                }
                dir_holder[dir_idx] = move_count_holder;
            }
            entry.* = .{ .max = dir_holder, .value = num - '0' };
            row[i] = entry;
        }
        try result.append(row);
    }
    return Challenge{ .grid = try result.toOwnedSlice(), .min_moves = min_moves, .max_moves = max_moves };
}

fn min_route(grid: [][]*Entry) u64 {
    const max_y = grid.len - 1;
    const max_x = grid[0].len - 1;
    return min_entry(grid[max_y][max_x]);
}

fn min_entry(entry: *Entry) u64 {
    var result: u64 = 1e8;
    for (entry.*.max) |dir_entry| {
        for (dir_entry) |n| {
            if (n < result) {
                result = n;
            }
        }
    }
    return result;
}

fn insert_move(challenge: Challenge, candidate: Move, moves: *std.ArrayList(Move)) !void {
    const max_x = challenge.grid[0].len - 1;
    const max_y = challenge.grid.len - 1;
    if (candidate.x < 0) return;
    if (candidate.x > max_x) return;
    if (candidate.y < 0) return;
    if (candidate.y > max_y) return;
    if (candidate.count >= challenge.max_moves) return;
    const dir_idx = @intFromEnum(candidate.direction);
    const entry = challenge.grid[@intCast(candidate.y)][@intCast(candidate.x)];
    const updated_score = candidate.score + entry.value;
    if (updated_score >= entry.*.max[dir_idx][candidate.count]) return;
    if (updated_score > min_route(challenge.grid)) return;
    // if all good, add it - only update score if we are at least min count
    if (candidate.count >= challenge.min_moves) {
        entry.*.max[dir_idx][candidate.count] = updated_score;
    }
    try moves.append(Move{ .x = candidate.x, .y = candidate.y, .direction = candidate.direction, .count = candidate.count, .score = updated_score });
}

fn walk_grid(challenge: Challenge, allocator: std.mem.Allocator) !void {
    var next_moves = std.ArrayList(Move).init(allocator);
    try next_moves.append(Move{ .x = 0, .y = 0, .direction = Direction.Down, .count = 0, .score = 0 });
    try next_moves.append(Move{ .x = 0, .y = 0, .direction = Direction.Right, .count = 0, .score = 0 });
    while (next_moves.items.len > 0) {
        const moves = try next_moves.toOwnedSlice();
        for (moves) |move| {
            switch (move.direction) {
                Direction.Right => {
                    try insert_move(challenge, Move{ .x = move.x + 1, .y = move.y, .direction = Direction.Right, .count = move.count + 1, .score = move.score }, &next_moves);
                    if (move.count >= challenge.min_moves) {
                        try insert_move(challenge, Move{ .x = move.x, .y = move.y - 1, .direction = Direction.Up, .count = 0, .score = move.score }, &next_moves);
                        try insert_move(challenge, Move{ .x = move.x, .y = move.y + 1, .direction = Direction.Down, .count = 0, .score = move.score }, &next_moves);
                    }
                },
                Direction.Left => {
                    try insert_move(challenge, Move{ .x = move.x - 1, .y = move.y, .direction = Direction.Left, .count = move.count + 1, .score = move.score }, &next_moves);
                    if (move.count >= challenge.min_moves) {
                        try insert_move(challenge, Move{ .x = move.x, .y = move.y - 1, .direction = Direction.Up, .count = 0, .score = move.score }, &next_moves);
                        try insert_move(challenge, Move{ .x = move.x, .y = move.y + 1, .direction = Direction.Down, .count = 0, .score = move.score }, &next_moves);
                    }
                },
                Direction.Up => {
                    try insert_move(challenge, Move{ .x = move.x, .y = move.y - 1, .direction = Direction.Up, .count = move.count + 1, .score = move.score }, &next_moves);
                    if (move.count >= challenge.min_moves) {
                        try insert_move(challenge, Move{ .x = move.x - 1, .y = move.y, .direction = Direction.Left, .count = 0, .score = move.score }, &next_moves);
                        try insert_move(challenge, Move{ .x = move.x + 1, .y = move.y, .direction = Direction.Right, .count = 0, .score = move.score }, &next_moves);
                    }
                },
                Direction.Down => {
                    try insert_move(challenge, Move{ .x = move.x, .y = move.y + 1, .direction = Direction.Down, .count = move.count + 1, .score = move.score }, &next_moves);
                    if (move.count >= challenge.min_moves) {
                        try insert_move(challenge, Move{ .x = move.x - 1, .y = move.y, .direction = Direction.Left, .count = 0, .score = move.score }, &next_moves);
                        try insert_move(challenge, Move{ .x = move.x + 1, .y = move.y, .direction = Direction.Right, .count = 0, .score = move.score }, &next_moves);
                    }
                },
            }
        }
    }
}

fn part1(path: []const u8, allocator: std.mem.Allocator) !u64 {
    const challenge = try load_challenge(path, allocator, 0, 3);
    try walk_grid(challenge, allocator);
    return min_route(challenge.grid);
}

fn part2(path: []const u8, allocator: std.mem.Allocator) !u64 {
    const challenge = try load_challenge(path, allocator, 3, 10);
    try walk_grid(challenge, allocator);
    return min_route(challenge.grid);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    std.debug.print("Part1 - {d}\n", .{try part1("day17/input.txt", allocator)});
    std.debug.print("Part2 - {d}\n", .{try part2("day17/input.txt", allocator)});
}

test "parse" {
    const allocator = std.heap.page_allocator;
    const challenge = try load_challenge("day17/test.txt", allocator, 0, 3);
    try std.testing.expectEqual(challenge.grid.len, 13);
}

test "part1" {
    const allocator = std.heap.page_allocator;
    try std.testing.expectEqual(try part1("day17/test.txt", allocator), 102);
}

test "part2" {
    const allocator = std.heap.page_allocator;
    try std.testing.expectEqual(try part2("day17/test.txt", allocator), 94);
}
