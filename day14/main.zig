const std = @import("std");

fn read_file(path: []const u8, allocator: std.mem.Allocator) ![][]u8 {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.mem.split(u8, file_contents, "\n");
    var result = std.ArrayList([]u8).init(allocator);
    while (lines.next()) |line| {
        const row = try allocator.alloc(u8, line.len);
        @memcpy(row, line);
        try result.append(row);
    }
    return result.toOwnedSlice();
}

fn print_grid(grid: *[][]u8) void {
    std.debug.print("Grid\n", .{});
    for (0..grid.*.len) |y| {
        std.debug.print("\n{s}", .{grid.*[y]});
    }
}

fn tip_north(grid: *[][]u8, width: u32, height: u32) void {
    var g = grid.*;
    var done = true;
    for (1..height) |y| {
        for (0..width) |x| {
            if (g[y - 1][x] == '.' and g[y][x] == 'O') {
                g[y - 1][x] = 'O';
                g[y][x] = '.';
                done = false;
            }
        }
    }
    if (!done) {
        tip_north(grid, width, height);
    }
}

fn tip_south(grid: *[][]u8, width: u32, height: u32) void {
    var g = grid.*;
    var done = true;
    var y = height - 1;
    while (y > 0) : (y -= 1) {
        for (0..width) |x| {
            if (g[y - 1][x] == 'O' and g[y][x] == '.') {
                g[y - 1][x] = '.';
                g[y][x] = 'O';
                done = false;
            }
        }
    }
    if (!done) {
        tip_south(grid, width, height);
    }
}

fn tip_west(grid: *[][]u8, width: u32, height: u32) void {
    var g = grid.*;
    var done = true;
    for (1..width) |x| {
        for (0..height) |y| {
            if (g[y][x - 1] == '.' and g[y][x] == 'O') {
                g[y][x - 1] = 'O';
                g[y][x] = '.';
                done = false;
            }
        }
    }
    if (!done) {
        tip_west(grid, width, height);
    }
}

fn tip_east(grid: *[][]u8, width: u32, height: u32) void {
    var g = grid.*;
    var done = true;
    var x = width - 1;
    while (x > 0) : (x -= 1) {
        for (0..height) |y| {
            if (g[y][x - 1] == 'O' and g[y][x] == '.') {
                g[y][x - 1] = '.';
                g[y][x] = 'O';
                done = false;
            }
        }
    }
    if (!done) {
        tip_east(grid, width, height);
    }
}

fn spin(grid: *[][]u8, width: u32, height: u32) void {
    tip_north(grid, width, height);
    tip_west(grid, width, height);
    tip_south(grid, width, height);
    tip_east(grid, width, height);
}

fn score(grid: *[][]u8, width: u32, height: u32) u32 {
    var total: u32 = 0;
    const g = grid.*;
    for (0..height) |y| {
        for (0..width) |x| {
            if (g[y][x] == 'O') {
                total += @as(u32, @intCast(height - y));
            }
        }
    }
    return total;
}

fn part1(grid: *[][]u8, width: u32, height: u32) u32 {
    tip_north(grid, width, height);
    return score(grid, width, height);
}

fn convert_grid(grid: *[][]u8) ![]u100 {
    var rep = std.ArrayList(u100).init(std.heap.page_allocator);
    var value: u100 = 0;
    for (0..grid.*.len) |y| {
        value = 0;
        for (0..grid.*[0].len) |x| {
            value = (value << 1);
            if (grid.*[y][x] == 'O') {
                value += 1;
            }
        }
        try rep.append(value);
    }
    return rep.toOwnedSlice();
}

fn part2(grid: *[][]u8, width: u32, height: u32) !u32 {
    var grids = std.ArrayList([]u100).init(std.heap.page_allocator);
    try grids.append(try convert_grid(grid));
    var loop_count: u64 = 1;
    const loop_index: u64 = done: while (true) : (loop_count += 1) {
        spin(grid, width, height);
        const grid_value = try convert_grid(grid);
        check: for (grids.items, 0..) |existing, index| {
            for (existing, grid_value) |v1, v2| {
                if (v1 != v2) continue :check;
            }
            break :done index;
        }

        try grids.append(grid_value);
    };
    // once found whats left to do
    const cycles: u64 = 1000000000;
    const cycle_loop_len: u64 = loop_count - loop_index;
    const remainder: u64 = (cycles - loop_count) % cycle_loop_len;
    for (0..remainder) |_| {
        spin(grid, width, height);
    }
    return score(grid, width, height);
}

pub fn main() !void {
    var contents = try read_file("day14/input.txt", std.heap.page_allocator);
    const width: u32 = @intCast(contents[0].len);
    const height: u32 = @intCast(contents.len);
    std.debug.print("Part 1 - {d}\n", .{part1(&contents, width, height)});
    std.debug.print("Part 2 - {d}\n", .{try part2(&contents, width, height)});
}

test "part1" {
    var contents = try read_file("day14/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(part1(&contents, @intCast(contents[0].len), @intCast(contents.len)), 136);
}

test "part2" {
    var contents = try read_file("day14/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(try part2(&contents, @intCast(contents[0].len), @intCast(contents.len)), 64);
}
test "parse" {
    const contents = try read_file("day14/test.txt", std.heap.page_allocator);
    try std.testing.expectEqual(contents.len, 10);
}
