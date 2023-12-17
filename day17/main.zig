const std = @import("std");

const Entry = struct { max: [4][3]u64, value: u8 };
const Direction = enum(u2) { Up = 0, Down = 1, Left = 2, Right = 3 };
const Move = struct { x: i16, y: i16, direction: Direction, count: u2, score: u64 };

fn parse_grid(path: []const u8, allocator: std.mem.Allocator) ![][]*Entry {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.mem.split(u8, file_contents, "\n");
    var result = std.ArrayList([]*Entry).init(allocator);
    while (lines.next()) |line| {
        var row = try allocator.alloc(*Entry, line.len);
        for (line, 0..) |num, i| {
            const entry = try allocator.create(Entry);
            entry.* = .{ .max = [4][3]u64{ [3]u64{ 1e6, 1e6, 1e6 }, [3]u64{ 1e6, 1e6, 1e6 }, [3]u64{ 1e6, 1e6, 1e6 }, [3]u64{ 1e6, 1e6, 1e6 } }, .value = num - '0' };
            row[i] = entry;
        }
        try result.append(row);
    }
    return result.toOwnedSlice();
}

fn min_route(grid: [][]*Entry) u64 {
    const max_y = grid.len - 1;
    const max_x = grid[0].len - 1;
    return min_entry(grid[max_y][max_x]);
}

fn min_entry(entry: *Entry) u64 {
    var result: u64 = 1e8;
    for (0..3) |i| {
        for (0..4) |dir| {
            const n = entry.*.max[dir][i];
            if (n < result) {
                result = n;
            }
        }
    }

    return result;
}

fn insert_move(grid: [][]*Entry, candidate: Move, moves: *std.ArrayList(Move)) !void {
    const max_x = grid[0].len - 1;
    const max_y = grid.len - 1;
    if (candidate.x < 0) return;
    if (candidate.x > max_x) return;
    if (candidate.y < 0) return;
    if (candidate.y > max_y) return;
    if (candidate.count > 2) return;
    const dir_idx = @intFromEnum(candidate.direction);
    const entry = grid[@intCast(candidate.y)][@intCast(candidate.x)];
    const updated_score = candidate.score + entry.value;
    if (updated_score >= entry.*.max[dir_idx][candidate.count]) return;
    if (updated_score > min_route(grid)) return;
    // if all good, add it
    entry.*.max[dir_idx][candidate.count] = updated_score;
    try moves.append(Move{ .x = candidate.x, .y = candidate.y, .direction = candidate.direction, .count = candidate.count, .score = updated_score });
}

fn walk_grid(grid: [][]*Entry, allocator: std.mem.Allocator) !void {
    var next_moves = std.ArrayList(Move).init(allocator);
    try next_moves.append(Move{ .x = 0, .y = 0, .direction = Direction.Down, .count = 0, .score = 0 });
    try next_moves.append(Move{ .x = 0, .y = 0, .direction = Direction.Right, .count = 0, .score = 0 });
    while (next_moves.items.len > 0) {
        const moves = try next_moves.toOwnedSlice();
        for (moves) |move| {
            switch (move.direction) {
                Direction.Right => {
                    try insert_move(grid, Move{ .x = move.x + 1, .y = move.y, .direction = Direction.Right, .count = move.count + 1, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x, .y = move.y - 1, .direction = Direction.Up, .count = 0, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x, .y = move.y + 1, .direction = Direction.Down, .count = 0, .score = move.score }, &next_moves);
                },
                Direction.Left => {
                    try insert_move(grid, Move{ .x = move.x - 1, .y = move.y, .direction = Direction.Left, .count = move.count + 1, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x, .y = move.y - 1, .direction = Direction.Up, .count = 0, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x, .y = move.y + 1, .direction = Direction.Down, .count = 0, .score = move.score }, &next_moves);
                },
                Direction.Up => {
                    try insert_move(grid, Move{ .x = move.x, .y = move.y - 1, .direction = Direction.Up, .count = move.count + 1, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x - 1, .y = move.y, .direction = Direction.Left, .count = 0, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x + 1, .y = move.y, .direction = Direction.Right, .count = 0, .score = move.score }, &next_moves);
                },
                Direction.Down => {
                    try insert_move(grid, Move{ .x = move.x, .y = move.y + 1, .direction = Direction.Down, .count = move.count + 1, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x - 1, .y = move.y, .direction = Direction.Left, .count = 0, .score = move.score }, &next_moves);
                    try insert_move(grid, Move{ .x = move.x + 1, .y = move.y, .direction = Direction.Right, .count = 0, .score = move.score }, &next_moves);
                },
            }
        }
    }
}

fn part1(grid: [][]*Entry, allocator: std.mem.Allocator) !u64 {
    try walk_grid(grid, allocator);
    return min_route(grid);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const grid = try parse_grid("day17/input.txt", allocator);
    std.debug.print("Part1 - {d}\n", .{try part1(grid, allocator)});
}

test "parse" {
    const allocator = std.heap.page_allocator;
    const grid = try parse_grid("day17/test.txt", allocator);
    try std.testing.expectEqual(grid.len, 13);
}

test "part1" {
    const allocator = std.heap.page_allocator;
    const grid = try parse_grid("day17/test.txt", allocator);
    try std.testing.expectEqual(try part1(grid, allocator), 102);
}
