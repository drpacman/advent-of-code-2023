const std = @import("std");

const Grid = struct {
    data: [][]u8,

    fn display(self: Grid) void {
        for (self.data) |row| {
            std.debug.print("{s}\n", .{row});
        }
    }
};

const Direction = enum { HORIZONTAL, VERTICAL };

const Match = struct {
    dir: Direction,
    pos: u16,

    fn score(self: Match) u32 {
        if (self.dir == Direction.VERTICAL) {
            return (100 * self.pos);
        }
        return self.pos;
    }

    fn equal(self: Match, other: Match) bool {
        return self.dir == other.dir and self.pos == other.pos;
    }
};

fn parse_file(path: []const u8, allocator: std.mem.Allocator) ![]Grid {
    const contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.mem.split(u8, contents, "\n");
    var grids = std.ArrayList(Grid).init(allocator);
    var data = std.ArrayList([]u8).init(allocator);
    while (lines.next()) |line| {
        if (line.len == 0) {
            try grids.append(Grid{ .data = try data.toOwnedSlice() });
        } else {
            const row = try allocator.alloc(u8, line.len);
            @memcpy(row, line);
            try data.append(row);
        }
    }
    try grids.append(Grid{ .data = try data.toOwnedSlice() });

    return grids.toOwnedSlice();
}

fn compare_cols(grid: Grid, colA: u8, colB: u8) bool {
    // std.debug.print("Comparing {d} and {d}\n", .{ colA, colB });
    for (0..grid.data.len) |row| {
        if (grid.data[row][colA] != grid.data[row][colB]) return false;
    }
    return true;
}

fn compare_rows(grid: Grid, rowA: u8, rowB: u8) bool {
    // std.debug.print("Comparing Rows {d} and {d}\n", .{ rowA, rowB });
    for (0..grid.data[0].len) |col| {
        if (grid.data[rowA][col] != grid.data[rowB][col]) return false;
    }
    return true;
}

fn find_mirrored_column(grid: Grid, ignore: ?u16) ?u16 {
    const columns = grid.data[0].len;
    for (0..columns - 1) |x| next: {
        if (ignore != null and x + 1 == ignore.?) continue;
        if (compare_cols(grid, @intCast(x), @intCast(x + 1))) {
            // found matching columns
            var n: u8 = 1;
            while (x >= n and x + 1 + n < columns) : (n += 1) {
                if (!compare_cols(grid, @intCast(x - n), @intCast(x + 1 + n))) {
                    break :next;
                }
            }
            return @intCast(x + 1);
        }
    }
    return null;
}

fn find_mirrored_row(grid: Grid, ignore: ?u16) ?u16 {
    const rows = grid.data.len;
    for (0..rows - 1) |y| next: {
        if (ignore != null and y + 1 == ignore.?) continue;
        if (compare_rows(grid, @intCast(y), @intCast(y + 1))) {
            var n: u8 = 1;
            while (y >= n and y + 1 + n < rows) : (n += 1) {
                if (!compare_rows(grid, @intCast(y - n), @intCast(y + 1 + n))) {
                    break :next;
                }
            }
            return @intCast(y + 1);
        }
    }
    return null;
}

fn find_mirror(grid: Grid) ?Match {
    if (find_mirrored_row(grid, null)) |row| {
        return Match{ .dir = Direction.VERTICAL, .pos = row };
    }

    if (find_mirrored_column(grid, null)) |col| {
        return Match{ .dir = Direction.HORIZONTAL, .pos = col };
    }
    unreachable;
}

fn part1(grids: []Grid) u32 {
    var total: u32 = 0;
    for (grids) |grid| {
        total += find_mirror(grid).?.score();
    }
    return total;
}

fn find_mirror_part2(grid: Grid, ignore: Match) ?Match {
    if (ignore.dir == Direction.VERTICAL) {
        if (find_mirrored_row(grid, ignore.pos)) |row| {
            return Match{ .dir = Direction.VERTICAL, .pos = row };
        }

        if (find_mirrored_column(grid, null)) |col| {
            return Match{ .dir = Direction.HORIZONTAL, .pos = col };
        }
    } else {
        if (find_mirrored_row(grid, null)) |row| {
            return Match{ .dir = Direction.VERTICAL, .pos = row };
        }

        if (find_mirrored_column(grid, ignore.pos)) |col| {
            return Match{ .dir = Direction.HORIZONTAL, .pos = col };
        }
    }
    return null;
}

fn smudge_grid(grid: Grid) u32 {
    const original = find_mirror(grid).?;
    for (0..grid.data.len) |row| {
        for (0..grid.data[0].len) |col| {
            const x = grid.data[row][col];
            if (x == '.') grid.data[row][col] = '#' else grid.data[row][col] = '.';
            const smudged = find_mirror_part2(grid, original);
            if (smudged) |s| {
                return s.score();
            }
            grid.data[row][col] = x;
        }
    }
    grid.display();
    unreachable;
}

fn part2(grids: []Grid) u32 {
    var total: u32 = 0;
    for (grids) |grid| {
        total += smudge_grid(grid);
    }
    return total;
}

pub fn main() !void {
    const grids = try parse_file("day13/input.txt", std.heap.page_allocator);
    std.debug.print("Part1: {d}\n", .{part1(grids)});
    std.debug.print("Part1: {d}\n", .{part2(grids)});
}

test "grid load" {
    const grids = try parse_file("day13/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(grids.len, 2);
}

test "grid mirrored column" {
    const grids = try parse_file("day13/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(find_mirrored_column(grids[0], null).?, 5);
    try std.testing.expectEqual(find_mirrored_column(grids[1], null), null);
}

test "grid mirrored row" {
    const grids = try parse_file("day13/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(find_mirrored_row(grids[0], null), null);
    try std.testing.expectEqual(find_mirrored_row(grids[1], null).?, 4);
}

test "part1" {
    const grids = try parse_file("day13/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(part1(grids), 405);
}

test "smudge" {
    const grids = try parse_file("day13/test2.txt", std.heap.page_allocator);
    try std.testing.expectEqual(smudge_grid(grids[0]), 1);
}

test "part2" {
    const grids = try parse_file("day13/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(part2(grids), 400);
}
