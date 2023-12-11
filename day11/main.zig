const std = @import("std");

const Coord = struct { x: i16, y: i16 };

fn parse_file(path: []const u8, allocator: std.mem.Allocator) ![]Coord {
    const contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var iter = std.mem.split(u8, contents, "\n");
    var entries = std.ArrayList(Coord).init(allocator);
    var y: u8 = 0;
    while (iter.next()) |line| {
        for (0..line.len) |x| {
            if (line[x] == '#') {
                try entries.append(Coord{ .x = @intCast(x), .y = @intCast(y) });
            }
        }
        y += 1;
    }
    return entries.toOwnedSlice();
}

fn get_blank_cols(coords: []Coord, min: i64, max: i64) u8 {
    var blank_col_count: u8 = 0;
    var x: i64 = min;
    cols: while (x < max) : (x += 1) {
        for (coords) |coord| {
            if (coord.x == x) continue :cols;
        }
        blank_col_count += 1;
    }
    return blank_col_count;
}

fn get_blank_rows(coords: []Coord, min: i64, max: i64) u8 {
    var blank_row_count: u8 = 0;
    var y: i64 = min;
    rows: while (y < max) : (y += 1) {
        for (coords) |coord| {
            if (coord.y == y) continue :rows;
        }
        blank_row_count += 1;
    }
    return blank_row_count;
}

fn get_distances(coords: []Coord, time: u32) usize {
    var result: usize = 0;
    for (0..coords.len - 1) |i| {
        for (i + 1..coords.len) |j| {
            if (i == j) continue;
            const a = coords[i];
            const b = coords[j];
            var distance: u64 = (time - 1) * get_blank_cols(coords, @min(a.x, b.x), @max(a.x, b.x));
            distance += (time - 1) * get_blank_rows(coords, @min(a.y, b.y), @max(a.y, b.y));
            // add manhattan distance
            distance += @abs(a.x - b.x) + @abs(a.y - b.y);
            result += distance;
        }
    }
    return result;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const coords = try parse_file("day11/input.txt", allocator);
    std.debug.print("Part1 - {d}\n", .{get_distances(coords, 2)});
    std.debug.print("Part2 - {d}\n", .{get_distances(coords, 1000000)});
}
test "parse" {
    const allocator = std.heap.page_allocator;
    const coords = try parse_file("day11/test.txt", allocator);
    try std.testing.expectEqual(coords.len, 9);
}

test "distances part1" {
    const allocator = std.heap.page_allocator;
    const coords = try parse_file("day11/test.txt", allocator);
    try std.testing.expectEqual(get_distances(coords, 2), 374);
}

test "distances part2" {
    const allocator = std.heap.page_allocator;
    const coords = try parse_file("day11/test.txt", allocator);
    try std.testing.expectEqual(get_distances(coords, 100), 8410);
}
