const std = @import("std");

fn expand(rows: [][]i64, sign: bool, allocator: std.mem.Allocator) ![][]i64 {
    var updated_rows = std.ArrayList([]i64).init(allocator);
    // add a zero to the end of each row
    for (rows) |row| {
        var updated_row = std.ArrayList(i64).init(allocator);
        for (row) |x| {
            try updated_row.append(x);
        }
        try updated_row.append(0);
        try updated_rows.append(try updated_row.toOwnedSlice());
    }

    const results = try updated_rows.toOwnedSlice();
    var i = results.len - 1;
    while (i > 0) : (i -= 1) {
        var current_row = results[i - 1];
        const previous_row = results[i];
        // calculate new entry
        if (sign) {
            current_row[current_row.len - 1] = current_row[current_row.len - 2] + previous_row[previous_row.len - 1];
        } else {
            current_row[current_row.len - 1] = current_row[current_row.len - 2] - previous_row[previous_row.len - 1];
        }
        // std.debug.print("{any}\n", .{current_row});
    }
    return results;
}

fn generate_rows(row: []i64, allocator: std.mem.Allocator) ![][]i64 {
    var rows = std.ArrayList([]i64).init(allocator);
    try rows.append(row[0..]);

    var current = row;
    // calculate earlier rows
    while (true) {
        var next_row = std.ArrayList(i64).init(allocator);
        var done = true;
        // diff the row
        for (0..current.len) |i| {
            if (i == 0) continue;
            const diff = current[i] - current[i - 1];
            if (diff != 0) done = false;
            try next_row.append(diff);
        }
        current = try next_row.toOwnedSlice();
        try rows.append(current);
        if (done) break;
    }
    return try rows.toOwnedSlice();
}

fn part1(lines: [][]i64, allocator: std.mem.Allocator) !i64 {
    var sum: i64 = 0;
    for (lines, 0..) |line, index| {
        _ = index;
        const rows = try generate_rows(line, allocator);
        const expanded = try expand(rows, true, allocator);
        sum += expanded[0][expanded[0].len - 1];
    }
    return sum;
}

fn part2(lines: [][]i64, allocator: std.mem.Allocator) !i64 {
    var sum: i64 = 0;
    for (lines, 0..) |line, index| {
        _ = index;
        const rows = try generate_rows(line, allocator);
        // reverse the rows
        var reversed_rows = std.ArrayList([]i64).init(allocator);
        for (rows) |row| {
            var reversed_row = std.ArrayList(i64).init(allocator);
            var i = row.len;
            while (i > 0) : (i -= 1) {
                try reversed_row.append(row[i - 1]);
            }
            try reversed_rows.append(try reversed_row.toOwnedSlice());
        }
        const expanded = try expand(try reversed_rows.toOwnedSlice(), false, allocator);
        sum += expanded[0][expanded[0].len - 1];
    }
    return sum;
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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const rows = try read_file("day09/input.txt", allocator);
    std.debug.print("Part1 - {d}\n", .{try part1(rows, allocator)});
    std.debug.print("Part2 - {d}\n", .{try part2(rows, allocator)});
}

test "expand" {
    var row = [_]i64{ 1, 3, 6, 10, 15, 21 };
    const rows = try generate_rows(&row, std.heap.page_allocator);
    try std.testing.expectEqual(rows.len, 4);
    const expanded = try expand(rows, true, std.heap.page_allocator);
    try std.testing.expectEqual(expanded[0][expanded[0].len - 1], 28);
}

test "part1" {
    const result = try part1(try read_file("day09/test.txt", std.heap.page_allocator), std.heap.page_allocator);
    try std.testing.expectEqual(result, 114);
}

test "part2" {
    const result = try part2(try read_file("day09/test.txt", std.heap.page_allocator), std.heap.page_allocator);
    try std.testing.expectEqual(result, 2);
}
