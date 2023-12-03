const std = @import("std");
const split = std.mem.split;

fn parse_file(path: []const u8, buf: []u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    const contents: []const u8 = try std.fs.cwd().readFile(path, buf);
    var iter = split(u8, contents, "\n");
    var list = std.ArrayList([]const u8).init(allocator);
    while (iter.next()) |item| {
        try list.append(item);
    }
    return list;
}

const Symbol = struct {
    x: usize,
    y: usize,
    symbol: u8,
};

fn check_symbol(x: usize, y: usize, grid: [][]const u8) ?Symbol {
    const c = grid[y][x];
    if ((c < '0' or c > '9') and c != '.') {
        return Symbol{ .x = x, .y = y, .symbol = c };
    }
    return null;
}

fn get_symbolic_neighbours(x: usize, y: usize, grid: [][]const u8, allocator: std.mem.Allocator) !std.ArrayList(Symbol) {
    const max_col = grid[0].len - 1;
    const max_row = grid.len - 1;
    const ix: i32 = @intCast(x);
    const iy: i32 = @intCast(y);
    var result = std.ArrayList(Symbol).init(allocator);
    for ([3]i32{ ix - 1, ix, ix + 1 }) |col| {
        for ([3]i32{ iy - 1, iy, iy + 1 }) |row| {
            if (row >= 0 and row < max_row and col >= 0 and col < max_col) {
                const symbol = check_symbol(@intCast(col), @intCast(row), grid);
                if (symbol != null) {
                    try result.append(symbol.?);
                }
            }
        }
    }
    return result;
}

fn part1(grid: [][]const u8, allocator: std.mem.Allocator) !u32 {
    var result: u32 = 0;
    for (grid, 0..) |line, row_index| {
        var valid_part: bool = false;
        var part_num: u32 = 0;
        for (line, 0..) |char, col_index| {
            if (char >= '0' and char <= '9') {
                part_num = (part_num * 10) + (char - '0');
                // check neighbours
                const neighbours = try get_symbolic_neighbours(col_index, row_index, grid, allocator);
                defer neighbours.deinit();
                if (neighbours.items.len > 0) {
                    valid_part = true;
                }
            } else {
                if (part_num > 0 and valid_part) {
                    result += part_num;
                }
                valid_part = false;
                part_num = 0;
            }
        }

        if (part_num > 0 and valid_part) {
            result += part_num;
        }
    }
    return result;
}

fn register_gear(gear: Symbol, part_num: u32, gears_lookup: *std.AutoArrayHashMap(Symbol, std.ArrayList(u32)), allocator: std.mem.Allocator) !void {
    var parts = gears_lookup.get(gear);
    if (parts == null) {
        parts = std.ArrayList(u32).init(allocator);
    }
    try parts.?.append(part_num);
    try gears_lookup.put(gear, parts.?);
}

fn part2(grid: [][]const u8, allocator: std.mem.Allocator) !u32 {
    var gears_lookup = std.AutoArrayHashMap(Symbol, std.ArrayList(u32)).init(allocator);
    defer gears_lookup.deinit();
    var gear_neighbours_set = std.AutoArrayHashMap(Symbol, void).init(allocator);
    defer gear_neighbours_set.deinit();

    for (grid, 0..) |line, row_index| {
        gear_neighbours_set.clearAndFree();
        var part_num: u32 = 0;
        for (line, 0..) |char, col_index| {
            if (char >= '0' and char <= '9') {
                part_num = (part_num * 10) + (char - '0');
                // check neighbours
                const neighbours = try get_symbolic_neighbours(col_index, row_index, grid, allocator);
                defer neighbours.deinit();
                for (neighbours.items) |neighbour| {
                    if (neighbour.symbol == '*') {
                        try gear_neighbours_set.put(neighbour, {});
                    }
                }
            } else {
                for (gear_neighbours_set.keys()) |gear| {
                    try register_gear(gear, part_num, &gears_lookup, allocator);
                }
                gear_neighbours_set.clearAndFree();
                part_num = 0;
            }
        }

        if (part_num > 0 and gear_neighbours_set.count() > 0) {
            for (gear_neighbours_set.keys()) |gear| {
                try register_gear(gear, part_num, &gears_lookup, allocator);
            }
        }
    }

    var result: u32 = 0;
    for (gears_lookup.keys()) |gear| {
        const parts = gears_lookup.get(gear).?;
        if (parts.items.len == 2) {
            result += (parts.items[0] * parts.items[1]);
        }
        parts.deinit();
    }
    return result;
}

pub fn main() !void {
    // create allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const buf = try allocator.alloc(u8, 1e6);
    defer allocator.free(buf);
    const grid = try parse_file("day03/input.txt", buf, allocator);
    defer grid.deinit();
    std.debug.print("Part1 - {d}\n", .{try part1(grid.items, allocator)});
    std.debug.print("Part2 - {d}\n", .{try part2(grid.items, allocator)});
}

test "part1" {
    const buf = try std.testing.allocator.alloc(u8, 1e6);
    const grid = try parse_file("day03/test.txt", buf, std.testing.allocator);
    defer {
        std.testing.allocator.free(buf);
        grid.deinit();
    }
    const result = try part1(grid.items, std.testing.allocator);
    try std.testing.expectEqual(result, 4361);
}

test "part2" {
    const buf = try std.testing.allocator.alloc(u8, 1e6);
    const grid = try parse_file("day03/test.txt", buf, std.testing.allocator);
    defer {
        std.testing.allocator.free(buf);
        grid.deinit();
    }
    const result = try part2(grid.items, std.testing.allocator);
    try std.testing.expectEqual(result, 467835);
}
