const std = @import("std");

fn read_contents(path: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.ArrayList([]const u8).init(allocator);
    var line_iter = std.mem.split(u8, file_contents, "\n");
    while (line_iter.next()) |line| {
        try lines.append(line);
    }
    return lines.toOwnedSlice();
}

const Direction = enum { North, South, East, West };
const Move = struct { direction: Direction, x: usize, y: usize };
const Errors = error{Invalid};
const Coord = struct { x: usize, y: usize };

fn find_start(contents: [][]const u8) !Coord {
    for (0..contents.len) |y| {
        for (0..contents[y].len) |x| {
            if (contents[y][x] == 'S') {
                return Coord{ .x = x, .y = y };
            }
        }
    }
    unreachable;
}

fn next(contents: [][]const u8, move: Move) Errors!Move {
    const c = contents[move.y][move.x];
    switch (move.direction) {
        Direction.North => return switch (c) {
            '|' => Move{ .direction = Direction.North, .x = move.x, .y = move.y - 1 },
            'F' => Move{ .direction = Direction.East, .x = move.x + 1, .y = move.y },
            '7' => Move{ .direction = Direction.West, .x = move.x - 1, .y = move.y },
            else => Errors.Invalid,
        },
        Direction.South => return switch (c) {
            '|' => Move{ .direction = Direction.South, .x = move.x, .y = move.y + 1 },
            'J' => Move{ .direction = Direction.West, .x = move.x - 1, .y = move.y },
            'L' => Move{ .direction = Direction.East, .x = move.x + 1, .y = move.y },
            else => Errors.Invalid,
        },
        Direction.East => return switch (c) {
            '-' => Move{ .direction = Direction.East, .x = move.x + 1, .y = move.y },
            'J' => Move{ .direction = Direction.North, .x = move.x, .y = move.y - 1 },
            '7' => Move{ .direction = Direction.South, .x = move.x, .y = move.y + 1 },
            else => Errors.Invalid,
        },
        Direction.West => return switch (c) {
            '-' => Move{ .direction = Direction.West, .x = move.x - 1, .y = move.y },
            'L' => Move{ .direction = Direction.North, .x = move.x, .y = move.y - 1 },
            'F' => Move{ .direction = Direction.South, .x = move.x, .y = move.y + 1 },
            else => Errors.Invalid,
        },
    }
    return Errors.Invalid;
}

fn get_first_move(contents: [][]const u8, start: Coord) Move {
    // get first move
    var elem = contents[start.y][start.x];
    var move = Move{ .x = start.x, .y = start.y, .direction = Direction.West };
    if (start.x > 0) {
        elem = contents[start.y][start.x - 1];
        if (elem == '-' or elem == 'F' or elem == 'L') {
            return move;
        }
    }
    if (start.x < contents[0].len) {
        move.direction = Direction.East;
        elem = contents[start.y][start.x + 1];
        if (elem == '-' or elem == '7' or elem == 'J') {
            return move;
        }
    }
    if (start.y > 0) {
        move.direction = Direction.North;
        elem = contents[start.y - 1][start.x];
        if (elem == '|' or elem == '7' or elem == 'F') {
            return move;
        }
    }

    move.direction = Direction.South;
    return move;
}

fn build_loop(contents: [][]const u8) ![]Move {
    var loop = std.ArrayList(Move).init(std.heap.page_allocator);
    const start = try find_start(contents);
    var current: Move = get_first_move(contents, start);
    try loop.append(current);
    switch (current.direction) {
        Direction.North => current = Move{ .x = current.x, .y = current.y - 1, .direction = Direction.North },
        Direction.South => current = Move{ .x = current.x, .y = current.y + 1, .direction = Direction.South },
        Direction.East => current = Move{ .x = current.x + 1, .y = current.y, .direction = Direction.East },
        Direction.West => current = Move{ .x = current.x - 1, .y = current.y, .direction = Direction.West },
    }
    try loop.append(current);
    while (true) {
        current = try next(contents, current);
        // check if we have completed the loop
        if (contents[current.y][current.x] == 'S') break;
        try loop.append(current);
    }
    return loop.toOwnedSlice();
}

fn part1(contents: [][]const u8) !usize {
    return (try build_loop(contents)).len / 2;
}

fn on_loop(x: usize, y: usize, loop: []Move) bool {
    for (loop) |loop_move| {
        if (loop_move.x == x and loop_move.y == y) {
            return true;
        }
    }
    return false;
}

// Cheated - Credit to https://github.com/OskarSigvardsson/adventofcode/blob/master/2023/day10/day10.py for the solution
// initially tried following the loop and counting internal neighbours but hit bugs with sharp corners
// and was too lazy to fix it - ray tracing is far more elegant.
fn part2(contents: [][]const u8) !usize {
    const loop = try build_loop(contents);
    // create a grid to display answer
    var updated_grid = std.ArrayList([]u8).init(std.heap.page_allocator);
    for (contents) |row| {
        var updated_row = std.ArrayList(u8).init(std.heap.page_allocator);
        for (row) |c| {
            try updated_row.append(c);
        }
        try updated_grid.append(try updated_row.toOwnedSlice());
    }
    var output = try updated_grid.toOwnedSlice();
    // walk elems from left to right, top to bottom keep a count of if they have cross the loop
    var internal_count: u16 = 0;
    const width = output[0].len;
    const height = output.len;
    for (0..height) |y| {
        for (0..width) |x| {
            if (on_loop(x, y, loop)) continue;
            // if entry is not on the loop ray trace to edge to see if inside a loop
            // if count of hitting loop on the way out is odd we are inside the loop
            // if count of hitting loop is even we aren't inside the loop
            // shoot out in a diagonal diagonally to avoid following horizontal edges of the loop
            var xx = x;
            var yy = y;
            var cross_count: u8 = 0;
            while (xx < width and yy < height) {
                // watch out for edge case where we hit corner "tangents" of loop
                if (on_loop(xx, yy, loop) and contents[yy][xx] != 'L' and contents[yy][xx] != '7') {
                    cross_count += 1;
                }
                xx += 1;
                yy += 1;
            }
            if (cross_count % 2 != 0) {
                internal_count += 1;
                output[y][x] = 'I';
            } else {
                output[y][x] = 'O';
            }
        }
    }

    for (output) |row| {
        std.debug.print("{s}\n", .{row});
    }
    return internal_count;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const contents = try read_contents("day10/input.txt", allocator);
    std.debug.print("Part1 - {any}\n", .{part1(contents)});
    std.debug.print("Part2 - {any}\n", .{part2(contents)});
}

test "read" {
    const allocator = std.heap.page_allocator;
    const contents = try read_contents("day10/input.txt", allocator);
    try std.testing.expectEqual(contents.len, 140);
    try std.testing.expectEqual(contents[0].len, 140);
}

test "part1" {
    const allocator = std.heap.page_allocator;
    const contents = try read_contents("day10/test.txt", allocator);
    try std.testing.expectEqual(part1(contents), 8);
}

test "part2" {
    const allocator = std.heap.page_allocator;
    const contents = try read_contents("day10/test2.txt", allocator);
    try std.testing.expectEqual(part2(contents), 10);
}
