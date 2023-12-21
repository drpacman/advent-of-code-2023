const std = @import("std");

const Instruction = struct { dir: u8, count: u32 };

fn parse_instructions_part1(path: []const u8, allocator: std.mem.Allocator) ![]Instruction {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.mem.split(u8, file_contents, "\n");
    var instructions = std.ArrayList(Instruction).init(allocator);
    while (lines.next()) |line| {
        var line_parts = std.mem.split(u8, line[2..], " ");
        const count = line_parts.next().?;
        try instructions.append(Instruction{ .dir = line[0], .count = try std.fmt.parseInt(u8, count, 10) });
    }
    return instructions.toOwnedSlice();
}

fn parse_instructions_part2(path: []const u8, allocator: std.mem.Allocator) ![]Instruction {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.mem.split(u8, file_contents, "\n");
    var instructions = std.ArrayList(Instruction).init(allocator);
    while (lines.next()) |line| {
        var line_parts = std.mem.split(u8, line[2..], " ");
        _ = line_parts.next().?;
        const colour = line_parts.next().?;
        const count: u32 = try std.fmt.parseInt(u32, colour[2..7], 16);
        const dir: u8 = switch (colour[7]) {
            '0' => 'R',
            '1' => 'D',
            '2' => 'L',
            '3' => 'U',
            else => unreachable,
        };
        try instructions.append(Instruction{ .dir = dir, .count = count });
    }
    return instructions.toOwnedSlice();
}

const Line = struct { x1: i64, x2: i64, y1: i64, y2: i64 };
const Lagoon = struct { lines: []Line, min_x: i64, max_x: i64, min_y: i64, max_y: i64 };

fn create_lagoon(instructions: []Instruction, allocator: std.mem.Allocator) !Lagoon {
    // build up list of horizontal lines
    var y: i64 = 0;
    var x: i64 = 0;
    var max_x: i64 = 0;
    var max_y: i64 = 0;
    var min_x: i64 = 0;
    var min_y: i64 = 0;

    var lines = std.ArrayList(Line).init(allocator);
    for (instructions) |instruction| {
        if (instruction.dir == 'D') {
            const line = Line{ .x1 = x, .x2 = x, .y1 = y, .y2 = y + instruction.count };
            y += instruction.count;
            if (y > max_y) max_y = y;
            try lines.append(line);
        } else if (instruction.dir == 'U') {
            const line = Line{ .x1 = x, .x2 = x, .y1 = y, .y2 = y - instruction.count };
            y -= instruction.count;
            if (y < min_y) min_y = y;
            try lines.append(line);
        } else if (instruction.dir == 'L') {
            const line = Line{ .x1 = x, .x2 = x - instruction.count, .y1 = y, .y2 = y };
            x = x - instruction.count;
            if (x < min_x) min_x = x;
            try lines.append(line);
        } else if (instruction.dir == 'R') {
            const line = Line{ .x1 = x, .x2 = x + instruction.count, .y1 = y, .y2 = y };
            x = x + instruction.count;
            if (x > max_x) max_x = x;
            try lines.append(line);
        }
    }
    return Lagoon{ .lines = try lines.toOwnedSlice(), .min_x = min_x, .max_x = max_x, .min_y = min_y, .max_y = max_y };
}

fn print_grid(grid: [][]u8) void {
    for (grid) |row| {
        std.debug.print("{s}", .{row});
    }
}

fn part1_via_flood_fill(instructions: []Instruction, allocator: std.mem.Allocator) !u64 {
    const lagoon = try create_lagoon(instructions, allocator);
    const max_x = lagoon.max_x;
    const min_x = lagoon.min_x;
    const max_y = lagoon.max_y;
    const min_y = lagoon.min_y;
    var grid = try allocator.alloc([]u8, @intCast(max_y - min_y + 1));
    for (0..grid.len) |i| {
        grid[i] = try allocator.alloc(u8, @intCast(max_x - min_x + 1));
        for (0..grid[i].len) |j| {
            grid[i][j] = ' ';
        }
    }

    for (lagoon.lines) |line| {
        if (line.y1 == line.y2) {
            const ypos: usize = @intCast(line.y1 - min_y);
            const ax: usize = @intCast(line.x1 - min_x);
            const bx: usize = @intCast(line.x2 - min_x);
            if (ax > bx) {
                for (bx..ax + 1) |xpos| {
                    grid[ypos][xpos] = '#';
                }
            } else {
                for (ax..bx + 1) |xpos| {
                    grid[ypos][xpos] = '#';
                }
            }
        } else {
            const xpos: usize = @intCast(line.x1 - min_x);
            const ay: usize = @intCast(line.y1 - min_y);
            const by: usize = @intCast(line.y2 - min_y);
            if (ay > by) {
                for (by..ay + 1) |ypos| {
                    grid[ypos][xpos] = '#';
                }
            } else {
                for (ay..by + 1) |ypos| {
                    grid[ypos][xpos] = '#';
                }
            }
        }
    }

    // find a point inside the grid
    var start_x: u16 = 0;
    var start = false;
    for (0..grid[1].len) |i| {
        if (grid[1][i] == '#') {
            start = true;
        } else if (start) {
            start_x = @intCast(i);
            break;
        }
    }

    // flood fill
    var queue = std.ArrayList([2]u16).init(allocator);
    try queue.append([2]u16{ 1, start_x });

    while (queue.items.len > 0) {
        const entry = queue.pop();
        const neighbours = [4][2]u16{
            [2]u16{ entry[0] - 1, entry[1] },
            [2]u16{ entry[0] + 1, entry[1] },
            [2]u16{ entry[0], entry[1] - 1 },
            [2]u16{ entry[0], entry[1] + 1 },
        };
        for (neighbours) |neighbour| {
            if (grid[neighbour[0]][neighbour[1]] == ' ') {
                grid[neighbour[0]][neighbour[1]] = '#';
                try queue.append(neighbour);
            }
        }
    }

    var total: u64 = 0;
    for (grid) |row| {
        for (row) |cell| {
            if (cell == '#') total += 1;
        }
    }
    return total;
}

// calculate area of a polygon, uses sum of determinents
// https://en.wikipedia.org/wiki/Shoelace_formula
fn shoelace_area_calculation(lines: []Line) u64 {
    var area: i64 = 0;
    for (lines) |line| {
        area += (line.x1 * line.y2) - (line.x2 * line.y1);
    }
    return @divFloor(@abs(area), 2);
}

fn perimeter_calculation(lines: []Line) u64 {
    var perimeter: u64 = 0;
    for (lines) |line| {
        perimeter += @abs(line.x2 - line.x1) + @abs(line.y2 - line.y1);
    }
    return perimeter;
}

// internal area based calculated based on picks forumla
// which states Area = internal points + half the points on the perimeter - 1 (e.g. A=i+p/2-1)
// we want to calculate the internal points and know how to calcuate the area and the perimeter
// Rearranged to
// i = A - p/2 + 1
// include the perimeter of the lagoon to
// i = A - p/2 + 1 + p = A + p/2 + 1
// https://en.wikipedia.org/wiki/Pick%27s_theorem
fn picks_theorem(instructions: []Instruction, allocator: std.mem.Allocator) !u64 {
    const lagoon = try create_lagoon(instructions, allocator);
    const area: u64 = shoelace_area_calculation(lagoon.lines);
    const perimeter: u64 = perimeter_calculation(lagoon.lines);
    return area + @divFloor(perimeter, 2) + 1;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var instructions = try parse_instructions_part1("day18/input.txt", allocator);
    std.debug.print("Part1 - {d}\n", .{try part1_via_flood_fill(instructions, allocator)});
    instructions = try parse_instructions_part2("day18/input.txt", allocator);
    std.debug.print("Part2 - {d}\n", .{try picks_theorem(instructions, allocator)});
}

test "parse" {
    const allocator = std.heap.page_allocator;
    const instructions = try parse_instructions_part1("day18/test.txt", allocator);
    try std.testing.expectEqual(instructions.len, 14);
    try std.testing.expectEqual(instructions[0].count, 6);
    try std.testing.expect(std.mem.eql(u8, instructions[0].colour, "#70c710"));
}
