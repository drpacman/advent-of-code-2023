const std = @import("std");

fn get_next_value(row: []i64, sign: bool, allocator: std.mem.Allocator) !i64 {
    var prev_row = std.ArrayList(i64).init(allocator);
    var done = true;
    for (1..row.len) |i| {
        const diff: i64 = row[i] - row[i - 1];
        if (diff != 0) done = false;
        try prev_row.append(diff);
    }
    if (done) {
        return row[row.len - 1];
    } else {
        if (sign) {
            return row[row.len - 1] + try get_next_value(try prev_row.toOwnedSlice(), sign, allocator);
        } else {
            return row[0] - try get_next_value(try prev_row.toOwnedSlice(), sign, allocator);
        }
    }
}

fn read_file(path: []const u8, allocator: std.mem.Allocator) ![][]i64 {
    const contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    defer allocator.free(contents);
    var lines = std.mem.split(u8, contents, "\n");
    var results = std.ArrayList([]i64).init(allocator);
    while (lines.next()) |line| {
        var entries = std.mem.split(u8, line, " ");
        var numbers = std.ArrayList(i64).init(allocator);
        while (entries.next()) |entry| {
            try numbers.append(try std.fmt.parseInt(i64, entry, 10));
        }
        try results.append(try numbers.toOwnedSlice());
    }
    return results.toOwnedSlice();
}

fn calculate(rows: [][]i64, sign: bool, allocator: std.mem.Allocator) !i64 {
    var sum: i64 = 0;
    for (rows) |row| {
        sum += try get_next_value(row, sign, allocator);
    }
    return sum;
}

fn part1(rows: [][]i64, allocator: std.mem.Allocator) !i64 {
    return calculate(rows, true, allocator);
}

fn part2(rows: [][]i64, allocator: std.mem.Allocator) !i64 {
    return calculate(rows, false, allocator);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const rows = try read_file("day09/input.txt", allocator);
    std.debug.print("Part1 - {d}\n", .{try part1(rows, allocator)});
    std.debug.print("Part2 - {d}\n", .{try part2(rows, allocator)});
}

test "part1" {
    const result = try part1(try read_file("day09/test.txt", std.heap.page_allocator), std.heap.page_allocator);
    try std.testing.expectEqual(result, 114);
}

test "part2" {
    const result = try part2(try read_file("day09/test.txt", std.heap.page_allocator), std.heap.page_allocator);
    try std.testing.expectEqual(result, 2);
}
