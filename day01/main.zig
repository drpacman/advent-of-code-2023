const std = @import("std");
const fs = std.fs;

const max_file_read_1_mb = (1 << 10) << 10;
const numbers: [10][]const u8 = .{ "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };

fn is_digit(str: []const u8) ?u8 {
    if (str[0] >= '0' and str[0] <= '9') {
        return (str[0] - '0');
    }
    return null;
}

fn is_text_digit(str: []const u8) ?u8 {
    for (numbers, 0..10) |number, index| {
        if (number.len <= str.len and std.mem.eql(u8, number, str[0..number.len])) {
            return @as(u8, @intCast(index));
        }
    }
    return null;
}

fn is_digit_or_text(str: []const u8) ?u8 {
    return is_digit(str) orelse is_text_digit(str);
}

fn calculate(lines: *std.mem.TokenIterator(u8, std.mem.DelimiterType.any), comptime find_digit: fn ([]const u8) ?u8) u32 {
    var count: u32 = 0;
    while (lines.next()) |line| {
        var first: ?u8 = null;
        var second: ?u8 = null;
        var pos: u8 = 0;
        const n = line.len;
        while (pos < n) : (pos += 1) {
            const remaining = line[pos..];
            if (find_digit(remaining)) |d| {
                if (first == null) {
                    first = d;
                } else {
                    second = d;
                }
            }
        }
        // increment count by multipling first optional by ten and add second
        const value: u32 = (first orelse 0) * 10 + (second orelse first orelse 0);
        count += value;
    }
    return count;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cwd = fs.cwd();
    const contents: []const u8 = try cwd.readFileAlloc(allocator, "day01/test.txt", max_file_read_1_mb);
    var lines = std.mem.tokenizeAny(u8, contents, "\n");
    const part1 = calculate(&lines, is_digit);
    std.debug.print("Part1: {d}\n", .{part1});
    lines.reset();
    const part2 = calculate(&lines, is_digit_or_text);
    std.debug.print("Part2: {d}\n", .{part2});
}

test "my first test" {
    try std.testing.expect(7 == is_text_digit("seven"));
}
